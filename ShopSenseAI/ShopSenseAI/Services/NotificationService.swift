import Foundation
import UserNotifications
import SwiftUI

class NotificationService: NSObject, ObservableObject {
    static let shared = NotificationService()
    
    @Published var deliveredNotifications: [UNNotification] = []
    @Published var unreadCount: Int = 0
    @Published var isAuthorized = false
    
    private let notificationCenter = UNUserNotificationCenter.current()
    private var notificationSettings: UserPreferencesManager?
    
    override private init() {
        super.init()
        notificationCenter.delegate = self
        checkAuthorizationStatus()
        loadDeliveredNotifications()
    }
    
    // MARK: - Authorization
    
    func requestAuthorization() {
        notificationCenter.requestAuthorization(options: [.alert, .badge, .sound]) { granted, error in
            DispatchQueue.main.async {
                self.isAuthorized = granted
                if granted {
                    self.scheduleNotifications()
                }
            }
        }
    }
    
    private func checkAuthorizationStatus() {
        notificationCenter.getNotificationSettings { settings in
            DispatchQueue.main.async {
                self.isAuthorized = settings.authorizationStatus == .authorized
            }
        }
    }
    
    // MARK: - Notification Management
    
    func updateNotificationSettings(with preferences: UserPreferencesManager) {
        self.notificationSettings = preferences
        
        // Reschedule notifications based on new settings
        notificationCenter.removeAllPendingNotificationRequests()
        
        if preferences.notificationsEnabled {
            scheduleNotifications()
        }
    }
    
    private func scheduleNotifications() {
        guard let settings = notificationSettings ?? UserPreferencesManager.shared,
              settings.notificationsEnabled else { return }
        
        // Schedule daily digest
        if settings.dailyDigestEnabled {
            scheduleDailyDigest(at: settings.digestTime)
        }
    }
    
    private func scheduleDailyDigest(at time: Date) {
        let content = UNMutableNotificationContent()
        content.title = "Daily Shopping Digest"
        content.body = "Check out today's deals and savings opportunities!"
        content.sound = .default
        content.categoryIdentifier = "DAILY_DIGEST"
        
        let calendar = Calendar.current
        let components = calendar.dateComponents([.hour, .minute], from: time)
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
        
        let request = UNNotificationRequest(
            identifier: "daily_digest",
            content: content,
            trigger: trigger
        )
        
        notificationCenter.add(request)
    }
    
    // MARK: - Sending Notifications
    
    func sendPriceDropNotification(for product: Product, currentPrice: Double, retailer: String) {
        guard notificationSettings?.priceDropAlertsEnabled ?? true else { return }
        
        let content = UNMutableNotificationContent()
        content.title = "Price Drop Alert! 🎉"
        content.body = "\(product.name) is now $\(String(format: "%.2f", currentPrice)) at \(retailer)"
        content.sound = .default
        content.categoryIdentifier = "PRICE_DROP"
        content.userInfo = ["productId": product.id.uuidString, "action": "view_deal"]
        
        let request = UNNotificationRequest(
            identifier: "price_drop_\(product.id.uuidString)",
            content: content,
            trigger: UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        )
        
        notificationCenter.add(request)
    }
    
    func sendInventoryAlert(for item: InventoryItem) {
        guard notificationSettings?.inventoryAlertsEnabled ?? true else { return }
        
        let content = UNMutableNotificationContent()
        content.title = "Low Stock Alert"
        content.body = "\(item.product.name) is running low. Only \(item.currentQuantity) left!"
        content.sound = .default
        content.categoryIdentifier = "INVENTORY_ALERT"
        content.userInfo = ["itemId": item.id.uuidString, "action": "reorder"]
        
        let request = UNNotificationRequest(
            identifier: "inventory_\(item.id.uuidString)",
            content: content,
            trigger: UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        )
        
        notificationCenter.add(request)
    }
    
    func sendDealExpiringNotification(for deal: DealAlert) {
        guard notificationSettings?.dealExpiringAlertsEnabled ?? true else { return }
        
        let content = UNMutableNotificationContent()
        content.title = "Deal Expiring Soon!"
        content.body = "\(deal.product.name) deal expires in 1 hour. Save $\(String(format: "%.2f", deal.savings))!"
        content.sound = .default
        content.categoryIdentifier = "DEAL_EXPIRING"
        content.userInfo = ["dealId": deal.id.uuidString]
        
        // Schedule 1 hour before expiry
        if let expiryDate = deal.expiryDate {
            let trigger = UNTimeIntervalNotificationTrigger(
                timeInterval: max(1, expiryDate.timeIntervalSinceNow - 3600),
                repeats: false
            )
            
            let request = UNNotificationRequest(
                identifier: "deal_expiring_\(deal.id.uuidString)",
                content: content,
                trigger: trigger
            )
            
            notificationCenter.add(request)
        }
    }
    
