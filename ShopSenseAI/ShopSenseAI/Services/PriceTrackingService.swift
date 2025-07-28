import Foundation
import Combine

class PriceTrackingService: ObservableObject {
    static let shared = PriceTrackingService()
    
    @Published var trackingItems: [TrackingItem] = []
    @Published var priceAlerts: [PriceAlert] = []
    @Published var isTracking = false
    
    private var cancellables = Set<AnyCancellable>()
    private var trackingTimer: Timer?
    private let userDefaults = UserDefaults.standard
    
    // Keys for persistence
    private let trackingItemsKey = "TrackingItems"
    private let priceAlertsKey = "PriceAlerts"
    
    private init() {
        loadTrackingItems()
        loadPriceAlerts()
        startBackgroundTracking()
    }
    
    // MARK: - Public Methods
    
    func startTracking(for product: Product, targetPrice: Double?) {
        // Check if already tracking
        if trackingItems.contains(where: { $0.product.id == product.id }) {
            return
        }
        
        let trackingItem = TrackingItem(
            product: product,
            targetPrice: targetPrice,
            addedDate: Date(),
            isActive: true,
            lastChecked: nil,
            priceHistory: []
        )
        
        trackingItems.append(trackingItem)
        saveTrackingItems()
        
        // Immediately check price
        checkPriceNow(for: product)
    }
    
    func stopTracking(for productId: UUID) {
        trackingItems.removeAll { $0.product.id == productId }
        saveTrackingItems()
    }
    
    func updateTargetPrice(for productId: UUID, targetPrice: Double?) {
        if let index = trackingItems.firstIndex(where: { $0.product.id == productId }) {
            var item = trackingItems[index]
            trackingItems[index] = TrackingItem(
                id: item.id,
                product: item.product,
                targetPrice: targetPrice,
                addedDate: item.addedDate,
                isActive: item.isActive,
                lastChecked: item.lastChecked,
                priceHistory: item.priceHistory
            )
            saveTrackingItems()
        }
    }
    
    func checkPriceNow(for product: Product) {
        Task {
            await checkPrice(for: product)
        }
    }
    
    func clearReadAlerts() {
        priceAlerts.removeAll { $0.isRead }
        savePriceAlerts()
    }
    
    func markAlertAsRead(_ alertId: UUID) {
        if let index = priceAlerts.firstIndex(where: { $0.id == alertId }) {
            priceAlerts[index].isRead = true
            savePriceAlerts()
        }
    }
    
    // MARK: - Background Tracking
    
    private func startBackgroundTracking() {
        // Check prices every hour for free users, every 15 minutes for premium
        let interval: TimeInterval = AuthenticationManager.shared.subscriptionTier == .premium ? 900 : 3600
        
        trackingTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { _ in
            self.checkAllPrices()
        }
    }
    
    private func checkAllPrices() {
        guard !trackingItems.isEmpty else { return }
        
        isTracking = true
        
        Task {
            for item in trackingItems where item.isActive {
                await checkPrice(for: item.product)
                
                // Small delay to avoid rate limiting
                try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
            }
            
            await MainActor.run {
                self.isTracking = false
            }
        }
    }
    
    @MainActor
    private func checkPrice(for product: Product) async {
        // Simulate price checking from multiple retailers
        let retailers = Retailer.allRetailers.prefix(3)
        var newPricePoints: [PricePoint] = []
        
        for retailer in retailers {
            // In production, this would make actual API calls
            let mockPrice = Double.random(in: 20...200)
            let pricePoint = PricePoint(
                retailer: retailer,
                price: mockPrice,
                timestamp: Date(),
                url: retailer.websiteURL,
                inStock: Bool.random(),
                shippingCost: Bool.random() ? nil : Double.random(in: 5...15)
            )
            newPricePoints.append(pricePoint)
        }
        
        // Update tracking item with new prices
        if let index = trackingItems.firstIndex(where: { $0.product.id == product.id }) {
            var item = trackingItems[index]
            item.priceHistory.append(contentsOf: newPricePoints)
            item.lastChecked = Date()
            trackingItems[index] = item
            
            // Check for price drops
            if let lowestPrice = newPricePoints.min(by: { $0.totalPrice < $1.totalPrice }) {
                checkForPriceAlert(product: product, currentPrice: lowestPrice, trackingItem: item)
                
                // Update product's current lowest price
                if var updatedProduct = trackingItems[index].product as? Product {
                    updatedProduct.currentLowestPrice = lowestPrice
                    trackingItems[index].product = updatedProduct
                }
            }
            
            saveTrackingItems()
        }
    }
    
