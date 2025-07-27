import Foundation

// MARK: - Product Model
struct Product: Identifiable, Codable, Hashable {
    let id: UUID
    let name: String
    let description: String
    let category: ProductCategory
    let imageURL: String?
    let barcode: String?
    let brand: String?
    
    var priceHistory: [PricePoint] = []
    var currentLowestPrice: PricePoint?
    var averagePrice: Double?
    
    enum CodingKeys: String, CodingKey {
        case id, name, description, category, imageURL, barcode, brand
        case priceHistory, currentLowestPrice, averagePrice
    }
    
    init(id: UUID = UUID(), name: String, description: String, category: ProductCategory,
         imageURL: String? = nil, barcode: String? = nil, brand: String? = nil,
         priceHistory: [PricePoint] = [], currentLowestPrice: PricePoint? = nil,
         averagePrice: Double? = nil) {
        self.id = id
        self.name = name
        self.description = description
        self.category = category
        self.imageURL = imageURL
        self.barcode = barcode
        self.brand = brand
        self.priceHistory = priceHistory
        self.currentLowestPrice = currentLowestPrice
        self.averagePrice = averagePrice
    }
    
    enum ProductCategory: String, CaseIterable, Codable {
        case electronics = "Electronics"
        case groceries = "Groceries"
        case clothing = "Clothing"
        case home = "Home & Garden"
        case beauty = "Beauty & Personal Care"
        case sports = "Sports & Outdoors"
        case toys = "Toys & Games"
        case food = "Food & Beverages"
        case health = "Health & Beauty"
        case books = "Books"
        case other = "Other"
    }
    
    // Hashable conformance
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: Product, rhs: Product) -> Bool {
        return lhs.id == rhs.id
    }
}

// MARK: - Price Point
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
         url: String, inStock: Bool, shippingCost: Double? = nil) {
        self.id = id
        self.retailer = retailer
        self.price = price
        self.timestamp = timestamp
        self.url = url
        self.inStock = inStock
        self.shippingCost = shippingCost
    }
    
    // Hashable conformance
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: PricePoint, rhs: PricePoint) -> Bool {
        return lhs.id == rhs.id
    }
}

// MARK: - Retailer
struct Retailer: Identifiable, Codable, Hashable {
    let id: String
    let name: String
    let logoURL: String?
    let websiteURL: String
    
    init(id: String, name: String, logoURL: String? = nil, websiteURL: String) {
        self.id = id
        self.name = name
        self.logoURL = logoURL
        self.websiteURL = websiteURL
    }
    
    static let allRetailers = [
        Retailer(id: "amazon", name: "Amazon", logoURL: nil, websiteURL: "https://amazon.com"),
        Retailer(id: "target", name: "Target", logoURL: nil, websiteURL: "https://target.com"),
        Retailer(id: "walmart", name: "Walmart", logoURL: nil, websiteURL: "https://walmart.com"),
        Retailer(id: "bestbuy", name: "Best Buy", logoURL: nil, websiteURL: "https://bestbuy.com"),
        Retailer(id: "costco", name: "Costco", logoURL: nil, websiteURL: "https://costco.com"),
        Retailer(id: "ebay", name: "eBay", logoURL: nil, websiteURL: "https://ebay.com")
    ]
    
    // Hashable conformance
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: Retailer, rhs: Retailer) -> Bool {
        return lhs.id == rhs.id
    }
}

// MARK: - Shopping List Item
struct ShoppingListItem: Identifiable, Codable {
    let id: UUID
    var product: Product
    var targetPrice: Double?
    var quantity: Int
    var priority: Priority
    var notes: String?
    let addedDate: Date
    var isTracking: Bool
    
    init(id: UUID = UUID(), product: Product, targetPrice: Double? = nil,
         quantity: Int, priority: Priority, notes: String? = nil,
         addedDate: Date = Date(), isTracking: Bool = false) {
        self.id = id
        self.product = product
        self.targetPrice = targetPrice
        self.quantity = quantity
        self.priority = priority
        self.notes = notes
        self.addedDate = addedDate
        self.isTracking = isTracking
    }
    
    enum Priority: String, CaseIterable, Codable {
        case low = "Low"
        case medium = "Medium"
        case high = "High"
        case urgent = "Urgent"
    }
}

// MARK: - Price Prediction
struct PricePrediction: Codable {
    let trend: String
    let optimalBuyDate: Date
    let expectedPriceRange: PriceRange
    let confidence: Double
    
