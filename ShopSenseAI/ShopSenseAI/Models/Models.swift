import Foundation
import SwiftUI

// MARK: - Core Product Models
struct Product: Identifiable, Codable, Hashable {
    let id: UUID
    var name: String
    var description: String?
    var category: ProductCategory
    var imageURL: String?
    var barcode: String?
    var brand: String?
    var currentLowestPrice: PricePoint?
    
    init(id: UUID = UUID(), name: String, description: String?, category: ProductCategory,
         imageURL: String?, barcode: String?, brand: String?, currentLowestPrice: PricePoint? = nil) {
        self.id = id
        self.name = name
        self.description = description
        self.category = category
        self.imageURL = imageURL
        self.barcode = barcode
        self.brand = brand
        self.currentLowestPrice = currentLowestPrice
    }
    
    enum ProductCategory: String, CaseIterable, Codable {
        case electronics = "Electronics"
        case groceries = "Groceries"
        case clothing = "Clothing"
        case home = "Home"
        case health = "Health"
        case beauty = "Beauty"
        case sports = "Sports"
        case toys = "Toys"
        case books = "Books"
        case automotive = "Automotive"
        case pets = "Pets"
        case food = "Food"
        case other = "Other"
        
        var icon: String {
            switch self {
            case .electronics: return "tv"
            case .groceries: return "cart"
            case .clothing: return "tshirt"
            case .home: return "house"
            case .health: return "heart"
            case .beauty: return "sparkles"
            case .sports: return "sportscourt"
            case .toys: return "teddybear"
            case .books: return "book"
            case .automotive: return "car"
            case .pets: return "pawprint"
            case .food: return "fork.knife"
            case .other: return "square.grid.2x2"
            }
        }
        
        var color: UIColor {
            switch self {
            case .electronics: return .systemBlue
            case .groceries: return .systemGreen
            case .clothing: return .systemPurple
            case .home: return .systemOrange
            case .health: return .systemRed
            case .beauty: return .systemPink
            case .sports: return .systemIndigo
            case .toys: return .systemYellow
            case .books: return .brown
            case .automotive: return .systemGray
            case .pets: return .systemTeal
            case .food: return .systemBrown
            case .other: return .systemGray2
            }
        }
    }
}

// MARK: - Retailer Model
struct Retailer: Identifiable, Codable, Hashable {
    let id: String
    let name: String
    let websiteURL: String
    let logoURL: String?
    let supportsPriceTracking: Bool
    
    static let allRetailers = [
        Retailer(id: "amazon", name: "Amazon", websiteURL: "https://www.amazon.com", logoURL: nil, supportsPriceTracking: true),
        Retailer(id: "walmart", name: "Walmart", websiteURL: "https://www.walmart.com", logoURL: nil, supportsPriceTracking: true),
        Retailer(id: "target", name: "Target", websiteURL: "https://www.target.com", logoURL: nil, supportsPriceTracking: true),
        Retailer(id: "bestbuy", name: "Best Buy", websiteURL: "https://www.bestbuy.com", logoURL: nil, supportsPriceTracking: true),
        Retailer(id: "costco", name: "Costco", websiteURL: "https://www.costco.com", logoURL: nil, supportsPriceTracking: true),
        Retailer(id: "kroger", name: "Kroger", websiteURL: "https://www.kroger.com", logoURL: nil, supportsPriceTracking: true),
        Retailer(id: "homedepot", name: "Home Depot", websiteURL: "https://www.homedepot.com", logoURL: nil, supportsPriceTracking: true),
        Retailer(id: "cvs", name: "CVS", websiteURL: "https://www.cvs.com", logoURL: nil, supportsPriceTracking: true)
    ]
}

// MARK: - Price Models
struct PricePoint: Identifiable, Codable, Hashable {
    let id: UUID
    let retailer: Retailer
    let price: Double
    let timestamp: Date
    let url: String
    let inStock: Bool
    let shippingCost: Double?
    
    var totalPrice: Double {
        return price + (shippingCost ?? 0)
    }
    
    init(id: UUID = UUID(), retailer: Retailer, price: Double, timestamp: Date,
         url: String, inStock: Bool, shippingCost: Double?) {
        self.id = id
        self.retailer = retailer
        self.price = price
        self.timestamp = timestamp
        self.url = url
        self.inStock = inStock
        self.shippingCost = shippingCost
    }
}

struct PriceHistory: Codable {
    let productId: UUID
    let history: [PricePoint]
    
    var lowestPrice: PricePoint? {
        history.min(by: { $0.totalPrice < $1.totalPrice })
    }
    
    var highestPrice: PricePoint? {
        history.max(by: { $0.totalPrice < $1.totalPrice })
    }
    
    var averagePrice: Double {
        guard !history.isEmpty else { return 0 }
        let total = history.reduce(0) { $0 + $1.totalPrice }
        return total / Double(history.count)
    }
}

