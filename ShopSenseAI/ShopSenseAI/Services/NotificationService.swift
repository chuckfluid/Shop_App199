import Foundation
import UserNotifications
import SwiftUI

// MARK: - Notification Service
class NotificationService: NSObject, ObservableObject {
    static let shared = NotificationService()
    
    @Published var pendingNotifications: [UNNotificationRequest] = []
    @Published var deliveredNotifications: [UNNotification] = []
    @Published var unreadCount: Int = 0
    
    private override init() {
        super.init()
        UNUserNotificationCenter.current().delegate = self
        setupNotificationCategories()
    }
    
    // MARK: - Setup
    func requestAuthorization() async -> Bool {
        do {
            let granted = try await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .badge, .sound])
            
            if granted {
                await setupNotificationCategories()
            }
            
            return granted
        } catch {
            print("Error requesting notification authorization: \(error)")
            return false
        }
    }
    
    func checkAuthorizationStatus() async -> UNAuthorizationStatus {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        return settings.authorizationStatus
    }
    
    // MARK: - Daily Digest
    func scheduleDailyDigest(at time: Date, userPreferences: UserPreferencesManager) {
        guard userPreferences.notificationsEnabled && userPreferences.dailyDigestEnabled else {
            removeDailyDigest()
            return
        }
        
        // Remove existing daily digest
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["daily-digest"])
        
        let content = UNMutableNotificationContent()
        content.title = "Your Daily Shopping Digest"
        content.body = "Check out today's personalized deals and savings opportunities!"
        content.sound = .default
        content.categoryIdentifier = "DAILY_DIGEST"
        content.badge = NSNumber(value: unreadCount + 1)
        
        // Create date components for the scheduled time
        let calendar = Calendar.current
        let components = calendar.dateComponents([.hour, .minute], from: time)
        
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
        
        let request = UNNotificationRequest(
            identifier: "daily-digest",
            content: content,
            trigger: trigger
        )
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Error scheduling daily digest: \(error)")
            } else {
                print("Daily digest scheduled for \(components.hour ?? 0):\(String(format: "%02d", components.minute ?? 0))")
            }
        }
    }
    
    func removeDailyDigest() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["daily-digest"])
    }
    
    // MARK: - Price Alerts
    func sendPriceAlert(_ alert: PriceAlert) {
        let content = UNMutableNotificationContent()
        
        switch alert.type {
        case .targetPriceMet:
            content.title = "🎯 Target Price Met!"
            content.body = alert.message
            content.sound = .default // Using default sound instead of custom
            
        case .significantDrop:
            content.title = "📉 Major Price Drop!"
            content.body = alert.message
            content.sound = .default
            
        case .backInStock:
            content.title = "📦 Back in Stock!"
            content.body = "\(alert.product.name) is available again at \(alert.price.retailer.name)"
            content.sound = .default
            
        case .flashSale:
            content.title = "⚡ Flash Sale Alert!"
            content.body = alert.message
            content.sound = .default // Using default sound instead of custom
        }
        
        content.categoryIdentifier = "PRICE_ALERT"
        content.badge = NSNumber(value: unreadCount + 1)
        content.userInfo = [
            "productId": alert.product.id.uuidString,
            "retailerId": alert.price.retailer.id,
            "price": alert.price.totalPrice,
            "type": "price_alert"
        ]
        
        let request = UNNotificationRequest(
            identifier: alert.id.uuidString,
            content: content,
            trigger: nil // Deliver immediately
        )
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Error sending price alert: \(error)")
            } else {
                print("Price alert sent for \(alert.product.name)")
            }
        }
        
        // Update unread count
        incrementUnreadCount()
    }
    
    // MARK: - Inventory Alerts
    func sendInventoryAlert(for item: InventoryItem) {
        let content = UNMutableNotificationContent()
        content.title = "🔄 Time to Restock"
        content.body = "You're running low on \(item.product.name). Current: \(item.currentQuantity), Preferred: \(item.preferredQuantity)"
        content.sound = .default
        content.categoryIdentifier = "INVENTORY_ALERT"
        content.badge = NSNumber(value: unreadCount + 1)
        content.userInfo = [
            "productId": item.product.id.uuidString,
            "inventoryItemId": item.id.uuidString,
            "type": "inventory_alert"
        ]
        
        let request = UNNotificationRequest(
            identifier: "inventory-\(item.id.uuidString)",
            content: content,
            trigger: nil
        )
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Error sending inventory alert: \(error)")
            } else {
                print("Inventory alert sent for \(item.product.name)")
            }
        }
        
        incrementUnreadCount()
    }
    
    // MARK: - Deal Expiring Alerts
    func scheduleDealExpiringAlert(for deal: DealAlert) {
        guard let expiryDate = deal.expiryDate else { return }
        
        // Schedule alert 1 hour before expiry
        let alertDate = expiryDate.addingTimeInterval(-3600)
        guard alertDate > Date() else { return }
        
        let content = UNMutableNotificationContent()
        content.title = "⏰ Deal Expiring Soon!"
        content.body = "\(deal.product.name) deal expires in 1 hour. Save $\(String(format: "%.2f", deal.savings))"
        content.sound = .default
        content.categoryIdentifier = "EXPIRING_DEAL"
        content.badge = NSNumber(value: unreadCount + 1)
        content.userInfo = [
            "dealId": deal.id.uuidString,
            "productId": deal.product.id.uuidString,
            "type": "expiring_deal"
        ]
        
        let trigger = UNTimeIntervalNotificationTrigger(
            timeInterval: alertDate.timeIntervalSinceNow,
            repeats: false
        )
        
        let request = UNNotificationRequest(
            identifier: "expiring-\(deal.id.uuidString)",
            content: content,
            trigger: trigger
        )
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Error scheduling expiring deal alert: \(error)")
            } else {
                print("Expiring deal alert scheduled for \(deal.product.name)")
            }
        }
    }
    
    // MARK: - AI Recommendations
    func sendAIRecommendation(_ recommendation: AIRecommendation) {
        let content = UNMutableNotificationContent()
        content.title = "🤖 AI Shopping Insight"
        content.body = "\(recommendation.reason) - Potential savings: $\(String(format: "%.2f", recommendation.potentialSavings ?? 0))"
        content.sound = .default
        content.categoryIdentifier = "AI_RECOMMENDATION"
        content.badge = NSNumber(value: unreadCount + 1)
        content.userInfo = [
            "recommendationId": recommendation.id.uuidString,
            "productId": recommendation.product.id.uuidString,
            "type": "ai_recommendation"
        ]
        
        let request = UNNotificationRequest(
            identifier: "ai-rec-\(recommendation.id.uuidString)",
            content: content,
            trigger: nil
        )
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Error sending AI recommendation: \(error)")
            } else {
                print("AI recommendation sent for \(recommendation.product.name)")
            }
        }
        
        incrementUnreadCount()
    }
    
    // MARK: - Badge Management
    func updateBadgeCount(_ count: Int) {
        Task { @MainActor in
            UIApplication.shared.applicationIconBadgeNumber = count
            unreadCount = count
        }
    }
    
    func clearBadge() {
        updateBadgeCount(0)
    }
    
    func incrementUnreadCount() {
        Task { @MainActor in
            unreadCount += 1
            UIApplication.shared.applicationIconBadgeNumber = unreadCount
        }
    }
    
    func decrementUnreadCount() {
        Task { @MainActor in
            unreadCount = max(0, unreadCount - 1)
            UIApplication.shared.applicationIconBadgeNumber = unreadCount
        }
    }
    
    // MARK: - Notification Management
    func getPendingNotifications() async -> [UNNotificationRequest] {
        let requests = await UNUserNotificationCenter.current().pendingNotificationRequests()
        await MainActor.run {
            self.pendingNotifications = requests
        }
        return requests
    }
    
    func getDeliveredNotifications() async -> [UNNotification] {
        let notifications = await UNUserNotificationCenter.current().deliveredNotifications()
        await MainActor.run {
            self.deliveredNotifications = notifications
            // Update unread count based on delivered notifications
            self.unreadCount = notifications.count
        }
        return notifications
    }
    
    func removeNotification(withIdentifier identifier: String) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [identifier])
        UNUserNotificationCenter.current().removeDeliveredNotifications(withIdentifiers: [identifier])
        decrementUnreadCount()
    }
    
    func removeAllNotifications() {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
        UNUserNotificationCenter.current().removeAllDeliveredNotifications()
        clearBadge()
    }
    
    // MARK: - Settings Integration
    func updateNotificationSettings(with preferences: UserPreferencesManager) {
        if preferences.notificationsEnabled {
            if preferences.dailyDigestEnabled {
                scheduleDailyDigest(at: preferences.digestTime, userPreferences: preferences)
            } else {
                removeDailyDigest()
            }
        } else {
            removeAllNotifications()
        }
    }
}

