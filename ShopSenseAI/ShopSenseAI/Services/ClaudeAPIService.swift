import Foundation

// MARK: - User Preferences Model (Missing from Models.swift)
struct UserPreferences: Codable {
    var priceDropThreshold: Double = 10.0 // Percentage
    var preferredRetailers: Set<String> = ["amazon", "target", "walmart"]
    var budgetAlertThreshold: Double = 0.8 // 80% of budget
    var notificationsEnabled: Bool = true
    var autoReorderEnabled: Bool = false
    var priceCheckFrequency: TimeInterval = 3600 // 1 hour in seconds
    var dealCategories: [Product.ProductCategory] = Product.ProductCategory.allCases
    
    init() {}
}

// MARK: - Claude API Service
class ClaudeAPIService: ObservableObject {
    static let shared = ClaudeAPIService()
    
    private let apiKey: String
    private let baseURL = "https://api.anthropic.com/v1/messages"
    private let model = "claude-4-sonnet-20250514" // Updated to latest model
    
    private init() {
        // IMPORTANT: In production, store this securely in Keychain, not in code
        // For development, you can temporarily hardcode it or load from a config file
        self.apiKey = "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" // Replace with your actual API key
    }
    
    // MARK: - Shopping Intelligence Analysis
    func analyzeShoppingPattern(purchases: [Purchase], inventory: [InventoryItem]) async throws -> ShoppingAnalysis {
        let prompt = createShoppingAnalysisPrompt(purchases: purchases, inventory: inventory)
        let response = try await sendRequest(prompt: prompt)
        return try parseShoppingAnalysis(from: response)
    }
    
    // MARK: - Price Prediction (Using existing PricePrediction from Models.swift)
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
    
    // MARK: - Product Alternative Suggestions
    func suggestAlternatives(for product: Product, priceHistory: [PricePoint]) async throws -> ProductAlternatives {
        let prompt = createProductAlternativesPrompt(product: product, history: priceHistory)
        let response = try await sendRequest(prompt: prompt)
        return try parseProductAlternatives(from: response)
    }
    
    // MARK: - Smart Shopping Recommendations
    func getSmartRecommendations(items: [ShoppingListItem], budget: Budget) async throws -> SmartRecommendations {
        let prompt = createSmartRecommendationsPrompt(items: items, budget: budget)
        let response = try await sendRequest(prompt: prompt)
        return try parseSmartRecommendations(from: response)
    }
    
