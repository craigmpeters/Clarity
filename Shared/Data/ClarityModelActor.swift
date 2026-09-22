//
//  ClarityModelActor.swift
//  Clarity
//
//  Created by Craig Peters on 02/10/2025.
//

import Foundation
import SwiftData
import WidgetKit
import XCGLogger
import os

@ModelActor
actor ClarityModelActor {
  /// Seam for widget/file coordination so tests can opt out of WidgetKit/NSFileCoordinator.
  nonisolated(unsafe) static var widgetCoordinator: any WidgetCoordination = LiveWidgetCoordinator()

  // MARK: Category Functions
  private var logger: XCGLogger { LogManager.shared.log }
  // Prevent concurrent completions for the same UUID within this actor
  private var inFlightCompletions: Set<UUID> = []
  private var inFlightHabitMutations: Set<UUID> = []

  /// Hook for the main app to push weekly progress to the watch after a task completes.
  /// Not set in widget/extension targets where WatchConnectivity is unavailable.
  nonisolated(unsafe) static var onTaskCompleted: (@MainActor @Sendable () -> Void)?
  /// Hook for the main app to push a snapshot to the watch after any task mutation (add/update/delete).
  nonisolated(unsafe) static var onTaskMutated: (@MainActor @Sendable () -> Void)?
  /// Hook for the main app to push a snapshot to the watch after any habit mutation (add/update/delete).
  nonisolated(unsafe) static var onHabitMutated: (@MainActor @Sendable () -> Void)?
  // Throttle dedup runs triggered by remote merges / write paths
  private var lastDedupRunAt: Date? = nil
  // In-flight dedup guard to prevent overlapping fetch/delete/save cycles
  private var isDedupInFlight = false

  private var totaltasks = 0

  func addCategory(_ dto: CategoryDTO) throws -> CategoryDTO {
    let category = Category(
      name: dto.name,
      color: dto.color,
      weeklyTarget: dto.weeklyTarget,
      iconName: dto.iconName
    )
    modelContext.insert(category)
    try modelContext.save()
    try Self.widgetCoordinator.writeCategories(getCategories())
    Self.widgetCoordinator.reloadTimelines(ofKind: "TodoWidget")
    return CategoryDTO(from: category)
  }

  func updateCategory(_ dto: CategoryDTO) throws -> CategoryDTO {
    guard let id = dto.id else {
      throw NSError(
        domain: "ClarityActor", code: 1,
        userInfo: [NSLocalizedDescriptionKey: "Missing PersistentIdentifier"])
    }
    guard let model = modelContext.model(for: id) as? Category else {
      throw NSError(
        domain: "ClarityActor", code: 2,
        userInfo: [NSLocalizedDescriptionKey: "Failed to cast to Category"])
    }
    model.name = dto.name
    model.color = dto.color
    model.weeklyTarget = dto.weeklyTarget
    model.iconName = dto.iconName
    try modelContext.save()
    try Self.widgetCoordinator.writeCategories(getCategories())
    Self.widgetCoordinator.reloadAllTimelines()
    return CategoryDTO(from: model)
  }

  func deleteCategory(_ id: PersistentIdentifier) throws {
    if let model = modelContext.model(for: id) as? Category {
      modelContext.delete(model)
      try modelContext.save()
    }
    try Self.widgetCoordinator.writeCategories(getCategories())
    Self.widgetCoordinator.reloadAllTimelines()
  }

  func getCategories() throws -> [CategoryDTO] {
    let descriptor = FetchDescriptor<Category>()
    let categories = try modelContext.fetch(descriptor)
    return categories.map(CategoryDTO.init(from:))
  }

  // MARK: Task Functions

  // MARK: - Habit Helpers

  private func habitPostMutationPipeline() throws {
    try modelContext.save()
    try Self.widgetCoordinator.writeHabits(fetchHabits())
    try Self.widgetCoordinator.writeTasks(fetchRecentTasks())
    Self.widgetCoordinator.reloadAllTimelines()
    if let onTaskMutated = ClarityModelActor.onTaskMutated {
      Task { @MainActor in onTaskMutated() }
    }
    if let onHabitMutated = ClarityModelActor.onHabitMutated {
      Task { @MainActor in onHabitMutated() }
    }
    try? serializedDeduplicateTasksByUUID()
  }

  private func habitByUUID(_ uuid: UUID, includeArchived: Bool = false) throws -> Habit {
    let descriptor = FetchDescriptor<Habit>(predicate: #Predicate { $0.uuid == uuid })
    guard let habit = try modelContext.fetch(descriptor).first else {
      throw HabitError.notFound
    }
    guard includeArchived || !habit.isArchived else {
      throw HabitError.archived
    }
    return habit
  }

  private func todayOccurrence(for habit: Habit, date: Date = Date(), source: String? = nil) throws
    -> HabitOccurrence
  {
    let calendar = Calendar.current
    let startOfDay = calendar.startOfDay(for: date)
    guard let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) else {
      throw HabitError.persistenceFailed(
        underlying: NSError(
          domain: "ClarityActor", code: 20,
          userInfo: [NSLocalizedDescriptionKey: "Invalid calendar date"]))
    }
    let habitUUID = habit.uuid
    let descriptor = FetchDescriptor<HabitOccurrence>(
      predicate: #Predicate {
        $0.habit?.uuid == habitUUID && $0.periodStart >= startOfDay && $0.periodStart < endOfDay
      }
    )
    if let existing = try modelContext.fetch(descriptor).first {
      return existing
    }
    let new = HabitOccurrence(habit: habit, periodStart: startOfDay, source: source)
    habit.occurrences = (habit.occurrences ?? []) + [new]
    modelContext.insert(new)
    return new
  }

  private func validateDailyTarget(_ target: Double, healthKitIdentifier: String?) throws {
    guard HabitConfig.validateTarget(target, healthKitIdentifier: healthKitIdentifier) else {
      throw HabitError.invalidTarget
    }
  }

  private func validateDailyTarget(_ dto: HabitDTO) throws {
    try validateDailyTarget(dto.dailyTarget, healthKitIdentifier: dto.healthKitIdentifier)
  }

  private func resolveCategories(from dtoCategories: [CategoryDTO]) throws -> [Category] {
    let allCategories = try modelContext.fetch(FetchDescriptor<Category>())
    return dtoCategories.compactMap { dto in
      if let catId = dto.id, let existing = modelContext.model(for: catId) as? Category {
        return existing
      }
      return allCategories.first(where: { $0.uuid == dto.uuid })
    }
  }

  func addHabit(_ dto: HabitDTO) throws -> HabitDTO {
    try validateDailyTarget(dto)
    let categories = try resolveCategories(from: dto.categories)
    let habit = Habit(
      uuid: dto.uuid,
      name: dto.name,
      created: dto.created,
      unitLabel: dto.unitLabel,
      dailyTarget: dto.dailyTarget,
      incrementStep: dto.incrementStep,
      weeklyFrequency: dto.weeklyFrequency,
      streakFreezes: dto.streakFreezes,
      freezesSpent: dto.freezesSpent,
      healthKitIdentifier: dto.healthKitIdentifier,
      isArchived: false,
      categories: categories
    )
    modelContext.insert(habit)
    try habitPostMutationPipeline()
    return HabitDTO(from: habit)
  }

  func updateHabit(_ dto: HabitDTO) throws -> HabitDTO {
    try validateDailyTarget(dto)
    guard let id = dto.id else {
      throw NSError(
        domain: "ClarityActor", code: 1,
        userInfo: [NSLocalizedDescriptionKey: "Missing PersistentIdentifier"])
    }
    guard let model = modelContext.model(for: id) as? Habit else {
      throw HabitError.notFound
    }
    let categories = try resolveCategories(from: dto.categories)
    model.name = dto.name
    model.unitLabel = dto.unitLabel
    model.dailyTarget = dto.dailyTarget
    model.incrementStep = dto.incrementStep
    model.weeklyFrequency = dto.weeklyFrequency
    model.healthKitIdentifier = dto.healthKitIdentifier
    model.categories = categories
    try habitPostMutationPipeline()
    return HabitDTO(from: model)
  }

  func archiveHabit(_ uuid: UUID) throws {
    let habit = try habitByUUID(uuid)
    habit.isArchived = true
    try habitPostMutationPipeline()
  }

  func unarchiveHabit(_ uuid: UUID) throws {
    let habit = try habitByUUID(uuid, includeArchived: true)
    guard habit.isArchived else { return }
    habit.isArchived = false
    try habitPostMutationPipeline()
  }

  func deleteHabit(_ uuid: UUID) throws {
    let habit = try habitByUUID(uuid, includeArchived: true)
    modelContext.delete(habit)
    try habitPostMutationPipeline()
  }

  func fetchHabits() throws -> [HabitDTO] {
    let descriptor = FetchDescriptor<Habit>(predicate: #Predicate { !$0.isArchived })
    let habits = try modelContext.fetch(descriptor)
    return habits.map(HabitDTO.init(from:))
  }

  func fetchHabitsIncludingArchived() throws -> [HabitDTO] {
    let descriptor = FetchDescriptor<Habit>()
    return try modelContext.fetch(descriptor).map(HabitDTO.init(from:))
  }

  func fetchHabitHistory(_ uuid: UUID, from: Date, to: Date) throws -> [HabitOccurrenceDTO] {
    let descriptor = FetchDescriptor<HabitOccurrence>(
      predicate: #Predicate {
        $0.habit?.uuid == uuid && $0.periodStart >= from && $0.periodStart <= to
      }
    )
    return try modelContext.fetch(descriptor).compactMap(HabitOccurrenceDTO.init(from:))
  }

  private func withHabitMutationLock<T>(_ habitUUID: UUID, operation: () throws -> T) throws -> T {
    guard !inFlightHabitMutations.contains(habitUUID) else {
      throw HabitError.persistenceFailed(
        underlying: NSError(
          domain: "ClarityActor", code: 21,
          userInfo: [NSLocalizedDescriptionKey: "Habit mutation already in flight"]))
    }
    inFlightHabitMutations.insert(habitUUID)
    defer { inFlightHabitMutations.remove(habitUUID) }
    return try operation()
  }

  func logHabitProgress(_ habitUUID: UUID, amount: Double? = nil, source: String = "manual") throws
    -> HabitOccurrenceDTO
  {
    try withHabitMutationLock(habitUUID) {
      let habit = try habitByUUID(habitUUID)
      let occurrence = try todayOccurrence(for: habit, source: source)
      let step = amount ?? habit.incrementStep
      occurrence.currentAmount += step
      if occurrence.currentAmount >= habit.dailyTarget {
        occurrence.completed = true
        occurrence.completedAt = Date.now
      }
      occurrence.source = source
      reconcileFreezes(habit)
      try habitPostMutationPipeline()
      guard let dto = HabitOccurrenceDTO(from: occurrence) else {
        throw HabitError.persistenceFailed(
          underlying: NSError(
            domain: "ClarityActor", code: 22,
            userInfo: [NSLocalizedDescriptionKey: "HabitOccurrence missing habit UUID"]))
      }
      return dto
    }
  }

  /// Log habit progress and optionally write the delta to HealthKit.
  /// HealthKit write is only attempted when source == "manual" and the habit is HealthKit-linked.
  /// The HealthKit write is dispatched as a detached task so the actor does not suspend while holding the modelContext.
  func logHabitProgressWithHealthKit(_ habitUUID: UUID, amount: Double? = nil) async throws
    -> HabitOccurrenceDTO
  {
    let dto = try logHabitProgress(habitUUID, amount: amount, source: "manual")
    #if os(iOS)
      if let habit = try? habitByUUID(habitUUID), let identifier = habit.healthKitIdentifier {
        let delta = amount ?? habit.incrementStep
        Task.detached(priority: .utility) {
          await HealthKitService.shared.saveHabitSample(identifier: identifier, value: delta)
        }
      }
    #endif
    return dto
  }

  func setHabitProgress(_ habitUUID: UUID, date: Date, amount: Double) throws -> HabitOccurrenceDTO
  {
    try withHabitMutationLock(habitUUID) {
      let habit = try habitByUUID(habitUUID)
      let occurrence = try todayOccurrence(for: habit, date: date)
      occurrence.currentAmount = max(amount, 0)
      if occurrence.currentAmount >= habit.dailyTarget {
        occurrence.completed = true
        occurrence.completedAt = Date.now
      } else {
        occurrence.completed = false
        occurrence.completedAt = nil
      }
      reconcileFreezes(habit)
      try habitPostMutationPipeline()
      guard let dto = HabitOccurrenceDTO(from: occurrence) else {
        throw HabitError.persistenceFailed(
          underlying: NSError(
            domain: "ClarityActor", code: 22,
            userInfo: [NSLocalizedDescriptionKey: "HabitOccurrence missing habit UUID"]))
      }
      return dto
    }
  }

  func applyHealthKitProgress(_ habitUUID: UUID, value: Double, date: Date = Date()) throws
    -> HabitOccurrenceDTO
  {
    try withHabitMutationLock(habitUUID) {
      let habit = try habitByUUID(habitUUID)
      let occurrence = try todayOccurrence(for: habit, date: date, source: "healthkit")
      occurrence.currentAmount = max(occurrence.currentAmount, value)
      if occurrence.currentAmount >= habit.dailyTarget {
        occurrence.completed = true
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        if calendar.isDateInToday(startOfDay) {
          occurrence.completedAt = Date.now
        } else if occurrence.completedAt == nil {
          // Backfilled day: record completion at the end of that day rather than "now".
          occurrence.completedAt =
            calendar.date(byAdding: .day, value: 1, to: startOfDay)?.addingTimeInterval(-1)
            ?? Date.now
        }
      }
      occurrence.source = "healthkit"
      reconcileFreezes(habit)
      try habitPostMutationPipeline()
      guard let dto = HabitOccurrenceDTO(from: occurrence) else {
        throw HabitError.persistenceFailed(
          underlying: NSError(
            domain: "ClarityActor", code: 22,
            userInfo: [NSLocalizedDescriptionKey: "HabitOccurrence missing habit UUID"]))
      }
      return dto
    }
  }

  func updateHabitArtwork(_ uuid: UUID, filename: String?) throws -> HabitDTO {
    let habit = try habitByUUID(uuid, includeArchived: true)
    habit.artworkFilename = filename
    try habitPostMutationPipeline()
    return HabitDTO(from: habit)
  }

  func forceStreakFreezes(_ uuid: UUID, count: Int) throws {
    let habit = try habitByUUID(uuid, includeArchived: true)
    habit.streakFreezes = count
    try modelContext.save()
  }

  func spendFreeze(_ habitUUID: UUID) throws {
    try withHabitMutationLock(habitUUID) {
      let habit = try habitByUUID(habitUUID)
      guard habit.streakFreezes > 0 else {
        throw HabitError.noFreezesAvailable
      }
      let calendar = Calendar.current
      let allOccurrences = try fetchHabitHistory(
        habitUUID, from: Date.distantPast, to: Date.distantFuture)
      let streak = HabitStreakCalculator.streak(
        occurrences: allOccurrences,
        frequency: habit.weeklyFrequency,
        freezes: habit.streakFreezes
      )
      guard let missedPeriod = streak.missedPeriod,
        let graceEnd = calendar.date(
          byAdding: .day, value: HabitConfig.gracePeriodDays, to: missedPeriod),
        Date() <= graceEnd
      else {
        throw HabitError.noFreezableMiss
      }
      let occurrence = try todayOccurrence(for: habit, date: missedPeriod)
      occurrence.freezeUsed = true
      occurrence.completed = true
      occurrence.currentAmount = habit.dailyTarget
      habit.streakFreezes -= 1
      habit.freezesSpent += 1
      try habitPostMutationPipeline()
    }
  }

  private func reconcileFreezes(_ habit: Habit) {
    let allOccurrences = try? fetchHabitHistory(
      habit.uuid, from: Date.distantPast, to: Date.distantFuture)
    let streak = HabitStreakCalculator.streak(
      occurrences: allOccurrences ?? [],
      frequency: habit.weeklyFrequency,
      freezes: habit.streakFreezes
    )
    let earned = min(streak.freezesEarned, HabitConfig.maxFreezes)
    let available = max(earned - habit.freezesSpent, 0)
    habit.streakFreezes = available
  }

  // MARK: Task Functions

  func fetchTaskByUuidIncludingCompleted(_ id: UUID) throws -> ToDoTaskDTO? {
    let taskUuid: UUID? = id
    let descriptor = FetchDescriptor<ToDoTask>(
      predicate: #Predicate { $0.uuid == taskUuid }
    )
    let tasks = try modelContext.fetch(descriptor)
    return tasks.first.map(ToDoTaskDTO.init(from:))
  }

  func fetchHabit(_ uuid: UUID) throws -> HabitDTO? {
    let descriptor = FetchDescriptor<Habit>(predicate: #Predicate { $0.uuid == uuid && !$0.isArchived })
    guard let habit = try modelContext.fetch(descriptor).first else { return nil }
    return HabitDTO(from: habit)
  }

  func fetchHabitIncludingArchived(_ uuid: UUID) throws -> HabitDTO? {
    let descriptor = FetchDescriptor<Habit>(predicate: #Predicate { $0.uuid == uuid })
    guard let habit = try modelContext.fetch(descriptor).first else { return nil }
    return HabitDTO(from: habit)
  }

  func deleteTask(uuid: UUID) throws {
    let descriptor = FetchDescriptor<ToDoTask>(predicate: #Predicate { $0.uuid == uuid })
    let tasks = try modelContext.fetch(descriptor)
    for task in tasks {
      modelContext.delete(task)
    }
    try modelContext.save()
    try Self.widgetCoordinator.writeTasks(fetchRecentTasks())
    Self.widgetCoordinator.reloadAllTimelines()
    if let onTaskMutated = ClarityModelActor.onTaskMutated {
      Task { @MainActor in onTaskMutated() }
    }
    try? deduplicateTasksByUUID()
  }
  func fetchWatchWidgetBackingData(
    completeFilter: ToDoTask.CompletedTaskFilter, dueFilter: ToDoTask.TaskFilterOption
  ) -> WatchWidgetData {
    var data = WatchWidgetData(due: 0, completed: 0, progress: 0, target: 0)

    // data.completed
    let descriptor = FetchDescriptor<ToDoTask>(
      predicate: #Predicate { $0.completed },
      sortBy: [SortDescriptor(\.completedAt, order: .reverse)]
    )
    do {
      let tasks = try modelContext.fetch(descriptor)
      let dto: [ToDoTaskDTO] = tasks.map { ToDoTaskDTO(from: $0) }

      let filtered = dto.filter { completeFilter.matches($0) }
      data.completed = filtered.count
    } catch {
      data.completed = 0
    }

    // data.due
    do {
      let dueTasks = try fetchTasks(filter: dueFilter.toTaskFilter())
      data.due = dueTasks.count
    } catch {
      data.due = 0
    }

    //data.progress
    do {
      let progress = try fetchWeeklyProgress()
      data.target = progress.target
      data.completed = progress.completed
    } catch {
      data.target = 0
      data.completed = 0
    }

    return data
  }

  func fetchLastCompletedTask(filter: ToDoTask.TaskFilter = .all) -> ToDoTaskDTO? {
    let descriptor = FetchDescriptor<ToDoTask>(
      predicate: #Predicate { $0.completed },
      sortBy: [SortDescriptor(\.completedAt, order: .reverse)]
    )

    do {
      let tasks = try modelContext.fetch(descriptor)
      let now = Date()
      let filtered = tasks.filter { filter.matches(task: $0, at: now) }
      if let task = filtered.first {
        return ToDoTaskDTO(from: task)
      }
      return nil
    } catch {
      return nil
    }
  }

  func fetchRecentlyCompleted(minutes: Int = 10) throws -> [ToDoTaskDTO] {
    let cutoff = Date().addingTimeInterval(-TimeInterval(minutes * 60))
    LogManager.shared.log.debug("📋 Fetching tasks completed after \(cutoff.ISO8601Format())")

    let descriptor = FetchDescriptor<ToDoTask>(
      predicate: #Predicate { $0.completed },
      sortBy: [SortDescriptor(\.completedAt, order: .reverse)]
    )

    let allCompleted = try modelContext.fetch(descriptor)
    LogManager.shared.log.debug("📋 Found \(allCompleted.count) total completed tasks")

    // Filter in Swift to avoid complex predicate expressions
    let recentTasks = allCompleted.filter { task in
      guard let completedAt = task.completedAt else { return false }
      return completedAt > cutoff
    }
    LogManager.shared.log.debug("📋 \(recentTasks.count) tasks completed in last \(minutes) minutes")
    return recentTasks.map(ToDoTaskDTO.init(from:))
  }

  func fetchRecentTasks() throws -> [ToDoTaskDTO] {
    let calendar = Calendar.current
    let now = Date()
    let cutoff = calendar.date(byAdding: .month, value: -1, to: now) ?? now

    // Fetch all tasks then filter in Swift to avoid unsupported predicate expressions
    let descriptor = FetchDescriptor<ToDoTask>(
      sortBy: [SortDescriptor(\.created, order: .reverse)]
    )

    let allTasks = try modelContext.fetch(descriptor)
    let tasks = allTasks.filter { !$0.completed || ($0.completedAt ?? Date.distantPast) > cutoff }
    LogManager.shared.log.debug(
      "Found \(tasks.count) tasks of which \(tasks.filter(\.completed).count) are completed")
    return tasks.map(ToDoTaskDTO.init(from:))
  }

  func fetchTasks(filter: ToDoTask.TaskFilter) throws -> [ToDoTaskDTO] {
    let descriptor = FetchDescriptor<ToDoTask>(
      predicate: #Predicate { !$0.completed },
      sortBy: [SortDescriptor(\.due, order: .forward)]
    )
    let tasks = try modelContext.fetch(descriptor)

    let now = Date()
    let filtered = tasks.filter { filter.matches(task: $0, at: now) }

    return filtered.map(ToDoTaskDTO.init(from:))
  }

  func fetchCompletedTasks() throws -> [ToDoTaskDTO] {
    let descriptor = FetchDescriptor<ToDoTask>(
      predicate: #Predicate { $0.completed },
      sortBy: [SortDescriptor(\.due, order: .forward)]
    )
    let tasks = try modelContext.fetch(descriptor)
    LogManager.shared.log.debug("Fetched \(tasks.count) completed tasks")
    return tasks.map(ToDoTaskDTO.init(from:))
  }

  func fetchCompletedTasks(since cutoff: Date) throws -> [ToDoTaskDTO] {
    let calendar = Calendar.current
    let startOfDay = calendar.startOfDay(for: cutoff)
    // Predicate: completed and has a completedAt timestamp. The SwiftData macro cannot
    // express `completedAt ?? .distantPast >= cutoff`, so we filter the (much smaller)
    // completed-only set in Swift below.
    let descriptor = FetchDescriptor<ToDoTask>(
      predicate: #Predicate { $0.completed && $0.completedAt != nil },
      sortBy: [SortDescriptor(\.completedAt, order: .forward)]
    )
    let tasks = try modelContext.fetch(descriptor).filter { task in
      (task.completedAt ?? .distantPast) >= startOfDay
    }
    LogManager.shared.log.debug("Fetched \(tasks.count) completed tasks since \(startOfDay)")
    return tasks.map(ToDoTaskDTO.init(from:))
  }

  func updateTask(_ task: ToDoTaskDTO) throws -> ToDoTaskDTO {
    guard let id = task.id else {
      throw NSError(
        domain: "ClarityActor", code: 1,
        userInfo: [NSLocalizedDescriptionKey: "Missing PersistentIdentifier"])
    }
    guard let model = modelContext.model(for: id) as? ToDoTask else {
      throw NSError(
        domain: "ClarityActor", code: 2, userInfo: [NSLocalizedDescriptionKey: "Task not found"])
    }
    model.due = task.due
    model.name = task.name

    // Map CategoryDTOs to persisted Category models
    // Prefer matching by persistent identifier when available; fall back to name match
    let allCategories = try modelContext.fetch(FetchDescriptor<Category>())
    let mappedCategories: [Category] = task.categories.compactMap { dto in
      if let catId = dto.id, let existing = modelContext.model(for: catId) as? Category {
        return existing
      }
      // Fallback: match by name
      return allCategories.first(where: { $0.name == dto.name })
    }
    model.categories = mappedCategories
    model.pomodoroTime = task.pomodoroTime
    model.customRecurrenceDays = task.customRecurrenceDays
    model.recurrenceInterval = task.recurrenceInterval
    model.repeating = task.repeating
    model.pomodoro = task.pomodoro
    model.everySpecificDayDay = task.everySpecificDayDay
    LogManager.shared.log.debug("Update Task Day Day \(task.everySpecificDayDay)")

    try modelContext.save()
    try Self.widgetCoordinator.writeTasks(fetchRecentTasks())
    Self.widgetCoordinator.reloadAllTimelines()
    if let onTaskMutated = ClarityModelActor.onTaskMutated {
      Task { @MainActor in onTaskMutated() }
    }
    try? deduplicateTasksByUUID()
    return ToDoTaskDTO(from: model)
  }

  /// Inserts a new task into the context without saving. Returns nil if a non-completed task
  /// with the same UUID already exists (dedup). Caller is responsible for saving.
  private func insertTask(_ dto: ToDoTaskDTO) throws -> ToDoTask? {
    let allCategories = try modelContext.fetch(FetchDescriptor<Category>())
    let incomingCategoryNames = dto.categories.map { $0.name }
    LogManager.shared.log.debug(
      "insertTask incoming categories: names=\(incomingCategoryNames) count=\(dto.categories.count)"
    )
    let categories: [Category] = dto.categories.compactMap { dto in
      if let catId = dto.id, let existing = modelContext.model(for: catId) as? Category {
        return existing
      }
      return allCategories.first(where: { $0.name == dto.name })
    }
    LogManager.shared.log.debug("insertTask mapped categories count=\(categories.count)")
    LogManager.shared.log.debug("insertTask Day Day \(dto.everySpecificDayDay)")

    let targetUUID: UUID? = dto.uuid
    let existingDescriptor = FetchDescriptor<ToDoTask>(
      predicate: #Predicate {
        $0.uuid == targetUUID && !$0.completed
      }
    )
    let existing = try modelContext.fetch(existingDescriptor)
    if let existingTask = existing.first {
      LogManager.shared.log.info(
        "insertTask deduped: active task already exists for UUID \(existingTask.uuid?.uuidString ?? "Unknown UUID")"
      )
      return nil
    }

    let toDoTask = ToDoTask(
      name: dto.name,
      pomodoro: dto.pomodoro,
      pomodoroTime: dto.pomodoroTime,
      repeating: dto.repeating,
      recurrenceInterval: dto.recurrenceInterval,
      customRecurrenceDays: dto.customRecurrenceDays,
      due: dto.due,
      everySpecificDayDay: dto.everySpecificDayDay,
      categories: categories,
      uuid: dto.uuid
    )
    modelContext.insert(toDoTask)
    return toDoTask
  }

  func addTask(_ dto: ToDoTaskDTO) throws -> ToDoTaskDTO {
    let toDoTask: ToDoTask
    if let inserted = try insertTask(dto) {
      toDoTask = inserted
    } else {
      // Already exists - fetch and return it
      let targetUUID: UUID? = dto.uuid
      let descriptor = FetchDescriptor<ToDoTask>(
        predicate: #Predicate { $0.uuid == targetUUID && !$0.completed })
      if let existing = try modelContext.fetch(descriptor).first {
        return ToDoTaskDTO(from: existing)
      }
      throw NSError(
        domain: "ClarityActor", code: 3,
        userInfo: [NSLocalizedDescriptionKey: "Dedup: existing task missing after insert skipped"])
    }
    try modelContext.save()
    try Self.widgetCoordinator.writeTasks(fetchRecentTasks())
    Self.widgetCoordinator.reloadAllTimelines()
    if let onTaskMutated = ClarityModelActor.onTaskMutated {
      Task { @MainActor in onTaskMutated() }
    }
    try? serializedDeduplicateTasksByUUID()
    return ToDoTaskDTO(from: toDoTask)
  }

  func deleteTask(_ id: PersistentIdentifier) throws {
    if let model = modelContext.model(for: id) as? ToDoTask {
      modelContext.delete(model)
      try modelContext.save()
    }
    try Self.widgetCoordinator.writeTasks(fetchRecentTasks())
    Self.widgetCoordinator.reloadAllTimelines()
    if let onTaskMutated = ClarityModelActor.onTaskMutated {
      Task { @MainActor in onTaskMutated() }
    }
    try? serializedDeduplicateTasksByUUID()
  }

  func completeTask(_ id: UUID, startedAt: Date? = nil) throws {
    guard !inFlightCompletions.contains(id) else {
      LogManager.shared.log.info(
        "completeTask: skipping duplicate in-flight completion for UUID \(id.uuidString)")
      return
    }
    inFlightCompletions.insert(id)
    defer { inFlightCompletions.remove(id) }

    var completed = false
    LogManager.shared.log.info("Completing task with UUID \(id.uuidString)")
    let descriptor = FetchDescriptor<ToDoTask>(
      predicate: #Predicate {
        $0.uuid == id && !$0.completed
      }
    )
    var tasks = try modelContext.fetch(descriptor)
    if tasks.isEmpty {
      LogManager.shared.log.info("completeTask: no incomplete task found for UUID \(id.uuidString); skipping")
      return
    }
    do {
      tasks = try tasks.map { task in
        task.completed = true
          if let startedAt = startedAt, startedAt + task.pomodoroTime < Date.now {
          task.completedAt = startedAt + task.pomodoroTime
        } else {
          task.completedAt = Date.now
        }
        task.startedAt = startedAt
        if task.repeating! && !completed {
          if let nextDTO = createNextOccurrence(task.id) {
            LogManager.shared.log.debug(
              "completeTask: creating next occurrence for uuid=\(task.uuid?.uuidString ?? "nil"), dtoCategoryCount=\(nextDTO.categories.count)"
            )
            if let newTask = try insertTask(nextDTO) {
              LogManager.shared.log.info("Staged next occurrence for \(newTask.name ?? "")")
            }
          }
          completed = true
        }
        return task
      }
    } catch {
      LogManager.shared.log.error("Error in completing task \(error.localizedDescription)")
    }
    try modelContext.save()
    try Self.widgetCoordinator.writeTasks(fetchRecentTasks())
    Self.widgetCoordinator.reloadAllTimelines()

    if let onTaskCompleted = ClarityModelActor.onTaskCompleted {
      Task { @MainActor in onTaskCompleted() }
    }
    try? serializedDeduplicateTasksByUUID()

    // Post after dedup so observers never observe pre-dedup state.
    Task {
      await MainActor.run {
        NotificationCenter.default.post(
          name: .taskCompleted,
          object: nil,
          userInfo: [Notification.Name.taskUUIDKey: id]
        )
      }
      LogManager.shared.log.debug("Posted taskCompleted notification for \(id.uuidString)")
    }
  }

  /// Marks a task as not completed, reverting completion state
  func uncompleteTask(_ id: UUID) throws {
    LogManager.shared.log.info("Uncompleting task with UUID \(id.uuidString)")
    let descriptor = FetchDescriptor<ToDoTask>(
      predicate: #Predicate {
        $0.uuid == id && $0.completed
      },
      sortBy: [SortDescriptor(\.completedAt, order: .reverse)]
    )

    // Get the most recently completed task with this UUID
    guard let task = try modelContext.fetch(descriptor).first else {
      LogManager.shared.log.warning(
        "uncompleteTask: no completed task found for UUID \(id.uuidString)")
      return
    }

    task.completed = false
    task.completedAt = nil
    task.startedAt = nil
    task.completionMoodValence = nil

    try modelContext.save()
    try Self.widgetCoordinator.writeTasks(fetchRecentTasks())
    Self.widgetCoordinator.reloadAllTimelines()
    if let onTaskMutated = ClarityModelActor.onTaskMutated {
      Task { @MainActor in onTaskMutated() }
    }
    try? serializedDeduplicateTasksByUUID()

    Task {
      await MainActor.run {
        NotificationCenter.default.post(
          name: .taskUncompleted,
          object: nil,
          userInfo: [Notification.Name.taskUUIDKey: id]
        )
      }
      LogManager.shared.log.debug("Posted taskUncompleted notification for \(id.uuidString)")
    }

    LogManager.shared.log.info("Task uncompleted: \(id.uuidString)")
  }

  /// Records the mood valence on the most recently completed task with the given UUID.
  func recordMood(valence: Double, taskUUID: UUID) throws {
    let uuid: UUID? = taskUUID
    let descriptor = FetchDescriptor<ToDoTask>(
      predicate: #Predicate { $0.uuid == uuid && $0.completed },
      sortBy: [SortDescriptor(\.completedAt, order: .reverse)]
    )
    guard let task = try modelContext.fetch(descriptor).first else { return }
    task.completionMoodValence = valence
    try modelContext.save()
  }

  func fetchLastCompletedAt(uuid: UUID) throws -> Date? {
    let taskUuid: UUID? = uuid
    let descriptor = FetchDescriptor<ToDoTask>(
      predicate: #Predicate { $0.uuid == taskUuid && $0.completed },
      sortBy: [SortDescriptor(\.completedAt, order: .reverse)]
    )
    return try modelContext.fetch(descriptor).first?.completedAt
  }

  func fetchTaskNameByUuid(_ id: UUID) throws -> String? {
    let taskUuid: UUID? = id
    let descriptor = FetchDescriptor<ToDoTask>(
      predicate: #Predicate { $0.uuid == taskUuid }
    )
    let tasks = try modelContext.fetch(descriptor)
    return tasks.first?.name
  }

  func fetchTaskByUuid(_ id: UUID) throws -> ToDoTaskDTO? {
    let taskUuid: UUID? = id
    let descriptor = FetchDescriptor<ToDoTask>(
      predicate: #Predicate {
        $0.uuid == taskUuid && !$0.completed
      }
    )
    let tasks = try modelContext.fetch(descriptor)
    LogManager.shared.log.info("fetchTaskByUuid: \(id) returned: \(tasks.count)")
    return tasks.first.map(ToDoTaskDTO.init(from:))
  }
  func fetchTaskById(_ id: PersistentIdentifier) throws -> ToDoTaskDTO? {
    if let model = modelContext.model(for: id) as? ToDoTask {
      return ToDoTaskDTO(from: model)
    }
    return nil
  }

  func createNextOccurrence(_ id: PersistentIdentifier) -> ToDoTaskDTO? {
    var nextDueDate: Date

    guard let task = modelContext.model(for: id) as? ToDoTask else {
      // Avoid interpolating PersistentIdentifier directly in logs
      LogManager.shared.log.error("Task not found for provided PersistentIdentifier")
      return nil
    }

    if let interval = task.recurrenceInterval {
      if interval == .custom {
        nextDueDate =
          Calendar.current.date(
            byAdding: .day,
            value: task.customRecurrenceDays,
            to: Date.now
          ) ?? task.due
      } else if interval == .specific {
        // Stored value already matches Calendar weekday (1...7). Clamp to be safe; default to Sunday (1) if nil.
        LogManager.shared.log.debug(
          "createNextOccurrence Day Day: \(task.everySpecificDayDay.map(String.init) ?? "None")")
        var com = DateComponents()
        // Map app's weekday index (where 3 = Wednesday) to Calendar's weekday (1 = Sunday ... 7 = Saturday)
        if let appWeekday = task.everySpecificDayDay {
          // Normalize to 1...7 range first
          let normalized = ((appWeekday - 1) % 7 + 7) % 7 + 1
          // Shift so that app's 3 (Wednesday) becomes Calendar's 4 (Wednesday)
          // Compute offset between app's Wednesday(3) and Calendar's Wednesday(4) => +1
          let calendarWeekday = ((normalized + 1 - 1) % 7) + 1
          com.weekday = calendarWeekday
        } else {
          // Default to Sunday if missing
          com.weekday = 1
        }

        let calendar = Calendar.current
        let startOfToday = calendar.startOfDay(for: Date())
        // let startOfTomorrow = calendar.date(byAdding: .day, value: 1, to: startOfToday) ?? Date().addingTimeInterval(86_400)

        if let computed = calendar.nextDate(
          after: startOfToday,
          matching: com,
          matchingPolicy: .nextTimePreservingSmallerComponents,
          direction: .forward)
        {
          nextDueDate = computed
        } else {
          LogManager.shared.log.error(
            "Failed to compute next specific weekday; falling back to interval.nextDate")
          nextDueDate = interval.nextDate(from: Date.now)
        }
      } else {
        nextDueDate = interval.nextDate(from: Date.now)
      }
    } else {
      // Fallback to daily if no interval set
      nextDueDate = Calendar.current.date(byAdding: .day, value: 1, to: task.due) ?? task.due
    }

    // Explicitly fetch categories to ensure the relationship is fully loaded.
    // Accessing task.categories directly on a freshly-created actor context (e.g. from
    // restoreIfNeeded) can return an empty array due to SwiftData lazy faulting.
    let resolvedCategories: [Category]
    if let catIds = task.categories?.compactMap({ $0.id }), !catIds.isEmpty {
      resolvedCategories = catIds.compactMap { modelContext.model(for: $0) as? Category }
    } else {
      resolvedCategories = []
    }
    let categoryCount = resolvedCategories.count
    LogManager.shared.log.debug(
      "createNextOccurrence: base task uuid=\(task.uuid?.uuidString ?? "nil"), name=\(task.name ?? "nil"), categories=\(categoryCount), nextDue=\(nextDueDate)"
    )

    // uuid is shared across all occurrences of a recurring series — this is the existing
    // behaviour and must not change to preserve CloudKit identity across devices.
    let newTask = ToDoTaskDTO(
      name: task.name,
      pomodoroTime: task.pomodoroTime,
      repeating: true,
      recurrenceInterval: task.recurrenceInterval,
      customRecurrenceDays: task.customRecurrenceDays,
      due: nextDueDate,
      everySpecificDayDay: task.everySpecificDayDay ?? 0,
      categories: resolvedCategories.map(CategoryDTO.init(from:)),
      uuid: task.uuid ?? UUID()
    )
    return newTask
  }

  func fetchWeeklyProgress() throws -> WeeklyProgress {
    let globalTarget =
      (try? modelContext.fetch(FetchDescriptor<GlobalTargetSettings>()))?.first?.weeklyGlobalTarget
      ?? 0
    let categories =
      (try? modelContext.fetch(FetchDescriptor<Category>()))?.map(CategoryDTO.init(from:)) ?? []
    let completedDTOs =
      (try? modelContext.fetch(
        FetchDescriptor<ToDoTask>(predicate: #Predicate { $0.completed })
      ))?.map(ToDoTaskDTO.init(from:)) ?? []

    return StatisticsCalculator.weeklyProgress(
      completedTasks: completedDTOs,
      categories: categories,
      globalTarget: globalTarget
    )
  }

  // MARK: - Maintenance / Deduplication

  /// Serializes deduplication to prevent overlapping fetch/delete/save cycles that can
  /// saturate SwiftData's performAndWait queue and trigger CoreData crashes.
  private func serializedDeduplicateTasksByUUID() throws {
    guard !isDedupInFlight else {
      logger.debug("Dedup already in flight, skipping concurrent run")
      return
    }
    isDedupInFlight = true
    defer { isDedupInFlight = false }
    try deduplicateTasksByUUID()
  }

  func deduplicateTasksByUUID() throws {
    // Fetch all incomplete tasks
    let descriptor = FetchDescriptor<ToDoTask>(
      predicate: #Predicate { !$0.completed }
    )
    let tasks = try modelContext.fetch(descriptor)

    // Group by UUID (ignore nil)
    var groups: [UUID: [ToDoTask]] = [:]
    for task in tasks {
      guard let id = task.uuid else { continue }
      groups[id, default: []].append(task)
    }

    var totalDuplicateGroups = 0
    var totalDeleted = 0

    for (uuid, group) in groups where group.count > 1 {
      logger.error("Dedup: Found duplicate group uuid=\(uuid.uuidString) count=\(group.count)")

      // Log full details for each record in the group
      for (idx, t) in group.enumerated() {
        let categories = (t.categories ?? []).compactMap { $0.name }.joined(separator: ",")
        logger.error(
          "  [\(idx)] id=\(t.id.debugDescription) name=\(t.name ?? "nil") due=\(t.due) completed=\(t.completed) completedAt=\(String(describing: t.completedAt)) cats=[\(categories)] created=[\(t.created.ISO8601Format())]"
        )
      }

      // Choose the winner deterministically
      let winner = group.min { a, b in
        let aCatCount = a.categories?.count ?? 0
        let bCatCount = b.categories?.count ?? 0

        // 1) Prefer the one that has categories if the other doesn't (any positive count beats zero)
        if (aCatCount > 0) != (bCatCount > 0) {
          return aCatCount == 0  // if a has 0 and b > 0, then a is "greater" so return false; but min uses this as "less-than"
        }

        // 2) If both have categories (or both don't), prefer more categories
        if aCatCount != bCatCount {
          return aCatCount < bCatCount  // larger category count wins, so "less-than" should be false when a has more
        }

        // 3) Earliest due date wins
        if a.due != b.due { return a.due < b.due }

        // 4) Prefer non-nil name
        let aNameNil = (a.name == nil)
        let bNameNil = (b.name == nil)
        if aNameNil != bNameNil { return !aNameNil }  // if a has a name and b doesn't, a should come first

        // 5) Stable tie-breaker
        return a.id.debugDescription < b.id.debugDescription
      }!

      // Delete all others
      for t in group where t.id != winner.id {
        logger.warning(
          "Dedup: Deleting loser id=\(t.id.debugDescription) for uuid=\(uuid.uuidString)")
        modelContext.delete(t)
        totalDeleted += 1
      }
      totalDuplicateGroups += 1
    }

    if totalDuplicateGroups > 0 {
      try modelContext.save()
      // Keep widgets in sync with the new state
      try Self.widgetCoordinator.writeTasks(fetchRecentTasks())
      Self.widgetCoordinator.reloadAllTimelines()
    }

    logger.info("Dedup: groups=\(totalDuplicateGroups) deleted=\(totalDeleted)")
  }

  func fetchTaskHistory(for taskUuid: UUID) throws -> [ToDoTaskDTO] {
    let descriptor = FetchDescriptor<ToDoTask>(
      predicate: #Predicate { $0.uuid == taskUuid }
    )
    let tasks = (try? modelContext.fetch(descriptor)) ?? []
    return tasks.map(ToDoTaskDTO.init(from:))
  }

  //    func getTaskHistoryTimeline(for taskUuid: UUID) -> [TaskHistoryEntry] {
  //        let tasks = getTaskHistory(for: taskUuid)
  //        return tasks.map { task in
  //            TaskHistoryEntry(
  //                date: task.created,
  //                uuid: task.uuid ?? taskUuid,
  //                title: task.name ?? ""
  //            )
  //        }
  //    }
}