// MARK: - Shopping List Models
struct ShoppingListItem: Identifiable, Codable {
    let id: UUID
    var product: Product
    var quantity: Int
    var priority: Priority
    var notes: String?
    var isPurchased: Bool
    var dateAdded: Date
    var isTracking: Bool
    var targetPrice: Double?
    
    init(id: UUID = UUID(), product: Product, quantity: Int = 1,
         priority: Priority = .normal, notes: String? = nil,
         isPurchased: Bool = false, dateAdded: Date = Date(),
         isTracking: Bool = false, targetPrice: Double? = nil) {
        self.id = id
        self.product = product
        self.quantity = quantity
        self.priority = priority
        self.notes = notes
        self.isPurchased = isPurchased
        self.dateAdded = dateAdded
        self.isTracking = isTracking
        self.targetPrice = targetPrice
    }
    
    enum Priority: String, CaseIterable, Codable {
        case urgent = "Urgent"
        case normal = "Normal"
        case low = "Low"
    }
}

// MARK: - Inventory Models
struct InventoryItem: Identifiable, Codable {
    let id: UUID
    var product: Product
    var currentQuantity: Int
    var preferredQuantity: Int
    var reorderThreshold: Int
    var lastPurchaseDate: Date?
    var averageConsumptionDays: Int?
    var autoReorder: Bool
    
    init(id: UUID = UUID(), product: Product, currentQuantity: Int,
         preferredQuantity: Int, lastPurchaseDate: Date? = nil,
         averageConsumptionDays: Int? = nil, autoReorder: Bool = false,
         reorderThreshold: Int) {
        self.id = id
        self.product = product
        self.currentQuantity = currentQuantity
        self.preferredQuantity = preferredQuantity
        self.lastPurchaseDate = lastPurchaseDate
        self.averageConsumptionDays = averageConsumptionDays
        self.autoReorder = autoReorder
        self.reorderThreshold = reorderThreshold
    }
    
    var needsReorder: Bool {
        return currentQuantity <= reorderThreshold
    }
    
    var stockLevel: StockLevel {
        let ratio = Double(currentQuantity) / Double(preferredQuantity)
        if ratio <= 0.1 {
            return .critical
        } else if ratio <= 0.25 {
            return .low
        } else if ratio <= 0.5 {
            return .medium
        } else {
            return .good
        }
    }
    
    var estimatedRunOutDate: Date? {
        guard let days = averageConsumptionDays, currentQuantity > 0 else { return nil }
        let daysRemaining = Double(currentQuantity) * Double(days)
        return Date().addingTimeInterval(daysRemaining * 86400)
    }
    
    enum StockLevel {
        case critical
        case low
        case medium
        case good
    }
}

// MARK: - Deal Models
struct DealAlert: Identifiable, Codable {
    let id: UUID
    let product: Product
    let retailer: Retailer
    let currentPrice: Double
    let previousPrice: Double
    let discount: Double
    let discountPercentage: Double
    let alertDate: Date
    let expiryDate: Date?
    let dealType: DealType
    
    init(id: UUID = UUID(), product: Product, retailer: Retailer,
         currentPrice: Double, previousPrice: Double, discount: Double,
         discountPercentage: Double, alertDate: Date, expiryDate: Date?,
         dealType: DealType) {
        self.id = id
        self.product = product
        self.retailer = retailer
        self.currentPrice = currentPrice
        self.previousPrice = previousPrice
        self.discount = discount
        self.discountPercentage = discountPercentage
        self.alertDate = alertDate
        self.expiryDate = expiryDate
        self.dealType = dealType
    }
    
    var savings: Double {
        return previousPrice - currentPrice
    }
    
    enum DealType: String, CaseIterable, Codable {
        case priceDropAlert = "Price Drop"
        case flashSale = "Flash Sale"
        case couponAvailable = "Coupon"
        case bundleDeal = "Bundle Deal"
        case seasonalSale = "Seasonal Sale"
    }
}

// MARK: - Budget Models
struct Budget: Codable {
    var monthlyLimit: Double
    var categories: [Product.ProductCategory: Double]
    var currentMonthSpending: Double
    var alerts: [BudgetAlert]
    
    var remainingBudget: Double {
        return monthlyLimit - currentMonthSpending
    }
    
    var percentageUsed: Double {
        guard monthlyLimit > 0 else { return 0 }
        return (currentMonthSpending / monthlyLimit) * 100
    }
}

struct BudgetAlert: Codable, Identifiable {
    let id: UUID
    let threshold: Double // Percentage (0.0 - 1.0)
    let message: String
    var hasBeenTriggered: Bool
    
    init(id: UUID = UUID(), threshold: Double, message: String, hasBeenTriggered: Bool = false) {
        self.id = id
        self.threshold = threshold
        self.message = message
        self.hasBeenTriggered = hasBeenTriggered
    }
}

// MARK: - Purchase History
struct Purchase: Identifiable, Codable {
    let id: UUID
    let product: Product
    let retailer: Retailer
    let purchaseDate: Date
    let price: Double
    let quantity: Int
    let totalAmount: Double
    