    // MARK: - Private Methods
    private func sendRequest(prompt: String) async throws -> ClaudeResponse {
        guard !apiKey.isEmpty && apiKey != "YOUR_CLAUDE_API_KEY_HERE" else {
            throw ClaudeAPIError.missingAPIKey
        }
        
        guard let url = URL(string: baseURL) else {
            throw ClaudeAPIError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.timeoutInterval = 30.0
        
        let requestBody = ClaudeRequest(
            model: model,
            messages: [Message(role: "user", content: prompt)],
            max_tokens: 2048,
            temperature: 0.7
        )
        
        do {
            request.httpBody = try JSONEncoder().encode(requestBody)
        } catch {
            throw ClaudeAPIError.encodingError(error)
        }
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw ClaudeAPIError.invalidResponse
            }
            
            if httpResponse.statusCode != 200 {
                let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
                throw ClaudeAPIError.httpError(statusCode: httpResponse.statusCode, message: errorMessage)
            }
            
            return try JSONDecoder().decode(ClaudeResponse.self, from: data)
        } catch let error as ClaudeAPIError {
            throw error
        } catch {
            throw ClaudeAPIError.networkError(error)
        }
    }
    
    // MARK: - Prompt Creation Methods
    private func createShoppingAnalysisPrompt(purchases: [Purchase], inventory: [InventoryItem]) -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .medium
        
        return """
        Analyze the following shopping data and provide insights:
        
        Recent Purchases:
        \(purchases.map { "- \($0.product.name): $\(String(format: "%.2f", $0.price)) from \($0.retailer.name) on \(dateFormatter.string(from: $0.purchaseDate))" }.joined(separator: "\n"))
        
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
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .short
        
        return """
        Analyze price history for \(product.name) and predict optimal buying time:
        
        Price History:
        \(history.map { "- \($0.retailer.name): $\(String(format: "%.2f", $0.price)) on \(dateFormatter.string(from: $0.timestamp))" }.joined(separator: "\n"))
        
        Product Category: \(product.category.rawValue)
        
        Please provide:
        1. Price trend analysis (use "Increasing", "Decreasing", "Stable", or "Volatile")
        2. Predicted best time to buy (provide date in YYYY-MM-DD format within next 30 days)
        3. Expected price range (min and max values)
        4. Confidence score (0.0 to 1.0)
        
        Format response as JSON with keys: trend, optimalBuyDate, expectedPriceRange (with min/max), confidence
        """
    }
    
    private func createDealEvaluationPrompt(deal: DealAlert, preferences: UserPreferences) -> String {
        return """
        Evaluate this deal based on user preferences:
        
        Deal Details:
        - Product: \(deal.product.name)
        - Current Price: $\(String(format: "%.2f", deal.currentPrice)) (was $\(String(format: "%.2f", deal.previousPrice)))
        - Discount: \(String(format: "%.1f", deal.discountPercentage))%
        - Retailer: \(deal.retailer.name)
        - Deal Type: \(deal.dealType.rawValue)
        
        User Preferences:
        - Price Drop Threshold: \(String(format: "%.1f", preferences.priceDropThreshold))%
        - Preferred Retailers: \(Array(preferences.preferredRetailers).joined(separator: ", "))
        
        Evaluate if this is a good deal and provide reasoning.
        Format as JSON with keys: recommendation (buy/wait/skip), score (0-10), reasoning
        """
    }
    
    private func createBudgetOptimizationPrompt(budget: Budget, purchases: [Purchase], goals: [String]) -> String {
        return """
        Optimize shopping budget based on:
        
        Current Budget:
        - Monthly Limit: $\(String(format: "%.2f", budget.monthlyLimit))
        - Spent This Month: $\(String(format: "%.2f", budget.currentMonthSpending))
        - Categories: \(budget.categories.map { "\($0.key.rawValue): $\(String(format: "%.2f", $0.value))" }.joined(separator: ", "))
        
        Recent Purchases:
        \(purchases.prefix(10).map { "- \($0.product.name): $\(String(format: "%.2f", $0.totalAmount))" }.joined(separator: "\n"))
        
        User Goals:
        \(goals.map { "- \($0)" }.joined(separator: "\n"))
        
        Provide budget optimization recommendations.
        Format as JSON with keys: recommendations, potentialSavings, categoryAdjustments
        """
    }
    
    private func createProductAlternativesPrompt(product: Product, history: [PricePoint]) -> String {
        return """
        Suggest alternative products for \(product.name) in the \(product.category.rawValue) category:
        
        Current Product Price Range: $\(String(format: "%.2f", history.min(by: { $0.price < $1.price })?.price ?? 0)) - $\(String(format: "%.2f", history.max(by: { $0.price < $1.price })?.price ?? 0))
        
        Please suggest 3-5 alternative products that offer better value.
        Format as JSON with keys: alternatives (array of objects with name, estimatedPrice, reason)
        """
    }
    
    private func createSmartRecommendationsPrompt(items: [ShoppingListItem], budget: Budget) -> String {
        return """
        Provide smart shopping recommendations for this shopping list:
        
        Shopping List:
        \(items.map { "- \($0.product.name) (Qty: \($0.quantity), Priority: \($0.priority.rawValue))" }.joined(separator: "\n"))
        
        Budget: $\(String(format: "%.2f", budget.remainingBudget)) remaining this month
        
        Provide recommendations for optimal shopping strategy.
        Format as JSON with keys: recommendations, priorityOrder, timingAdvice
        """
    }
}

// MARK: - Request/Response Models
struct ClaudeRequest: Codable {
    let model: String
    let messages: [Message]
    let max_tokens: Int
    let temperature: Double?
}

struct Message: Codable {
    let role: String
    let content: String
}

struct ClaudeResponse: Codable {
    let content: [Content]
    let usage: Usage?
    
    struct Content: Codable {
        let text: String
        let type: String?
    }
    
    struct Usage: Codable {
        let input_tokens: Int?
        let output_tokens: Int?
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

struct ProductAlternatives: Codable {
    let alternatives: [Alternative]
    
    struct Alternative: Codable {
        let name: String
        let estimatedPrice: Double
        let reason: String
    }
}

struct SmartRecommendations: Codable {
    let recommendations: [String]
    let priorityOrder: [String]
    let timingAdvice: [String]
}

// MARK: - Errors
enum ClaudeAPIError: LocalizedError {
    case missingAPIKey
    case invalidURL
    case invalidResponse
    case httpError(statusCode: Int, message: String)
    case parsingError(String)
    case encodingError(Error)
    case networkError(Error)
    
    var errorDescription: String? {
        switch self {
        case .missingAPIKey:
            return "Claude API key is missing. Please configure your API key."
        case .invalidURL:
            return "Invalid API URL"
        case .invalidResponse:
            return "Invalid response from Claude API"
        case .httpError(let statusCode, let message):
            return "HTTP error \(statusCode): \(message)"
        case .parsingError(let details):
            return "Failed to parse Claude API response: \(details)"
        case .encodingError(let error):
            return "Failed to encode request: \(error.localizedDescription)"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        }
    }
}

// MARK: - Parsing Methods Extension
extension ClaudeAPIService {
    private func parseShoppingAnalysis(from response: ClaudeResponse) throws -> ShoppingAnalysis {
        guard let text = response.content.first?.text else {
            throw ClaudeAPIError.parsingError("No content in response")
        }
        
        // Extract JSON from response if it's wrapped in markdown or other formatting
        let cleanedText = extractJSON(from: text)
        
        guard let data = cleanedText.data(using: .utf8) else {
            throw ClaudeAPIError.parsingError("Could not convert response to data")
        }
        
        do {
            return try JSONDecoder().decode(ShoppingAnalysis.self, from: data)
        } catch {
            throw ClaudeAPIError.parsingError(error.localizedDescription)
        }
    }
    
    private func parsePricePrediction(from response: ClaudeResponse) throws -> PricePrediction {
        guard let text = response.content.first?.text else {
            throw ClaudeAPIError.parsingError("No content in response")
        }
        
        let cleanedText = extractJSON(from: text)
        
        // Parse the response and convert to our PricePrediction model
        guard let data = cleanedText.data(using: .utf8) else {
            throw ClaudeAPIError.parsingError("Could not convert response to data")
        }
        
        do {
            let decoder = JSONDecoder()
            
            // Custom date parsing for the API response
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"
            decoder.dateDecodingStrategy = .formatted(formatter)
            
            return try decoder.decode(PricePrediction.self, from: data)
        } catch {
            throw ClaudeAPIError.parsingError(error.localizedDescription)
        }
    }
    
    private func parseDealEvaluation(from response: ClaudeResponse) throws -> DealEvaluation {
        guard let text = response.content.first?.text else {
            throw ClaudeAPIError.parsingError("No content in response")
        }
        
        let cleanedText = extractJSON(from: text)
        
        guard let data = cleanedText.data(using: .utf8) else {
            throw ClaudeAPIError.parsingError("Could not convert response to data")
        }
        
        do {
            return try JSONDecoder().decode(DealEvaluation.self, from: data)
        } catch {
            throw ClaudeAPIError.parsingError(error.localizedDescription)
        }
    }
    
    private func parseBudgetRecommendation(from response: ClaudeResponse) throws -> BudgetRecommendation {
        guard let text = response.content.first?.text else {
            throw ClaudeAPIError.parsingError("No content in response")
        }
        
        let cleanedText = extractJSON(from: text)
        
        guard let data = cleanedText.data(using: .utf8) else {
            throw ClaudeAPIError.parsingError("Could not convert response to data")
        }
        
        do {
            return try JSONDecoder().decode(BudgetRecommendation.self, from: data)
        } catch {
            throw ClaudeAPIError.parsingError(error.localizedDescription)
        }
    }
    
    private func parseProductAlternatives(from response: ClaudeResponse) throws -> ProductAlternatives {
        guard let text = response.content.first?.text else {
            throw ClaudeAPIError.parsingError("No content in response")
        }
        
        let cleanedText = extractJSON(from: text)
        
        guard let data = cleanedText.data(using: .utf8) else {
            throw ClaudeAPIError.parsingError("Could not convert response to data")
        }
        
        do {
            return try JSONDecoder().decode(ProductAlternatives.self, from: data)
        } catch {
            throw ClaudeAPIError.parsingError(error.localizedDescription)
        }
    }
    
    private func parseSmartRecommendations(from response: ClaudeResponse) throws -> SmartRecommendations {
        guard let text = response.content.first?.text else {
            throw ClaudeAPIError.parsingError("No content in response")
        }
        
        let cleanedText = extractJSON(from: text)
        
        guard let data = cleanedText.data(using: .utf8) else {
            throw ClaudeAPIError.parsingError("Could not convert response to data")
        }
        
        do {
            return try JSONDecoder().decode(SmartRecommendations.self, from: data)
        } catch {
            throw ClaudeAPIError.parsingError(error.localizedDescription)
        }
    }
    
    // Helper method to extract JSON from Claude's response which might be wrapped in markdown
    private func extractJSON(from text: String) -> String {
        // Look for JSON wrapped in code blocks
        if let range = text.range(of: "```json\\s*\\n([\\s\\S]*?)\\n```", options: .regularExpression) {
            let jsonText = String(text[range])
            let cleanedJson = jsonText.replacingOccurrences(of: "```json", with: "")
                .replacingOccurrences(of: "```", with: "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            return cleanedJson
        }
        
        // Look for JSON wrapped in code blocks without language specifier
        if let range = text.range(of: "```\\s*\\n([\\s\\S]*?)\\n```", options: .regularExpression) {
            let jsonText = String(text[range])
            let cleanedJson = jsonText.replacingOccurrences(of: "```", with: "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            return cleanedJson
        }
        
        // Try to find JSON-like content between { and }
        if let startRange = text.range(of: "{"),
           let endRange = text.range(of: "}", options: .backwards) {
            return String(text[startRange.lowerBound...endRange.upperBound])
        }
        
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
