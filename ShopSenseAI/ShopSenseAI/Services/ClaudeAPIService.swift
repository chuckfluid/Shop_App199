import Foundation

// MARK: - Claude API Service
class ClaudeAPIService: ObservableObject {
    static let shared = ClaudeAPIService()
    
    private let apiKey: String
    private let baseURL = "https://api.anthropic.com/v1/messages"
    private let model = "claude-3-opus-20240229" // Update to latest model as needed
    
    private init() {
        // IMPORTANT: In production, store this securely in Keychain, not in code
        // For development, you can temporarily hardcode it or load from a config file
        self.apiKey = "YOUR_CLAUDE_API_KEY_HERE" // Replace with your actual API key
    }
    
    // MARK: - Shopping Intelligence Analysis
    func analyzeShoppingPattern(purchases: [Purchase], inventory: [InventoryItem]) async throws -> ShoppingAnalysis {
        let prompt = createShoppingAnalysisPrompt(purchases: purchases, inventory: inventory)
        let response = try await sendRequest(prompt: prompt)
        return try parseShoppingAnalysis(from: response)
    }
    
    // MARK: - Price Prediction
    func predictOptimalBuyingTime(for product: Product, priceHistory: [PricePoint]) async throws -> PricePrediction {
        let prompt = createPricePredictionPrompt(product: product, history: priceHistory)
        let response = try await sendRequest(prompt: prompt)
        return try parsePricePrediction(from: response)
    }
    
    // MARK: - Deal Evaluation
    func evaluateDeal(_ deal: DealAlert, userPreferences: UserPreferences) async throws -> DealEvaluation {
        let prompt = createDealEvaluationPrompt(deal: deal, preferences: userPreferences)
        let response = try await sendRequest(prompt: prompt)
        return try parseDealEvaluation(from: response)
    }
    
    // MARK: - Budget Optimization
    func optimizeBudget(currentBudget: Budget, purchases: [Purchase], goals: [String]) async throws -> BudgetRecommendation {
        let prompt = createBudgetOptimizationPrompt(budget: currentBudget, purchases: purchases, goals: goals)
        let response = try await sendRequest(prompt: prompt)
        return try parseBudgetRecommendation(from: response)
    }
    
    // MARK: - Private Methods
    private func sendRequest(prompt: String) async throws -> ClaudeResponse {
        guard !apiKey.isEmpty else {
            throw ClaudeAPIError.missingAPIKey
        }
        
        var request = URLRequest(url: URL(string: baseURL)!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        
        let requestBody = ClaudeRequest(
            model: model,
            messages: [Message(role: "user", content: prompt)],
            max_tokens: 1024
        )
        
        request.httpBody = try JSONEncoder().encode(requestBody)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw ClaudeAPIError.invalidResponse
        }
        
        if httpResponse.statusCode != 200 {
            throw ClaudeAPIError.httpError(statusCode: httpResponse.statusCode)
        }
        
        return try JSONDecoder().decode(ClaudeResponse.self, from: data)
    }
    
    // MARK: - Prompt Creation Methods
    private func createShoppingAnalysisPrompt(purchases: [Purchase], inventory: [InventoryItem]) -> String {
        """
        Analyze the following shopping data and provide insights:
        
        Recent Purchases:
        \(purchases.map { "- \($0.product.name): $\($0.price) from \($0.retailer.name) on \($0.purchaseDate)" }.joined(separator: "\n"))
        
        Current Inventory:
        \(inventory.map { "- \($0.product.name): \($0.currentQuantity) units, reorder at \($0.reorderThreshold)" }.joined(separator: "\n"))
        
        Please provide:
        1. Shopping patterns and frequency analysis
        2. Items likely to need restocking soon
        3. Potential savings opportunities
        4. Recommended bulk purchase opportunities
        
        Format the response as JSON with keys: patterns, restockingSoon, savingsOpportunities, bulkRecommendations
        """
    }
    
    private func createPricePredictionPrompt(product: Product, history: [PricePoint]) -> String {
        """
        Analyze price history for \(product.name) and predict optimal buying time:
        
        Price History:
        \(history.map { "- \($0.retailer.name): $\($0.price) on \($0.timestamp)" }.joined(separator: "\n"))
        
        Product Category: \(product.category.rawValue)
        
        Please provide:
        1. Price trend analysis
        2. Predicted best time to buy (within next 30 days)
        3. Expected price range
        4. Confidence score (0-1)
        
        Format response as JSON with keys: trend, optimalBuyDate, expectedPriceRange, confidence
        """
    }
    