// MARK: - UNUserNotificationCenterDelegate
extension NotificationService: UNUserNotificationCenterDelegate {
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        // Show notification even when app is in foreground
        completionHandler([.banner, .sound, .badge])
    }
    
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                didReceive response: UNNotificationResponse,
                                withCompletionHandler completionHandler: @escaping () -> Void) {
        // Handle notification tap
        handleNotificationResponse(response)
        
        // Mark notification as read
        decrementUnreadCount()
        
        completionHandler()
    }
    
    private func handleNotificationResponse(_ response: UNNotificationResponse) {
        let userInfo = response.notification.request.content.userInfo
        let actionIdentifier = response.actionIdentifier
        
        // Handle specific actions
        switch actionIdentifier {
        case "VIEW_DEAL", "SHOP_NOW":
            if let productId = userInfo["productId"] as? String {
                NotificationCenter.default.post(
                    name: .navigateToProduct,
                    object: nil,
                    userInfo: ["productId": productId]
                )
            }
            
        case "REORDER":
            if let productId = userInfo["productId"] as? String {
                NotificationCenter.default.post(
                    name: .navigateToInventory,
                    object: nil,
                    userInfo: ["productId": productId, "action": "reorder"]
                )
            }
            
        case "REMIND_LATER":
            // Schedule reminder for 4 hours later
            if let inventoryItemId = userInfo["inventoryItemId"] as? String {
                scheduleReminderNotification(for: inventoryItemId, delay: 4 * 3600)
            }
            
        case UNNotificationDefaultActionIdentifier:
            // Handle default tap action based on notification type
            switch response.notification.request.content.categoryIdentifier {
            case "PRICE_ALERT":
                if let productId = userInfo["productId"] as? String {
                    NotificationCenter.default.post(
                        name: .navigateToProduct,
                        object: nil,
                        userInfo: ["productId": productId]
                    )
                }
                
            case "INVENTORY_ALERT":
                NotificationCenter.default.post(name: .navigateToInventory, object: nil)
                
            case "DAILY_DIGEST":
                NotificationCenter.default.post(name: .navigateToDeals, object: nil)
                
            case "EXPIRING_DEAL":
                if let dealId = userInfo["dealId"] as? String {
                    NotificationCenter.default.post(
                        name: .navigateToDeal,
                        object: nil,
                        userInfo: ["dealId": dealId]
                    )
                }
                
            case "AI_RECOMMENDATION":
                if let productId = userInfo["productId"] as? String {
                    NotificationCenter.default.post(
                        name: .navigateToProduct,
                        object: nil,
                        userInfo: ["productId": productId]
                    )
                }
                
            default:
                break
            }
            
        default:
            break
        }
    }
    
    private func scheduleReminderNotification(for inventoryItemId: String, delay: TimeInterval) {
        let content = UNMutableNotificationContent()
        content.title = "🔔 Reminder: Low Stock"
        content.body = "Don't forget to restock this item!"
        content.sound = .default
        content.categoryIdentifier = "INVENTORY_REMINDER"
        content.userInfo = [
            "inventoryItemId": inventoryItemId,
            "type": "reminder"
        ]
        
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: delay, repeats: false)
        
        let request = UNNotificationRequest(
            identifier: "reminder-\(inventoryItemId)-\(Date().timeIntervalSince1970)",
            content: content,
            trigger: trigger
        )
        
        UNUserNotificationCenter.current().add(request)
    }
}

