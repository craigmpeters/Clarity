import UserNotifications

/// Represents the available alarm sounds for a Pomodoro completion notification.
enum PomodoroAlarmSound: Equatable {
    case `default`
    case preset(name: String)   // "chime", "bell", "ding"
    case custom(filename: String)

    // MARK: Display

    var displayName: String {
        switch self {
        case .default:
            return "Default"
        case .preset(let name):
            return name.prefix(1).uppercased() + name.dropFirst()
        case .custom(let filename):
            // Strip the .caf extension for display
            let base = filename.hasSuffix(".caf") ? String(filename.dropLast(4)) : filename
            return base
        }
    }

    // MARK: Notification sound

    var notificationSound: UNNotificationSound {
        switch self {
        case .default:
            return .default
        case .preset(let name):
            #if os(watchOS)
            return .default
            #else
            return UNNotificationSound(named: UNNotificationSoundName("pomodoro_\(name).caf"))
            #endif
        case .custom(let filename):
            #if os(watchOS)
            return .default
            #else
            return UNNotificationSound(named: UNNotificationSoundName(filename))
            #endif
        }
    }

    // MARK: Persistence

    /// A stable string identifier stored in UserDefaults.
    var persistenceID: String {
        switch self {
        case .default:
            return "default"
        case .preset(let name):
            return "preset:\(name)"
        case .custom(let filename):
            return "custom:\(filename)"
        }
    }

    static func from(persistenceID id: String) -> PomodoroAlarmSound {
        if id == "default" {
            return .default
        }
        if id.hasPrefix("preset:") {
            let name = String(id.dropFirst("preset:".count))
            return .preset(name: name)
        }
        if id.hasPrefix("custom:") {
            let filename = String(id.dropFirst("custom:".count))
            return .custom(filename: filename)
        }
        return .default
    }

    // MARK: Available presets

    static let allPresets: [PomodoroAlarmSound] = [
        .preset(name: "chime"),
        .preset(name: "bell"),
        .preset(name: "ding")
    ]
}
