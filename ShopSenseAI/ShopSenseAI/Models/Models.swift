import Foundation

// MARK: - Product Model
struct Product: Identifiable, Codable {
    var id = UUID()
    let name: String
    let description: String
    let category: ProductCategory
    let imageURL: String?
    let barcode: String?
    let brand: String?
    
    var priceHistory: [PricePoint] = []
    var currentLowestPrice: PricePoint?
    var averagePrice: Double?
    
    enum ProductCategory: String, CaseIterable, Codable {
        case electronics = "Electronics"
        case groceries = "Groceries"
        case clothing = "Clothing"
        case home = "Home & Garden"
        case beauty = "Beauty & Personal Care"
        case sports = "Sports & Outdoors"
        case toys = "Toys & Games"
        case other = "Other"
    }
}

// MARK: - Price Point
struct PricePoint: Codable {
    let retailer: Retailer
    let price: Double
    let timestamp: Date
    let url: String
    let inStock: Bool
    let shippingCost: Double?
    
    var totalPrice: Double {
        return price + (shippingCost ?? 0)
    }
}

// MARK: - Retailer
struct Retailer: Identifiable, Codable {
    let id: String
    let name: String
    let logoURL: String?
    let websiteURL: String
    
    static let allRetailers = [
        Retailer(id: "amazon", name: "Amazon", logoURL: nil, websiteURL: "https://amazon.com"),
        Retailer(id: "target", name: "Target", logoURL: nil, websiteURL: "https://target.com"),
        Retailer(id: "walmart", name: "Walmart", logoURL: nil, websiteURL: "https://walmart.com"),
        Retailer(id: "bestbuy", name: "Best Buy", logoURL: nil, websiteURL: "https://bestbuy.com"),
        Retailer(id: "costco", name: "Costco", logoURL: nil, websiteURL: "https://costco.com")
    ]
}

// MARK: - Shopping List Item
struct ShoppingListItem: Identifiable, Codable {
    var id = UUID()
    var product: Product
    var targetPrice: Double?
    var quantity: Int
    var priority: Priority
    var notes: String?
    var addedDate: Date
    var isTracking: Bool
    
    enum Priority: String, CaseIterable, Codable {
        case low = "Low"
        case medium = "Medium"
        case high = "High"
        case urgent = "Urgent"
    }
}

// MARK: - Deal Alert
struct DealAlert: Identifiable, Codable {
    var id = UUID()
    let product: Product
    let retailer: Retailer
    let currentPrice: Double
    let previousPrice: Double
    let discount: Double
    let discountPercentage: Double
    let alertDate: Date
    let expiryDate: Date?
    let dealType: DealType
    
    var savings: Double {
        return previousPrice - currentPrice
    }
    
    enum DealType: String, Codable {
        case priceDropAlert = "Price Drop"
        case flashSale = "Flash Sale"
        case couponAvailable = "Coupon Available"
        case bundleDeal = "Bundle Deal"
        case seasonalSale = "Seasonal Sale"
    }
}

// MARK: - Household Inventory Item
struct InventoryItem: Identifiable, Codable {
    var id = UUID()
    var product: Product
    var currentQuantity: Int
    var preferredQuantity: Int
    var lastPurchaseDate: Date?
    var averageConsumptionDays: Int?
    var autoReorder: Bool
    var reorderThreshold: Int
    
    var needsReorder: Bool {
        return currentQuantity <= reorderThreshold
    }
    
    var estimatedRunOutDate: Date? {
        guard let avgDays = averageConsumptionDays,
              let lastPurchase = lastPurchaseDate else { return nil }
        return Calendar.current.date(byAdding: .day, value: avgDays, to: lastPurchase)
    }
}

// MARK: - Purchase History
struct Purchase: Identifiable, Codable {
    var id = UUID()
    let product: Product
    let retailer: Retailer
    let purchaseDate: Date
    let price: Double
    let quantity: Int
    let totalAmount: Double
    
    var pricePerUnit: Double {
        return price / Double(quantity)
    }
}

// MARK: - AI Recommendation
struct AIRecommendation: Identifiable, Codable {
    var id = UUID()
    let product: Product
    let reason: String
    let confidenceScore: Double
    let potentialSavings: Double?
    let alternativeProducts: [Product]
    let bestTimeToBy: DateRange?
    let createdAt: Date
    
    struct DateRange: Codable {
        let start: Date
        let end: Date
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
        return currentMonthSpending / monthlyLimit
    }
}