enum ClarityModelActorFactory {
  static func makeBackground(container: ModelContainer) async -> ClarityModelActor {
    await withCheckedContinuation { cont in
      Task.detached(priority: .userInitiated) {
        let store = ClarityModelActor(modelContainer: container)  // created off main queue
        cont.resume(returning: store)
      }
    }
  }
}

// Containers.swift
enum Containers {
  nonisolated static func liveApp() throws -> ModelContainer {
    let schema = Schema([
      ToDoTask.self, Category.self, GlobalTargetSettings.self, TaskSwipeAndTapOptions.self,
      Habit.self, HabitOccurrence.self,
    ])
    let cfg = ModelConfiguration(
      schema: schema,
      isStoredInMemoryOnly: false,
      allowsSave: true,
      groupContainer: .identifier("group.me.craigpeters.clarity"),
      cloudKitDatabase: .private("iCloud.me.craigpeters.clarity")  // CK ON
    )
    return try ModelContainer(for: schema, configurations: [cfg])
  }

  nonisolated static func liveExtension() throws -> ModelContainer {
    let schema = Schema([
      ToDoTask.self, Category.self, GlobalTargetSettings.self, TaskSwipeAndTapOptions.self,
      Habit.self, HabitOccurrence.self,
    ])
    let cfg = ModelConfiguration(
      schema: schema,
      isStoredInMemoryOnly: false,
      allowsSave: true,
      groupContainer: .identifier("group.me.craigpeters.clarity"),
      // CK OFF
    )
    return try ModelContainer(for: schema, configurations: [cfg])
  }