// MARK: - Notification Names
extension Notification.Name {
    static let navigateToProduct = Notification.Name("navigateToProduct")
    static let navigateToInventory = Notification.Name("navigateToInventory")
    static let navigateToDeals = Notification.Name("navigateToDeals")
    static let navigateToDeal = Notification.Name("navigateToDeal")
    static let notificationReceived = Notification.Name("notificationReceived")
}

// MARK: - Notification Categories Setup
extension NotificationService {
    func setupNotificationCategories() {
        // Price Alert Actions
        let viewDealAction = UNNotificationAction(
            identifier: "VIEW_DEAL",
            title: "View Deal",
            options: [.foreground]
        )
        
        let dismissAction = UNNotificationAction(
            identifier: "DISMISS",
            title: "Dismiss",
            options: [.destructive]
        )
        
        let priceAlertCategory = UNNotificationCategory(
            identifier: "PRICE_ALERT",
            actions: [viewDealAction, dismissAction],
            intentIdentifiers: [],
            options: []
        )
        
        // Inventory Alert Actions
        let reorderAction = UNNotificationAction(
            identifier: "REORDER",
            title: "Reorder Now",
            options: [.foreground]
        )
        
        let remindLaterAction = UNNotificationAction(
            identifier: "REMIND_LATER",
            title: "Remind Later",
            options: []
        )
        
        let inventoryAlertCategory = UNNotificationCategory(
            identifier: "INVENTORY_ALERT",
            actions: [reorderAction, remindLaterAction],
            intentIdentifiers: [],
            options: []
        )
        
        // Inventory Reminder Category
        let inventoryReminderCategory = UNNotificationCategory(
            identifier: "INVENTORY_REMINDER",
            actions: [reorderAction, dismissAction],
            intentIdentifiers: [],
            options: []
        )
        
        // Daily Digest Category
        let dailyDigestCategory = UNNotificationCategory(
            identifier: "DAILY_DIGEST",
            actions: [viewDealAction],
            intentIdentifiers: [],
            options: []
        )
        
        // Expiring Deal Category
        let shopNowAction = UNNotificationAction(
            identifier: "SHOP_NOW",
            title: "Shop Now",
            options: [.foreground]
        )
        
        let expiringDealCategory = UNNotificationCategory(
            identifier: "EXPIRING_DEAL",
            actions: [shopNowAction, dismissAction],
            intentIdentifiers: [],
            options: []
        )
        
        // AI Recommendation Category
        let aiRecommendationCategory = UNNotificationCategory(
            identifier: "AI_RECOMMENDATION",
            actions: [viewDealAction, dismissAction],
            intentIdentifiers: [],
            options: []
        )
        
        // Register categories
        UNUserNotificationCenter.current().setNotificationCategories([
            priceAlertCategory,
            inventoryAlertCategory,
            inventoryReminderCategory,
            dailyDigestCategory,
            expiringDealCategory,
            aiRecommendationCategory
        ])
    }
}

// MARK: - Testing and Debug Methods
extension NotificationService {
    func sendTestNotification() {
        let content = UNMutableNotificationContent()
        content.title = "Test Notification"
        content.body = "This is a test notification from ShopSense AI"
        content.sound = .default
        
        let request = UNNotificationRequest(
            identifier: "test-\(Date().timeIntervalSince1970)",
            content: content,
            trigger: nil
        )
        
        UNUserNotificationCenter.current().add(request)
    }
    
    func printNotificationStatus() async {
        let pending = await getPendingNotifications()
        let delivered = await getDeliveredNotifications()
        
        print("📱 Notification Status:")
        print("   Pending: \(pending.count)")
        print("   Delivered: \(delivered.count)")
        print("   Unread Count: \(unreadCount)")
        print("   Badge Number: \(UIApplication.shared.applicationIconBadgeNumber)")
    }
}
