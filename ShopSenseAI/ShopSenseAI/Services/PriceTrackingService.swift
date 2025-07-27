import Foundation
import Combine

// MARK: - Price Tracking Service
class PriceTrackingService: ObservableObject {
    static let shared = PriceTrackingService()
    
    @Published var trackingItems: [TrackingItem] = []
    @Published var priceAlerts: [PriceAlert] = []
    
    private var cancellables = Set<AnyCancellable>()
    private let priceCheckInterval: TimeInterval = 3600 // 1 hour
    private var priceCheckTimer: Timer?
    
    private init() {
        startPriceMonitoring()
    }
    
    // MARK: - Public Methods
    func startTracking(for product: Product, targetPrice: Double? = nil) {
        let trackingItem = TrackingItem(
            product: product,
            targetPrice: targetPrice,
            startDate: Date(),
            isActive: true
        )
        
        trackingItems.append(trackingItem)
        checkPriceImmediately(for: product)
    }
    
    func stopTracking(for productId: UUID) {
        trackingItems.removeAll { $0.product.id == productId }
    }
    
    func updateTargetPrice(for productId: UUID, newPrice: Double?) {
        if let index = trackingItems.firstIndex(where: { $0.product.id == productId }) {
            trackingItems[index].targetPrice = newPrice
        }
    }
    
    func checkPriceImmediately(for product: Product) {
        Task {
            await fetchCurrentPrices(for: product)
        }
    }
    
    func markAlertAsRead(_ alertId: UUID) {
        if let index = priceAlerts.firstIndex(where: { $0.id == alertId }) {
            priceAlerts[index].isRead = true
        }
    }
    
    func clearReadAlerts() {
        priceAlerts.removeAll { $0.isRead }
    }
    
    // MARK: - Private Methods
    private func startPriceMonitoring() {
        // Set up periodic price checking
        priceCheckTimer = Timer.scheduledTimer(withTimeInterval: priceCheckInterval, repeats: true) { _ in
            self.checkAllPrices()
        }
    }
    
    private func checkAllPrices() {
        Task {
            for item in trackingItems where item.isActive {
                await fetchCurrentPrices(for: item.product)
            }
        }
    }
    
    private func fetchCurrentPrices(for product: Product) async {
        // In production, this would call actual price checking APIs
        // For demo, we'll simulate price fetching
        
        await MainActor.run {
            // Simulate price changes
            let mockPrices = Retailer.allRetailers.map { retailer in
                PricePoint(
                    retailer: retailer,
                    price: Double.random(in: 50...200),
                    timestamp: Date(),
                    url: "\(retailer.websiteURL)/product/\(product.id)",
                    inStock: Bool.random(),
                    shippingCost: Bool.random() ? nil : Double.random(in: 5...15)
                )
            }
            
            // Update product with new prices
            if let index = trackingItems.firstIndex(where: { $0.product.id == product.id }) {
                let lowestPrice = mockPrices.min(by: { $0.totalPrice < $1.totalPrice })
                trackingItems[index].product.currentLowestPrice = lowestPrice
                trackingItems[index].product.priceHistory.append(contentsOf: mockPrices)
                trackingItems[index].lastChecked = Date()
                
                // Calculate average price
                let allPrices = trackingItems[index].product.priceHistory.map { $0.price }
                trackingItems[index].product.averagePrice = allPrices.reduce(0, +) / Double(allPrices.count)
                
                // Check for price alerts
                checkForPriceAlerts(item: trackingItems[index], prices: mockPrices)
            }
        }
    }
    
    private func checkForPriceAlerts(item: TrackingItem, prices: [PricePoint]) {
        guard let lowestPrice = prices.min(by: { $0.totalPrice < $1.totalPrice }) else { return }
        
        // Check if price dropped below target
        if let targetPrice = item.targetPrice, lowestPrice.totalPrice <= targetPrice {
            createPriceAlert(
                type: .targetPriceMet,
                product: item.product,
                price: lowestPrice,
                message: "Target price met! \(item.product.name) is now $\(String(format: "%.2f", lowestPrice.totalPrice))"
            )
        }
        
        // Check for significant price drops
        if let previousPrice = item.product.priceHistory.dropLast().last {
            let priceDrop = previousPrice.price - lowestPrice.price
            let dropPercentage = (priceDrop / previousPrice.price) * 100
            
            if dropPercentage >= 10 { // 10% or more drop
                createPriceAlert(
                    type: .significantDrop,
                    product: item.product,
                    price: lowestPrice,
                    message: "\(Int(dropPercentage))% price drop on \(item.product.name)!"
                )
            }
        }
        
        // Check for back in stock
        if !lowestPrice.inStock {
            // Check if any previous price point was out of stock
            let wasOutOfStock = item.product.priceHistory.contains { !$0.inStock }
            if wasOutOfStock && lowestPrice.inStock {
                createPriceAlert(
                    type: .backInStock,
                    product: item.product,
                    price: lowestPrice,
                    message: "\(item.product.name) is back in stock at \(lowestPrice.retailer.name)!"
                )
            }
        }
    }
    