    struct PriceRange: Codable {
        let min: Double
        let max: Double
    }
}

// MARK: - Deal Alert
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
         discountPercentage: Double, alertDate: Date, expiryDate: Date? = nil,
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
    
    enum DealType: String, Codable, CaseIterable {
        case priceDropAlert = "Price Drop"
        case flashSale = "Flash Sale"
        case couponAvailable = "Coupon Available"
        case bundleDeal = "Bundle Deal"
        case seasonalSale = "Seasonal Sale"
    }
}

// MARK: - Household Inventory Item
struct InventoryItem: Identifiable, Codable {
    let id: UUID
    var product: Product
    var currentQuantity: Int
    var preferredQuantity: Int
    var lastPurchaseDate: Date?
    var averageConsumptionDays: Int?
    var autoReorder: Bool
    var reorderThreshold: Int
    
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
    
    var estimatedRunOutDate: Date? {
        guard let avgDays = averageConsumptionDays else { return nil }
        
        // If we have a last purchase date, calculate from there
        if let lastPurchase = lastPurchaseDate {
            return Calendar.current.date(byAdding: .day, value: avgDays, to: lastPurchase)
        }
        
        // Otherwise, calculate from current date based on current consumption
        let daysLeft = (currentQuantity * avgDays) / preferredQuantity
        return Calendar.current.date(byAdding: .day, value: daysLeft, to: Date())
    }
    
    var stockLevel: StockLevel {
        let ratio = Double(currentQuantity) / Double(preferredQuantity)
        if ratio <= 0.25 {
            return .critical
        } else if ratio <= 0.5 {
            return .low
        } else if ratio <= 0.75 {
            return .medium
        } else {
            return .good
        }
    }
    
    enum StockLevel {
        case critical, low, medium, good
        
        var color: String {
            switch self {
            case .critical: return "red"
            case .low: return "orange"
            case .medium: return "yellow"
            case .good: return "green"
            }
        }
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
    
    var pricePerUnit: Double {
        return totalAmount / Double(quantity)
    }
    
    var savings: Double? {
        guard let averagePrice = product.averagePrice else { return nil }
        return (averagePrice - pricePerUnit) * Double(quantity)
    }
}

// MARK: - AI Recommendation
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
         confidenceScore: Double, potentialSavings: Double? = nil,
         alternativeProducts: [Product] = [], bestTimeToBuy: DateRange? = nil,
         createdAt: Date = Date(), type: RecommendationType) {
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
    
    struct DateRange: Codable {
        let start: Date
        let end: Date
        
        var description: String {
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            return "\(formatter.string(from: start)) - \(formatter.string(from: end))"
        }
    }
    
    enum RecommendationType: String, Codable {
        case priceDrop = "Price Drop"
        case stockUp = "Stock Up"
        case alternative = "Alternative Product"
        case timing = "Optimal Timing"
        case budgetOptimization = "Budget Optimization"
    }
}

// MARK: - User Budget
struct Budget: Codable {
    var monthlyLimit: Double
    var categories: [Product.ProductCategory: Double]
    var currentMonthSpending: Double
    var alerts: [BudgetAlert]
    
    struct BudgetAlert: Codable {
        let threshold: Double // percentage (e.g., 0.8 for 80%)
        let message: String
    }
    
    var remainingBudget: Double {
        return monthlyLimit - currentMonthSpending
    }
    
    var budgetUtilization: Double {
        guard monthlyLimit > 0 else { return 0 }
        return currentMonthSpending / monthlyLimit
    }
    
    var isOverBudget: Bool {
        return currentMonthSpending > monthlyLimit
    }
    
    func categorySpending(for category: Product.ProductCategory) -> Double {
        return categories[category] ?? 0
    }
    
    func categoryUtilization(for category: Product.ProductCategory) -> Double {
        let limit = categories[category] ?? 0
        let spent = categorySpending(for: category)
        guard limit > 0 else { return 0 }
        return spent / limit
    }
}

// MARK: - Price Alert Models
struct PriceAlert: Identifiable, Codable {
    let id: UUID
    let type: PriceAlertType
    let product: Product
    let price: PricePoint
    let message: String
    let timestamp: Date
    var isRead: Bool
    
    init(id: UUID = UUID(), type: PriceAlertType, product: Product,
         price: PricePoint, message: String, timestamp: Date, isRead: Bool = false) {
        self.id = id
        self.type = type
        self.product = product
        self.price = price
        self.message = message
        self.timestamp = timestamp
        self.isRead = isRead
    }
    