    private func checkForPriceAlert(product: Product, currentPrice: PricePoint, trackingItem: TrackingItem) {
        // Check if price dropped below target
        if let targetPrice = trackingItem.targetPrice,
           currentPrice.totalPrice <= targetPrice {
            createPriceAlert(
                product: product,
                message: "Price dropped to $\(String(format: "%.2f", currentPrice.totalPrice)) at \(currentPrice.retailer.name) - below your target of $\(String(format: "%.2f", targetPrice))!"
            )
            
            // Send notification
            NotificationService.shared.sendPriceDropNotification(
                for: product,
                currentPrice: currentPrice.totalPrice,
                retailer: currentPrice.retailer.name
            )
        }
        
        // Check for significant price drop
        if let lastPrice = trackingItem.priceHistory.suffix(10).first?.totalPrice {
            let dropPercentage = ((lastPrice - currentPrice.totalPrice) / lastPrice) * 100
            
            if dropPercentage >= UserPreferencesManager.shared.priceDropThreshold {
                createPriceAlert(
                    product: product,
                    message: "Price dropped by \(Int(dropPercentage))% to $\(String(format: "%.2f", currentPrice.totalPrice)) at \(currentPrice.retailer.name)!"
                )
                
                // Send notification
                NotificationService.shared.sendPriceDropNotification(
                    for: product,
                    currentPrice: currentPrice.totalPrice,
                    retailer: currentPrice.retailer.name
                )
            }
        }
    }
    
    private func createPriceAlert(product: Product, message: String) {
        let alert = PriceAlert(
            product: product,
            timestamp: Date(),
            message: message
        )
        
        priceAlerts.insert(alert, at: 0)
        savePriceAlerts()
        
        // Post notification for UI updates
        NotificationCenter.default.post(name: .priceDropDetected, object: nil, userInfo: ["product": product])
    }
    
    // MARK: - Persistence
    
    private func saveTrackingItems() {
        if let encoded = try? JSONEncoder().encode(trackingItems) {
            userDefaults.set(encoded, forKey: trackingItemsKey)
        }
    }
    
    private func loadTrackingItems() {
        if let data = userDefaults.data(forKey: trackingItemsKey),
           let decoded = try? JSONDecoder().decode([TrackingItem].self, from: data) {
            trackingItems = decoded
        }
    }
    
    private func savePriceAlerts() {
        if let encoded = try? JSONEncoder().encode(priceAlerts) {
            userDefaults.set(encoded, forKey: priceAlertsKey)
        }
    }
    
    private func loadPriceAlerts() {
        if let data = userDefaults.data(forKey: priceAlertsKey),
           let decoded = try? JSONDecoder().decode([PriceAlert].self, from: data) {
            priceAlerts = decoded
        }
    }
    
    // MARK: - Analytics
    
    func getPriceHistory(for productId: UUID) -> [PricePoint] {
        guard let item = trackingItems.first(where: { $0.product.id == productId }) else {
            return []
        }
        return item.priceHistory
    }
    
    func getLowestPrice(for productId: UUID) -> PricePoint? {
        let history = getPriceHistory(for: productId)
        return history.min(by: { $0.totalPrice < $1.totalPrice })
    }
    
    func getAveragePrice(for productId: UUID) -> Double {
        let history = getPriceHistory(for: productId)
        guard !history.isEmpty else { return 0 }
        let total = history.reduce(0) { $0 + $1.totalPrice }
        return total / Double(history.count)
    }
    
    func getPriceTrend(for productId: UUID) -> PriceTrend {
        let history = getPriceHistory(for: productId).suffix(10)
        guard history.count >= 2 else { return .stable }
        
        let prices = history.map { $0.totalPrice }
        let firstHalf = Array(prices.prefix(prices.count / 2))
        let secondHalf = Array(prices.suffix(prices.count / 2))
        
        let firstAvg = firstHalf.reduce(0, +) / Double(firstHalf.count)
        let secondAvg = secondHalf.reduce(0, +) / Double(secondHalf.count)
        
        let changePercentage = ((secondAvg - firstAvg) / firstAvg) * 100
        
        if changePercentage > 5 {
            return .increasing
        } else if changePercentage < -5 {
            return .decreasing
        } else {
            return .stable
        }
    }
    
    enum PriceTrend {
        case increasing
        case decreasing
        case stable
    }
}