  nonisolated static func inMemory() throws -> ModelContainer {
    let schema = Schema([
      ToDoTask.self, Category.self, GlobalTargetSettings.self, TaskSwipeAndTapOptions.self,
      Habit.self, HabitOccurrence.self,
    ])
    let cfg = ModelConfiguration(
      schema: schema,
      isStoredInMemoryOnly: true,
      allowsSave: true,
      groupContainer: .none,
      cloudKitDatabase: .none
    )
    return try ModelContainer(for: schema, configurations: [cfg])
  }
}

// AppContainer.swift (APP TARGET)
enum AppContainer {
  nonisolated static let shared: ModelContainer = {
    do {
      if TestEnvironment.isRunningTests {
        return try Containers.inMemory()
      }
      return try Containers.liveApp()
    } catch {
      fatalError("Failed to create shared model container: \(error)")
    }
  }()
}

// #MARK: Timeline Entries

struct TaskHistoryEntry: TimelineEntry {
  let date: Date
  let uuid: UUID
  let tasks: [ToDoTaskDTO]

}

struct TaskWidgetEntry: TimelineEntry {
  let date: Date
  var todos: [ToDoTaskDTO]
  let progress: WeeklyProgress
  let filter: ToDoTask.TaskFilterOption
  let showWeeklyProgress: Bool
}

struct CompletedTaskEntry: TimelineEntry {
  let date: Date
  let tasks: [ToDoTaskDTO]
  let categories: [CategoryDTO]
  let progress: WeeklyProgress
  let filter: ToDoTask.CompletedTaskFilter
  let showWeeklyProgress: Bool
}