    init(id: UUID = UUID(), product: Product, retailer: Retailer,
         purchaseDate: Date, price: Double, quantity: Int, totalAmount: Double) {
        self.id = id
        self.product = product
        self.retailer = retailer
        self.purchaseDate = purchaseDate
        self.price = price
        self.quantity = quantity
        self.totalAmount = totalAmount
    }
}

// MARK: - AI Recommendation Models
struct AIRecommendation: Identifiable, Codable {
    let id: UUID
    let product: Product
    let reason: String
    let confidenceScore: Double
    let potentialSavings: Double?
    let alternativeProducts: [Product]
    let bestTimeToBuy: DateRange?
    let createdAt: Date
    let type: RecommendationType
    
    init(id: UUID = UUID(), product: Product, reason: String,
         confidenceScore: Double, potentialSavings: Double?,
         alternativeProducts: [Product], bestTimeToBuy: DateRange?,
         createdAt: Date, type: RecommendationType) {
        self.id = id
        self.product = product
        self.reason = reason
        self.confidenceScore = confidenceScore
        self.potentialSavings = potentialSavings
        self.alternativeProducts = alternativeProducts
        self.bestTimeToBuy = bestTimeToBuy
        self.createdAt = createdAt
        self.type = type
    }
    
    enum RecommendationType: String, Codable {
        case priceDrop = "Price Drop"
        case newDeal = "New Deal"
        case restockReminder = "Restock"
        case alternative = "Alternative"
        case seasonal = "Seasonal"
        case trending = "Trending"
        case bundle = "Bundle"
        case stockUp = "Stock Up"
    }
    
    struct DateRange: Codable {
        let start: Date
        let end: Date
        
        var description: String {
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            return "\(formatter.string(from: start)) - \(formatter.string(from: end))"
        }
    }
}

// MARK: - Price Prediction Model
struct PricePrediction: Codable {
    let trend: String // "Increasing", "Decreasing", "Stable", "Volatile"
    let optimalBuyDate: Date
    let expectedPriceRange: PriceRange
    let confidence: Double
    
    struct PriceRange: Codable {
        let min: Double
        let max: Double
    }
}

// MARK: - User Preferences
struct ClaudeUserPreferences: Codable {
    var priceDropThreshold: Double
    var preferredRetailers: Set<String>
    var budgetAlertThreshold: Double
    var notificationsEnabled: Bool
    var autoReorderEnabled: Bool
    var priceCheckFrequency: TimeInterval
    var dealCategories: [Product.ProductCategory]
}

// MARK: - Notification Models
struct PriceAlert: Identifiable, Codable {
    let id: UUID
    let product: Product
    let timestamp: Date
    let message: String
    var isRead: Bool
    
    init(id: UUID = UUID(), product: Product, timestamp: Date, message: String, isRead: Bool = false) {
        self.id = id
        self.product = product
        self.timestamp = timestamp
        self.message = message
        self.isRead = isRead
    }
}

// MARK: - Tracking Models
struct TrackingItem: Identifiable, Codable {
    let id: UUID
    let product: Product
    let targetPrice: Double?
    let addedDate: Date
    var isActive: Bool
    var lastChecked: Date?
    var priceHistory: [PricePoint]
    
    init(id: UUID = UUID(), product: Product, targetPrice: Double?,
         addedDate: Date = Date(), isActive: Bool = true,
         lastChecked: Date? = nil, priceHistory: [PricePoint] = []) {
        self.id = id
        self.product = product
        self.targetPrice = targetPrice
        self.addedDate = addedDate
        self.isActive = isActive
        self.lastChecked = lastChecked
        self.priceHistory = priceHistory
    }
}

// MARK: - App-wide Notification Names
extension Notification.Name {
    static let priceDropDetected = Notification.Name("priceDropDetected")
    static let inventoryLow = Notification.Name("inventoryLow")
    static let dealExpiring = Notification.Name("dealExpiring")
    static let budgetExceeded = Notification.Name("budgetExceeded")
    static let newRecommendation = Notification.Name("newRecommendation")
    static let navigateToDeals = Notification.Name("navigateToDeals")
    static let navigateToInventory = Notification.Name("navigateToInventory")
    static let navigateToProduct = Notification.Name("navigateToProduct")
}

// MARK: - Error Types
enum ShopSenseError: LocalizedError {
    case networkError
    case parsingError
    case authenticationError
    case subscriptionRequired
    case invalidData
    
    var errorDescription: String? {
        switch self {
        case .networkError:
            return "Network connection error. Please check your internet connection."
        case .parsingError:
            return "Error processing data. Please try again."
        case .authenticationError:
            return "Authentication failed. Please sign in again."
        case .subscriptionRequired:
            return "This feature requires a premium subscription."
        case .invalidData:
            return "Invalid data received. Please try again."
        }
    }
}
