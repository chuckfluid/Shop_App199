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
                trackingItems[index].product.currentLowestPrice = mockPrices.min(by: { $0.totalPrice < $1.totalPrice })
                trackingItems[index].lastChecked = Date()
                
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
                message: "Target price met! \(item.product.name) is now $\(lowestPrice.totalPrice)"
            )
        }
        
        // Check for significant price drops
        if let previousPrice = item.product.priceHistory.last {
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
    }
    
    private func createPriceAlert(type: PriceAlertType, product: Product, price: PricePoint, message: String) {
        let alert = PriceAlert(
            id: UUID(),
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
}

// MARK: - Supporting Models
struct TrackingItem {
    var product: Product
    var targetPrice: Double?
    let startDate: Date
    var lastChecked: Date?
    var isActive: Bool
}

struct PriceAlert: Identifiable {
    let id: UUID
    let type: PriceAlertType
    let product: Product
    let price: PricePoint
    let message: String
    let timestamp: Date
    var isRead: Bool
}

enum PriceAlertType {
    case targetPriceMet
    case significantDrop
    case backInStock
    case flashSale
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
        return nil
    }
}

class TargetPriceProvider: PriceProvider {
    func fetchPrice(for product: Product) async throws -> PricePoint? {
        // Implementation for Target price fetching
        return nil
    }
}

class WalmartPriceProvider: PriceProvider {
    func fetchPrice(for product: Product) async throws -> PricePoint? {
        // Implementation for Walmart price fetching
        return nil
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
}