    func sendBudgetAlert(message: String) {
        let content = UNMutableNotificationContent()
        content.title = "Budget Alert"
        content.body = message
        content.sound = .default
        content.categoryIdentifier = "BUDGET_ALERT"
        
        let request = UNNotificationRequest(
            identifier: "budget_alert_\(Date().timeIntervalSince1970)",
            content: content,
            trigger: UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        )
        
        notificationCenter.add(request)
    }
    
    func sendTestNotification() {
        let content = UNMutableNotificationContent()
        content.title = "Test Notification"
        content.body = "Notifications are working correctly!"
        content.sound = .default
        
        let request = UNNotificationRequest(
            identifier: "test_notification",
            content: content,
            trigger: UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        )
        
        notificationCenter.add(request)
    }
    
    // MARK: - Managing Delivered Notifications
    
    func loadDeliveredNotifications() {
        notificationCenter.getDeliveredNotifications { notifications in
            DispatchQueue.main.async {
                self.deliveredNotifications = notifications.sorted {
                    $0.date > $1.date
                }
                self.updateUnreadCount()
            }
        }
    }
    
    func removeNotification(withIdentifier identifier: String) {
        notificationCenter.removeDeliveredNotifications(withIdentifiers: [identifier])
        loadDeliveredNotifications()
    }
    
    func removeAllNotifications() {
        notificationCenter.removeAllDeliveredNotifications()
        deliveredNotifications = []
        unreadCount = 0
    }
    
    private func updateUnreadCount() {
        // In a real app, you'd track which notifications have been viewed
        unreadCount = deliveredNotifications.count
    }
    
    // MARK: - Action Handling
    
    private func setupNotificationCategories() {
        let viewDealAction = UNNotificationAction(
            identifier: "VIEW_DEAL",
            title: "View Deal",
            options: [.foreground]
        )
        
        let reorderAction = UNNotificationAction(
            identifier: "REORDER",
            title: "Reorder Now",
            options: [.foreground]
        )
        
        let dismissAction = UNNotificationAction(
            identifier: "DISMISS",
            title: "Dismiss",
            options: [.destructive]
        )
        
        let priceDropCategory = UNNotificationCategory(
            identifier: "PRICE_DROP",
            actions: [viewDealAction, dismissAction],
            intentIdentifiers: []
        )
        
        let inventoryCategory = UNNotificationCategory(
            identifier: "INVENTORY_ALERT",
            actions: [reorderAction, dismissAction],
            intentIdentifiers: []
        )
        
        let dealExpiringCategory = UNNotificationCategory(
            identifier: "DEAL_EXPIRING",
            actions: [viewDealAction, dismissAction],
            intentIdentifiers: []
        )
        
        notificationCenter.setNotificationCategories([
            priceDropCategory,
            inventoryCategory,
            dealExpiringCategory
        ])
    }
}

// MARK: - UNUserNotificationCenterDelegate
extension NotificationService: UNUserNotificationCenterDelegate {
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                              willPresent notification: UNNotification,
                              withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        // Show notification even when app is in foreground
        completionHandler([.banner, .sound, .badge])
        loadDeliveredNotifications()
    }
    
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                              didReceive response: UNNotificationResponse,
                              withCompletionHandler completionHandler: @escaping () -> Void) {
        let userInfo = response.notification.request.content.userInfo
        
        switch response.actionIdentifier {
        case "VIEW_DEAL":
            NotificationCenter.default.post(name: .navigateToDeals, object: nil, userInfo: userInfo)
        case "REORDER":
            NotificationCenter.default.post(name: .navigateToInventory, object: nil, userInfo: userInfo)
        case UNNotificationDefaultActionIdentifier:
            // Handle tap on notification
            handleNotificationTap(userInfo: userInfo)
        default:
            break
        }
        
        completionHandler()
    }
    
    private func handleNotificationTap(userInfo: [AnyHashable: Any]) {
        if let action = userInfo["action"] as? String {
            switch action {
            case "view_deal":
                NotificationCenter.default.post(name: .navigateToDeals, object: nil, userInfo: userInfo)
            case "reorder":
                NotificationCenter.default.post(name: .navigateToInventory, object: nil, userInfo: userInfo)
            default:
                break
            }
        }
    }
}