    private func createPriceAlert(type: PriceAlert.PriceAlertType, product: Product, price: PricePoint, message: String) {
        let alert = PriceAlert(
            type: type,
            product: product,
            price: price,
            message: message,
            timestamp: Date(),
            isRead: false
        )
        
        priceAlerts.append(alert)
        
        // Send notification
        NotificationService.shared.sendPriceAlert(alert)
    }
    
    deinit {
        priceCheckTimer?.invalidate()
    }
}

// MARK: - Price Fetching Protocols
protocol PriceProvider {
    func fetchPrice(for product: Product) async throws -> PricePoint?
}

// MARK: - Retailer-Specific Price Providers
class AmazonPriceProvider: PriceProvider {
    func fetchPrice(for product: Product) async throws -> PricePoint? {
        // Implementation for Amazon price fetching
        // This would use web scraping or Amazon's API if available
        
        // Simulate network delay
        try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
        
        guard let amazonRetailer = Retailer.allRetailers.first(where: { $0.id == "amazon" }) else {
            return nil
        }
        
        return PricePoint(
            retailer: amazonRetailer,
            price: Double.random(in: 50...200),
            timestamp: Date(),
            url: "\(amazonRetailer.websiteURL)/dp/\(product.id)",
            inStock: Bool.random(),
            shippingCost: Bool.random() ? nil : Double.random(in: 5...15)
        )
    }
}

class TargetPriceProvider: PriceProvider {
    func fetchPrice(for product: Product) async throws -> PricePoint? {
        // Implementation for Target price fetching
        try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
        
        guard let targetRetailer = Retailer.allRetailers.first(where: { $0.id == "target" }) else {
            return nil
        }
        
        return PricePoint(
            retailer: targetRetailer,
            price: Double.random(in: 50...200),
            timestamp: Date(),
            url: "\(targetRetailer.websiteURL)/p/\(product.id)",
            inStock: Bool.random(),
            shippingCost: Bool.random() ? nil : Double.random(in: 5...15)
        )
    }
}

class WalmartPriceProvider: PriceProvider {
    func fetchPrice(for product: Product) async throws -> PricePoint? {
        // Implementation for Walmart price fetching
        try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
        
        guard let walmartRetailer = Retailer.allRetailers.first(where: { $0.id == "walmart" }) else {
            return nil
        }
        
        return PricePoint(
            retailer: walmartRetailer,
            price: Double.random(in: 50...200),
            timestamp: Date(),
            url: "\(walmartRetailer.websiteURL)/ip/\(product.id)",
            inStock: Bool.random(),
            shippingCost: Bool.random() ? nil : Double.random(in: 5...15)
        )
    }
}

// MARK: - Price Aggregator
class PriceAggregator {
    private let providers: [String: PriceProvider] = [
        "amazon": AmazonPriceProvider(),
        "target": TargetPriceProvider(),
        "walmart": WalmartPriceProvider()
    ]
    
    func fetchAllPrices(for product: Product) async -> [PricePoint] {
        var prices: [PricePoint] = []
        
        await withTaskGroup(of: PricePoint?.self) { group in
            for (retailerId, provider) in providers {
                group.addTask {
                    try? await provider.fetchPrice(for: product)
                }
            }
            
            for await price in group {
                if let price = price {
                    prices.append(price)
                }
            }
        }
        
        return prices
    }
    
    func fetchPrice(from retailerId: String, for product: Product) async -> PricePoint? {
        guard let provider = providers[retailerId] else { return nil }
        return try? await provider.fetchPrice(for: product)
    }
}
