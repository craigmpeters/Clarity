//
//  ReminderSchemaEntities.swift
//  Clarity
//
//  App Intents schema entities for the reminders domain.
//

import AppIntents
import Foundation
import GeoToolbox
import SwiftData

@available(iOS 27, macOS 27, *)
@AppEnum(schema: .reminders.listType)
enum ReminderListType: String, Sendable {
    case standard

    static let caseDisplayRepresentations: [ReminderListType: DisplayRepresentation] = [
        .standard: DisplayRepresentation(title: "Standard")
    ]
}

@available(iOS 27, macOS 27, *)
@AppEntity(schema: .reminders.list)
struct ReminderListEntity {
    static let defaultQuery = ReminderListEntityQuery()

    let id: String
    var name: String
    var type: ReminderListType

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(name)")
    }

    init(id: String, name: String, type: ReminderListType = .standard) {
        self.id = id
        self.name = name
        self.type = type
    }
}

@available(iOS 27, macOS 27, *)
struct ReminderListEntityQuery: EntityQuery, EntityStringQuery, Sendable {
    func entities(for identifiers: [ReminderListEntity.ID]) async throws -> [ReminderListEntity] {
        let all = try await allEntities()
        return all.filter { identifiers.contains($0.id) }
    }

    func suggestedEntities() async throws -> [ReminderListEntity] {
        try await allEntities()
    }

    func entities(matching string: String) async throws -> [ReminderListEntity] {
        let all = try await allEntities()
        let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return all }
        return all.filter { $0.name.localizedCaseInsensitiveContains(trimmed) }
    }

    func allEntities() async throws -> [ReminderListEntity] {
        let store = try await ClarityServices.store()
        let categories = try await store.getCategories()
        return categories.map { category in
            ReminderListEntity(
                id: category.uuid?.uuidString ?? category.name,
                name: category.name
            )
        }
    }
}

@available(iOS 27, macOS 27, *)
@AppEnum(schema: .reminders.locationTriggerEvent)
enum ReminderLocationTriggerEvent: String, Sendable {
    case arrive
    case depart

    static let caseDisplayRepresentations: [ReminderLocationTriggerEvent: DisplayRepresentation] = [
        .arrive: DisplayRepresentation(title: "Arrive"),
        .depart: DisplayRepresentation(title: "Depart")
    ]
}

@available(iOS 27, macOS 27, *)
@AppEntity(schema: .reminders.locationTrigger)
struct ReminderLocationTriggerEntity {
    static let defaultQuery = ReminderLocationTriggerEntityQuery()

    let id: String
    var place: PlaceDescriptor
    var event: ReminderLocationTriggerEvent

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "Location Trigger")
    }

    init(id: String, place: PlaceDescriptor? = nil, event: ReminderLocationTriggerEvent = .arrive) {
        self.id = id
        self.place = place ?? PlaceDescriptor(representations: [.coordinate(.init(latitude: 0, longitude: 0))], commonName: nil)
        self.event = event
    }
}

@available(iOS 27, macOS 27, *)
struct ReminderLocationTriggerEntityQuery: EntityQuery, EntityStringQuery, Sendable {
    func entities(for identifiers: [ReminderLocationTriggerEntity.ID]) async throws -> [ReminderLocationTriggerEntity] {
        []
    }

    func suggestedEntities() async throws -> [ReminderLocationTriggerEntity] {
        []
    }

    func entities(matching string: String) async throws -> [ReminderLocationTriggerEntity] {
        []
    }
}

@available(iOS 27, macOS 27, *)
@AppEntity(schema: .reminders.section)
struct ReminderSectionEntity {
    static let defaultQuery = ReminderSectionEntityQuery()

    let id: String
    var name: String
    var list: ReminderListEntity

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(name)")
    }

    init(id: String, name: String, list: ReminderListEntity) {
        self.id = id
        self.name = name
        self.list = list
    }
}

@available(iOS 27, macOS 27, *)
struct ReminderSectionEntityQuery: EntityQuery, EntityStringQuery, Sendable {
    func entities(for identifiers: [ReminderSectionEntity.ID]) async throws -> [ReminderSectionEntity] {
        []
    }

    func suggestedEntities() async throws -> [ReminderSectionEntity] {
        []
    }

    func entities(matching string: String) async throws -> [ReminderSectionEntity] {
        []
    }
}

@available(iOS 27, macOS 27, *)
@AppEntity(schema: .reminders.reminder)
struct ReminderEntity {
    static let defaultQuery = ReminderEntityQuery()

    let id: String