    private func createDealEvaluationPrompt(deal: DealAlert, preferences: UserPreferences) -> String {
        """
        Evaluate this deal based on user preferences:
        
        Deal Details:
        - Product: \(deal.product.name)
        - Current Price: $\(deal.currentPrice) (was $\(deal.previousPrice))
        - Discount: \(deal.discountPercentage)%
        - Retailer: \(deal.retailer.name)
        - Deal Type: \(deal.dealType.rawValue)
        
        User Preferences:
        - Price Drop Threshold: \(preferences.priceDropThreshold)%
        - Preferred Retailers: \(Array(preferences.preferredRetailers).joined(separator: ", "))
        
        Evaluate if this is a good deal and provide reasoning.
        Format as JSON with keys: recommendation (buy/wait/skip), score (0-10), reasoning
        """
    }
    
    private func createBudgetOptimizationPrompt(budget: Budget, purchases: [Purchase], goals: [String]) -> String {
        """
        Optimize shopping budget based on:
        
        Current Budget:
        - Monthly Limit: $\(budget.monthlyLimit)
        - Spent This Month: $\(budget.currentMonthSpending)
        - Categories: \(budget.categories.map { "\($0.key.rawValue): $\($0.value)" }.joined(separator: ", "))
        
        Recent Purchases:
        \(purchases.prefix(10).map { "- \($0.product.name): $\($0.totalAmount)" }.joined(separator: "\n"))
        
        User Goals:
        \(goals.map { "- \($0)" }.joined(separator: "\n"))
        
        Provide budget optimization recommendations.
        Format as JSON with keys: recommendations, potentialSavings, categoryAdjustments
        """
    }
}

// MARK: - Response Models
struct ClaudeRequest: Codable {
    let model: String
    let messages: [Message]
    let max_tokens: Int
}

struct Message: Codable {
    let role: String
    let content: String
}

struct ClaudeResponse: Codable {
    let content: [Content]
    
    struct Content: Codable {
        let text: String
    }
}

// MARK: - Analysis Models
struct ShoppingAnalysis: Codable {
    let patterns: [String]
    let restockingSoon: [String]
    let savingsOpportunities: [SavingOpportunity]
    let bulkRecommendations: [String]
    
    struct SavingOpportunity: Codable {
        let item: String
        let potentialSaving: Double
        let recommendation: String
    }
}

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

struct DealEvaluation: Codable {
    let recommendation: Recommendation
    let score: Int
    let reasoning: String
    
    enum Recommendation: String, Codable {
        case buy = "buy"
        case wait = "wait"
        case skip = "skip"
    }
}

struct BudgetRecommendation: Codable {
    let recommendations: [String]
    let potentialSavings: Double
    let categoryAdjustments: [String: Double]
}

// MARK: - Errors
enum ClaudeAPIError: LocalizedError {
    case missingAPIKey
    case invalidResponse
    case httpError(statusCode: Int)
    case parsingError
    
    var errorDescription: String? {
        switch self {
        case .missingAPIKey:
            return "Claude API key is missing. Please configure your API key."
        case .invalidResponse:
            return "Invalid response from Claude API"
        case .httpError(let statusCode):
            return "HTTP error with status code: \(statusCode)"
        case .parsingError:
            return "Failed to parse Claude API response"
        }
    }
}

// MARK: - Parsing Methods Extension
extension ClaudeAPIService {
    private func parseShoppingAnalysis(from response: ClaudeResponse) throws -> ShoppingAnalysis {
        guard let text = response.content.first?.text,
              let data = text.data(using: .utf8) else {
            throw ClaudeAPIError.parsingError
        }
        
        return try JSONDecoder().decode(ShoppingAnalysis.self, from: data)
    }
    
    private func parsePricePrediction(from response: ClaudeResponse) throws -> PricePrediction {
        guard let text = response.content.first?.text,
              let data = text.data(using: .utf8) else {
            throw ClaudeAPIError.parsingError
        }
        
        return try JSONDecoder().decode(PricePrediction.self, from: data)
    }
    
    private func parseDealEvaluation(from response: ClaudeResponse) throws -> DealEvaluation {
        guard let text = response.content.first?.text,
              let data = text.data(using: .utf8) else {
            throw ClaudeAPIError.parsingError
        }
        
        return try JSONDecoder().decode(DealEvaluation.self, from: data)
    }
    
    private func parseBudgetRecommendation(from response: ClaudeResponse) throws -> BudgetRecommendation {
        guard let text = response.content.first?.text,
              let data = text.data(using: .utf8) else {
            throw ClaudeAPIError.parsingError
        }
        
        return try JSONDecoder().decode(BudgetRecommendation.self, from: data)
    }
}
