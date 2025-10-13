
import Foundation
import UserNotifications

protocol NotificationServiceProtocol {
    func requestAuthorization() async -> Bool
    func scheduleDailyCheckIn(at hour: Int, minute: Int) async
    func schedulePreCompetitionReminder(for event: Event) async
}

final class NotificationService: NotificationServiceProtocol {
    func requestAuthorization() async -> Bool {
        await withCheckedContinuation { continuation in
            UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
                continuation.resume(returning: granted)
            }
        }
    }

    func scheduleDailyCheckIn(at hour: Int, minute: Int) async {
        let content = UNMutableNotificationContent()
        content.title = "Check-in MindAthlete"
        content.body = "¿Cómo te sientes hoy? Registra tu mood y energía."
        content.sound = .default

        var date = DateComponents()
        date.hour = hour
        date.minute = minute

        let trigger = UNCalendarNotificationTrigger(dateMatching: date, repeats: true)
        let request = UNNotificationRequest(identifier: "daily_check_in", content: content, trigger: trigger)

        try? await UNUserNotificationCenter.current().add(request)
    }

    func schedulePreCompetitionReminder(for event: Event) async {
        let content = UNMutableNotificationContent()
        content.title = "Preparación pre-competencia"
        content.body = "Recuerda tu ritual de respiración y foco antes de \(event.type)."
        content.sound = .defaultCritical

        let triggerDate = Calendar.current.date(byAdding: .hour, value: -2, to: event.date) ?? event.date
        let triggerComponents = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: triggerDate)

        let trigger = UNCalendarNotificationTrigger(dateMatching: triggerComponents, repeats: false)
        let request = UNNotificationRequest(identifier: "pre_competition_\(event.id)", content: content, trigger: trigger)

        try? await UNUserNotificationCenter.current().add(request)
    }
}