    var title: String
    var note: AttributedString?
    var images: [IntentFile]
    var subtasks: [ReminderEntity]
    var tags: Set<String>
    var urls: [URL]
    var dueDate: DateComponents?
    var recurrence: Calendar.RecurrenceRule?
    var isCompleted: Bool
    var isFlagged: Bool?
    var creationDate: Date?
    var completionDate: Date?
    var list: ReminderListEntity
    var section: ReminderSectionEntity?
    var locationTrigger: ReminderLocationTriggerEntity?

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(title)")
    }

    init(task: ToDoTaskDTO, category: CategoryDTO?, allCategories: [CategoryDTO]) {
        let listEntity = ReminderSchemaList.entity(for: category, allCategories: allCategories)
        self.id = ReminderSchemaID.encode(.task, uuid: task.uuid)
        self.images = []
        self.subtasks = []
        self.tags = []
        self.urls = []
        self.title = task.name
        self.note = nil
        self.dueDate = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: task.due)
        self.recurrence = ReminderSchemaRecurrence.recurrenceRule(
            from: task.recurrenceInterval ?? .daily,
            customDays: task.customRecurrenceDays,
            specificDay: task.everySpecificDayDay
        )
        self.isCompleted = task.completed
        self.isFlagged = false
        self.creationDate = task.created
        self.completionDate = task.completedAt
        self.list = listEntity
        self.section = nil
        self.locationTrigger = nil
    }

    init(habit: HabitDTO, occurrence: HabitOccurrenceDTO? = nil, category: CategoryDTO?, allCategories: [CategoryDTO]) {
        let listEntity = ReminderSchemaList.entity(for: category, allCategories: allCategories)
        self.id = ReminderSchemaID.encode(.habit, uuid: habit.uuid)
        self.images = []
        self.subtasks = []
        self.tags = []
        self.urls = []
        self.title = habit.name
        self.note = nil
        self.dueDate = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: Date.now)
        self.recurrence = Calendar.RecurrenceRule(calendar: .current, frequency: .daily, interval: 1)
        self.isCompleted = occurrence?.completed ?? false
        self.isFlagged = false
        self.creationDate = habit.created
        self.completionDate = occurrence?.completedAt
        self.list = listEntity
        self.section = nil
        self.locationTrigger = nil
    }
}

@available(iOS 27, macOS 27, *)
struct ReminderEntityQuery: EntityQuery, EntityStringQuery, Sendable {
    func entities(for identifiers: [ReminderEntity.ID]) async throws -> [ReminderEntity] {
        let store = try await ClarityServices.store()
        let allCategories = (try? await store.getCategories()) ?? []
        var results: [ReminderEntity] = []
        for id in identifiers {
            guard let (kind, uuid) = ReminderSchemaID.decode(id) else { continue }
            switch kind {
            case .task:
                if let dto = try await store.fetchTaskByUuidIncludingCompleted(uuid) {
                    results.append(ReminderEntity(
                        task: dto,
                        category: dto.categories.first,
                        allCategories: allCategories
                    ))
                }
            case .habit:
                if let dto = try await store.fetchHabit(uuid) {
                    let occurrence = try? await todaysOccurrence(for: uuid, using: store)
                    results.append(ReminderEntity(
                        habit: dto,
                        occurrence: occurrence,
                        category: dto.categories.first,
                        allCategories: allCategories
                    ))
                }
            }
        }
        return results
    }

    func suggestedEntities() async throws -> [ReminderEntity] {
        let store = try await ClarityServices.store()
        let allCategories = (try? await store.getCategories()) ?? []
        let tasks = try await store.fetchTasks(filter: .all)
        let habits = try await store.fetchHabits()
        var results: [ReminderEntity] = []
        for task in tasks where !task.completed {
            results.append(ReminderEntity(
                task: task,
                category: task.categories.first,
                allCategories: allCategories
            ))
        }
        for habit in habits {
            let occurrence = try? await todaysOccurrence(for: habit.uuid, using: store)
            results.append(ReminderEntity(
                habit: habit,
                occurrence: occurrence,
                category: habit.categories.first,
                allCategories: allCategories
            ))
        }
        return results
    }

    func entities(matching string: String) async throws -> [ReminderEntity] {
        let store = try await ClarityServices.store()
        let allCategories = (try? await store.getCategories()) ?? []
        let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return try await suggestedEntities() }
        let tasks = try await store.fetchTasks(filter: .all)
        let habits = try await store.fetchHabits()
        var results: [ReminderEntity] = []
        for task in tasks where task.name.localizedCaseInsensitiveContains(trimmed) {
            results.append(ReminderEntity(
                task: task,
                category: task.categories.first,
                allCategories: allCategories
            ))
        }
        for habit in habits where habit.name.localizedCaseInsensitiveContains(trimmed) {
            let occurrence = try? await todaysOccurrence(for: habit.uuid, using: store)
            results.append(ReminderEntity(
                habit: habit,
                occurrence: occurrence,
                category: habit.categories.first,
                allCategories: allCategories
            ))
        }
        return results
    }

    private func todaysOccurrence(for habitUUID: UUID, using store: ClarityModelActor) async -> HabitOccurrenceDTO? {
        let startOfDay = Calendar.current.startOfDay(for: .now)
        return try? await store.fetchHabitHistory(habitUUID, from: startOfDay, to: .now).first
    }
}
