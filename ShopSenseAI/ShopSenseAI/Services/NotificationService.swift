import Foundation
import UserNotifications
import SwiftUI

// MARK: - Notification Service
class NotificationService: NSObject, ObservableObject {
    static let shared = NotificationService()
    
    @Published var pendingNotifications: [UNNotificationRequest] = []
    @Published var deliveredNotifications: [UNNotification] = []
    
    private override init() {
        super.init()
        UNUserNotificationCenter.current().delegate = self
    }
    
    // MARK: - Setup
    func requestAuthorization() async -> Bool {
        do {
            let granted = try await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .badge, .sound])
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
    func scheduleDailyDigest(at time: Date) {
        // Remove existing daily digest
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["daily-digest"])
        
        let content = UNMutableNotificationContent()
        content.title = "Your Daily Shopping Digest"
        content.body = "5 deals worth $127 in savings are waiting for you!"
        content.sound = .default
        content.categoryIdentifier = "DAILY_DIGEST"
        
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
            }
        }
    }
    
    // MARK: - Price Alerts
    func sendPriceAlert(_ alert: PriceAlert) {
        let content = UNMutableNotificationContent()
        
        switch alert.type {
        case .targetPriceMet:
            content.title = "🎯 Target Price Met!"
            content.body = alert.message
            content.sound = UNNotificationSound(named: UNNotificationSoundName("success.wav"))
            
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
            content.sound = UNNotificationSound(named: UNNotificationSoundName("alert.wav"))
        }
        
        content.categoryIdentifier = "PRICE_ALERT"
        content.userInfo = [
            "productId": alert.product.id.uuidString,
            "retailerId": alert.price.retailer.id,
            "price": alert.price.totalPrice
        ]
        
        let request = UNNotificationRequest(
            identifier: alert.id.uuidString,
            content: content,
            trigger: nil // Deliver immediately
        )
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Error sending price alert: \(error)")
            }
        }
    }
    
    // MARK: - Inventory Alerts
    func sendInventoryAlert(for item: InventoryItem) {
        let content = UNMutableNotificationContent()
        content.title = "🔄 Time to Restock"
        content.body = "You're running low on \(item.product.name). Current: \(item.currentQuantity), Preferred: \(item.preferredQuantity)"
        content.sound = .default
        content.categoryIdentifier = "INVENTORY_ALERT"
        content.userInfo = ["productId": item.product.id.uuidString]
        
        let request = UNNotificationRequest(
            identifier: "inventory-\(item.id.uuidString)",
            content: content,
            trigger: nil
        )
        
        UNUserNotificationCenter.current().add(request)
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
        content.userInfo = ["dealId": deal.id.uuidString]
        
        let trigger = UNTimeIntervalNotificationTrigger(
            timeInterval: alertDate.timeIntervalSinceNow,
            repeats: false
        )
        
        let request = UNNotificationRequest(
            identifier: "expiring-\(deal.id.uuidString)",
            content: content,
            trigger: trigger
        )
        
        UNUserNotificationCenter.current().add(request)
    }
    
    // MARK: - Badge Management
    func updateBadgeCount(_ count: Int) {
        Task { @MainActor in
            UIApplication.shared.applicationIconBadgeNumber = count
        }
    }
    
    func clearBadge() {
        updateBadgeCount(0)
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
        }
        return notifications
    }
    
    func removeNotification(withIdentifier identifier: String) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [identifier])
        UNUserNotificationCenter.current().removeDeliveredNotifications(withIdentifiers: [identifier])
    }
    
    func removeAllNotifications() {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
        UNUserNotificationCenter.current().removeAllDeliveredNotifications()
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
        completionHandler()
    }
    
    private func handleNotificationResponse(_ response: UNNotificationResponse) {
        let userInfo = response.notification.request.content.userInfo
        
        switch response.notification.request.content.categoryIdentifier {
        case "PRICE_ALERT":
            if let productId = userInfo["productId"] as? String {
                // Navigate to product details
                NotificationCenter.default.post(
                    name: .navigateToProduct,
                    object: nil,
                    userInfo: ["productId": productId]
                )
            }
            
        case "INVENTORY_ALERT":
            // Navigate to inventory
            NotificationCenter.default.post(name: .navigateToInventory, object: nil)
            
        case "DAILY_DIGEST":
            // Navigate to deals
            NotificationCenter.default.post(name: .navigateToDeals, object: nil)
            
        case "EXPIRING_DEAL":
            if let dealId = userInfo["dealId"] as? String {
                // Navigate to specific deal
                NotificationCenter.default.post(
                    name: .navigateToDeal,
                    object: nil,
                    userInfo: ["dealId": dealId]
                )
            }
            
        default:
            break
        }
    }
}

// MARK: - Notification Names
extension Notification.Name {
    static let navigateToProduct = Notification.Name("navigateToProduct")
    static let navigateToInventory = Notification.Name("navigateToInventory")
    static let navigateToDeals = Notification.Name("navigateToDeals")
    static let navigateToDeal = Notification.Name("navigateToDeal")
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
        
        // Register categories
        UNUserNotificationCenter.current().setNotificationCategories([
            priceAlertCategory,
            inventoryAlertCategory,
            dailyDigestCategory,
            expiringDealCategory
        ])
    }
}