    enum PriceAlertType: String, CaseIterable, Codable {
        case targetPriceMet = "Target Price Met"
        case significantDrop = "Significant Drop"
        case backInStock = "Back In Stock"
        case flashSale = "Flash Sale"
    }
}

// MARK: - User Preferences Model (Struct version for Claude API)
struct ClaudeUserPreferences: Codable {
    var priceDropThreshold: Double = 10.0 // Percentage
    var preferredRetailers: Set<String> = ["amazon", "target", "walmart"]
    var budgetAlertThreshold: Double = 0.8 // 80% of budget
    var notificationsEnabled: Bool = true
    var autoReorderEnabled: Bool = false
    var priceCheckFrequency: TimeInterval = 3600 // 1 hour in seconds
    var dealCategories: [Product.ProductCategory] = Product.ProductCategory.allCases
    
    init() {}
    
    init(priceDropThreshold: Double,
         preferredRetailers: Set<String>,
         budgetAlertThreshold: Double,
         notificationsEnabled: Bool,
         autoReorderEnabled: Bool,
         priceCheckFrequency: TimeInterval,
         dealCategories: [Product.ProductCategory]) {
        self.priceDropThreshold = priceDropThreshold
        self.preferredRetailers = preferredRetailers
        self.budgetAlertThreshold = budgetAlertThreshold
        self.notificationsEnabled = notificationsEnabled
        self.autoReorderEnabled = autoReorderEnabled
        self.priceCheckFrequency = priceCheckFrequency
        self.dealCategories = dealCategories
    }
}

// MARK: - Tracking Item Model
struct TrackingItem: Identifiable, Codable {
    let id: UUID
    var product: Product
    var targetPrice: Double?
    let startDate: Date
    var lastChecked: Date?
    var isActive: Bool
    
    init(id: UUID = UUID(), product: Product, targetPrice: Double? = nil,
         startDate: Date = Date(), lastChecked: Date? = nil, isActive: Bool = true) {
        self.id = id
        self.product = product
        self.targetPrice = targetPrice
        self.startDate = startDate
        self.lastChecked = lastChecked
        self.isActive = isActive
    }
}

// MARK: - App State Models
enum AppTab: Int, CaseIterable {
    case shopping = 0
    case inventory = 1
    case deals = 2
    case analytics = 3
    case profile = 4
    
    var title: String {
        switch self {
        case .shopping: return "Shopping"
        case .inventory: return "Inventory"
        case .deals: return "Deals"
        case .analytics: return "Analytics"
        case .profile: return "Profile"
        }
    }
    
    var icon: String {
        switch self {
        case .shopping: return "list.bullet.clipboard"
        case .inventory: return "shippingbox"
        case .deals: return "tag.fill"
        case .analytics: return "chart.line.uptrend.xyaxis"
        case .profile: return "person.circle"
        }
    }
}

// MARK: - Error Models
enum ShopSenseError: LocalizedError {
    case networkError(String)
    case apiError(String)
    case dataCorruption
    case unauthorized
    case subscriptionRequired
    
    var errorDescription: String? {
        switch self {
        case .networkError(let message):
            return "Network Error: \(message)"
        case .apiError(let message):
            return "API Error: \(message)"
        case .dataCorruption:
            return "Data corruption detected. Please restart the app."
        case .unauthorized:
            return "Authentication required. Please sign in."
        case .subscriptionRequired:
            return "This feature requires a premium subscription."
        }
    }
}

// MARK: - Extension for Product Category Icons
extension Product.ProductCategory {
    var icon: String {
        switch self {
        case .electronics: return "tv"
        case .groceries: return "cart"
        case .clothing: return "tshirt"
        case .home: return "house"
        case .beauty: return "sparkles"
        case .sports: return "sportscourt"
        case .toys: return "teddybear"
        case .food: return "fork.knife"
        case .health: return "heart"
        case .books: return "book"
        case .other: return "square.grid.2x2"
        }
    }
    
    var color: String {
        switch self {
        case .electronics: return "blue"
        case .groceries: return "green"
        case .clothing: return "purple"
        case .home: return "orange"
        case .beauty: return "pink"
        case .sports: return "red"
        case .toys: return "yellow"
        case .food: return "brown"
        case .health: return "mint"
        case .books: return "indigo"
        case .other: return "gray"
        }
    }
}
