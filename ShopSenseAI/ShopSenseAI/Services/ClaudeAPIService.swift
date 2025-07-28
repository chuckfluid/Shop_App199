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
    private let model = "claude-4-sonnet-20250514"
    private let cacheManager = APICacheManager.shared
    
    // Rate limiting
    private var lastAPICallTime: Date?
    private let minimumTimeBetweenCalls: TimeInterval = 2.0 // 2 seconds
    private let apiCallQueue = DispatchQueue(label: "com.shopsenseai.api", qos: .userInitiated)
    private var pendingRequests = 0
    private let maxConcurrentRequests = 3
    
    private init() {
        // IMPORTANT: In production, store this securely in Keychain, not in code
        // For development, you can temporarily hardcode it or load from a config file
        self.apiKey = "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" // Replace with your actual API key
    }
    
    // MARK: - Shopping Intelligence Analysis with Caching
    func analyzeShoppingPattern(purchases: [Purchase], inventory: [InventoryItem], forceRefresh: Bool = false) async throws -> ShoppingAnalysis {
        let cacheKey = "shopping_analysis_\(AuthenticationManager.shared.userProfile?.id ?? "default")"
        
        // Check cache first unless force refresh
        if !forceRefresh,
           let cached: ShoppingAnalysis = cacheManager.getCachedResponse(for: cacheKey, type: ShoppingAnalysis.self) {
            return cached
        }
        
        // Check if user is premium for real-time analysis
        guard AuthenticationManager.shared.subscriptionTier == .premium || forceRefresh else {
            // Free users get limited analysis
            return createBasicShoppingAnalysis(purchases: purchases, inventory: inventory)
        }
        
        // Rate limiting
        try await enforceRateLimit()
        
        let prompt = createShoppingAnalysisPrompt(purchases: purchases, inventory: inventory)
        let response = try await sendRequest(prompt: prompt)
        let analysis = try parseShoppingAnalysis(from: response)
        
        // Cache the response
        cacheManager.cacheResponse(analysis, for: cacheKey)
        
        return analysis
    }
    
    // MARK: - Price Prediction with Caching
    func predictOptimalBuyingTime(for product: Product, priceHistory: [PricePoint], forceRefresh: Bool = false) async throws -> PricePrediction {
        let cacheKey = "price_prediction_\(product.id.uuidString)"
        
        // Check cache first
        if !forceRefresh,
           let cached: PricePrediction = cacheManager.getCachedResponse(for: cacheKey, type: PricePrediction.self) {
            return cached
        }
        
        // Premium feature check
        guard AuthenticationManager.shared.subscriptionTier == .premium else {
            // Free users get basic prediction
            return createBasicPricePrediction(for: product)
        }
        
        try await enforceRateLimit()
        
        let prompt = createPricePredictionPrompt(product: product, history: priceHistory)
        let response = try await sendRequest(prompt: prompt)
        let prediction = try parsePricePrediction(from: response)
        
        // Cache the response
        cacheManager.cacheResponse(prediction, for: cacheKey)
        
        return prediction
    }
    
    // MARK: - Deal Evaluation with Caching
    func evaluateDeal(_ deal: DealAlert, userPreferences: UserPreferences, forceRefresh: Bool = false) async throws -> DealEvaluation {
        let cacheKey = "deal_evaluation_\(deal.id.uuidString)"
        
        // Check cache first
        if !forceRefresh,
           let cached: DealEvaluation = cacheManager.getCachedResponse(for: cacheKey, type: DealEvaluation.self) {
            return cached
        }
        
        // Premium users get AI evaluation, free users get basic evaluation
        guard AuthenticationManager.shared.subscriptionTier == .premium else {
            return createBasicDealEvaluation(deal: deal, preferences: userPreferences)
        }
        
        try await enforceRateLimit()
        
        let prompt = createDealEvaluationPrompt(deal: deal, preferences: userPreferences)
        let response = try await sendRequest(prompt: prompt)
        let evaluation = try parseDealEvaluation(from: response)
        
        // Cache the response
        cacheManager.cacheResponse(evaluation, for: cacheKey)
        
        return evaluation
    }
    
    // MARK: - Budget Optimization (Premium Only)
    func optimizeBudget(currentBudget: Budget, purchases: [Purchase], goals: [String]) async throws -> BudgetRecommendation {
        guard AuthenticationManager.shared.subscriptionTier == .premium else {
            throw ClaudeAPIError.subscriptionRequired
        }
        
        let cacheKey = "budget_optimization_\(AuthenticationManager.shared.userProfile?.id ?? "default")"
        
        // Check cache (valid for 7 days for budget optimization)
        if let cached: BudgetRecommendation = cacheManager.getCachedResponse(for: cacheKey, type: BudgetRecommendation.self) {
            return cached
        }
        
        try await enforceRateLimit()
        
        let prompt = createBudgetOptimizationPrompt(budget: currentBudget, purchases: purchases, goals: goals)
        let response = try await sendRequest(prompt: prompt)
        let recommendation = try parseBudgetRecommendation(from: response)
        
        cacheManager.cacheResponse(recommendation, for: cacheKey)
        
        return recommendation
    }
    
    // MARK: - Product Alternative Suggestions
    func suggestAlternatives(for product: Product, priceHistory: [PricePoint]) async throws -> ProductAlternatives {
        // Basic alternatives for free users, AI-powered for premium
        if AuthenticationManager.shared.subscriptionTier != .premium {
            return createBasicProductAlternatives(for: product)
        }
        
        try await enforceRateLimit()
        
        let prompt = createProductAlternativesPrompt(product: product, history: priceHistory)
        let response = try await sendRequest(prompt: prompt)
        return try parseProductAlternatives(from: response)
    }
    
    // MARK: - Smart Shopping Recommendations
    func getSmartRecommendations(items: [ShoppingListItem], budget: Budget) async throws -> SmartRecommendations {
        guard AuthenticationManager.shared.subscriptionTier == .premium else {
            return createBasicSmartRecommendations(items: items)
        }
        
        try await enforceRateLimit()
        
        let prompt = createSmartRecommendationsPrompt(items: items, budget: budget)
        let response = try await sendRequest(prompt: prompt)
        return try parseSmartRecommendations(from: response)
    }
    
    // MARK: - Rate Limiting
    private func enforceRateLimit() async throws {
        return try await withCheckedThrowingContinuation { continuation in
            apiCallQueue.async { [weak self] in
                guard let self = self else {
                    continuation.resume(throwing: ClaudeAPIError.networkError(NSError(domain: "ClaudeAPI", code: -1)))
                    return
                }
                
                // Check concurrent requests
                if self.pendingRequests >= self.maxConcurrentRequests {
                    continuation.resume(throwing: ClaudeAPIError.rateLimitExceeded)
                    return
                }
                
                // Check time since last call
                if let lastCall = self.lastAPICallTime {
                    let timeSinceLastCall = Date().timeIntervalSince(lastCall)
                    if timeSinceLastCall < self.minimumTimeBetweenCalls {
                        let waitTime = self.minimumTimeBetweenCalls - timeSinceLastCall
                        Thread.sleep(forTimeInterval: waitTime)
                    }
                }
                
                self.lastAPICallTime = Date()
                self.pendingRequests += 1
                continuation.resume()
            }
        }
    }
    
    // MARK: - Private Methods
    private func sendRequest(prompt: String) async throws -> ClaudeResponse {
        defer {
            apiCallQueue.async { [weak self] in
                self?.pendingRequests -= 1
            }
        }
        
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
            
            if httpResponse.statusCode == 429 {
                throw ClaudeAPIError.rateLimitExceeded
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
    
    // MARK: - Basic Implementations for Free Users
    private func createBasicShoppingAnalysis(purchases: [Purchase], inventory: [InventoryItem]) -> ShoppingAnalysis {
        var patterns: [String] = []
        var restockingSoon: [String] = []
        var savingsOpportunities: [ShoppingAnalysis.SavingOpportunity] = []
        
        // Basic pattern analysis
        if !purchases.isEmpty {
            patterns.append("You've made \(purchases.count) purchases recently")
            
            let avgSpending = purchases.reduce(0) { $0 + $1.totalAmount } / Double(purchases.count)
            patterns.append("Average purchase amount: $\(String(format: "%.2f", avgSpending))")
        }
        
        // Check inventory for restock needs
        for item in inventory where item.needsReorder {
            restockingSoon.append(item.product.name)
        }
        
        // Basic savings opportunities
        if restockingSoon.count > 3 {
            savingsOpportunities.append(
                ShoppingAnalysis.SavingOpportunity(
                    item: "Bundle Purchase",
                    potentialSaving: Double(restockingSoon.count) * 2.5,
                    recommendation: "Consider buying these items together for potential bulk discounts"
                )
            )
        }
        
        return ShoppingAnalysis(
            patterns: patterns,
            restockingSoon: restockingSoon,
            savingsOpportunities: savingsOpportunities,
            bulkRecommendations: restockingSoon.count > 5 ? ["Consider bulk purchasing for frequently used items"] : []
        )
    }
    
    private func createBasicPricePrediction(for product: Product) -> PricePrediction {
        // Basic prediction based on category
        let trend: String
        let daysToWait: Int
        
        switch product.category {
        case .electronics:
            trend = "Stable"
            daysToWait = 14
        case .groceries, .food:
            trend = "Volatile"
            daysToWait = 7
        case .clothing:
            trend = "Seasonal"
            daysToWait = 30
        default:
            trend = "Stable"
            daysToWait = 10
        }
        
        let currentPrice = product.currentLowestPrice?.price ?? 100
        let variance = currentPrice * 0.1
        
        return PricePrediction(
            trend: trend,
            optimalBuyDate: Date().addingTimeInterval(TimeInterval(daysToWait * 86400)),
            expectedPriceRange: PricePrediction.PriceRange(
                min: currentPrice - variance,
                max: currentPrice + variance
            ),
            confidence: 0.6
        )
    }
    
    private func createBasicDealEvaluation(deal: DealAlert, preferences: UserPreferences) -> DealEvaluation {
        let recommendation: DealEvaluation.Recommendation
        let score: Int
        let reasoning: String
        
        if deal.discountPercentage >= preferences.priceDropThreshold * 2 {
            recommendation = .buy
            score = 8
            reasoning = "Excellent discount! This exceeds your typical threshold."
        } else if deal.discountPercentage >= preferences.priceDropThreshold {
            recommendation = .buy
            score = 6
            reasoning = "Good deal that meets your discount preferences."
        } else {
            recommendation = .wait
            score = 4
            reasoning = "Discount is below your preferred threshold. Consider waiting for a better deal."
        }
        
        return DealEvaluation(
            recommendation: recommendation,
            score: score,
            reasoning: reasoning
        )
    }
    
    private func createBasicProductAlternatives(for product: Product) -> ProductAlternatives {
        // Basic alternatives based on category
        let alternatives: [ProductAlternatives.Alternative] = [
            ProductAlternatives.Alternative(
                name: "Generic \(product.category.rawValue) Option",
                estimatedPrice: (product.currentLowestPrice?.price ?? 100) * 0.7,
                reason: "Typically 30% cheaper than branded options"
            ),
            ProductAlternatives.Alternative(
                name: "Store Brand Alternative",
                estimatedPrice: (product.currentLowestPrice?.price ?? 100) * 0.8,
                reason: "Good quality at a lower price point"
            )
        ]
        
        return ProductAlternatives(alternatives: alternatives)
    }
    
    private func createBasicSmartRecommendations(items: [ShoppingListItem]) -> SmartRecommendations {
        var recommendations: [String] = []
        var priorityOrder: [String] = []
        var timingAdvice: [String] = []
        
        // Sort by priority
        let sortedItems = items.sorted { $0.priority.rawValue < $1.priority.rawValue }
        priorityOrder = sortedItems.prefix(5).map { $0.product.name }
        
        // Basic recommendations
        let urgentItems = items.filter { $0.priority == .urgent }
        if !urgentItems.isEmpty {
            recommendations.append("Focus on \(urgentItems.count) urgent items first")
        }
        
        let trackingItems = items.filter { $0.isTracking }
        if trackingItems.count < items.count / 2 {
            recommendations.append("Enable price tracking on more items to maximize savings")
        }
        
        // Basic timing advice
        timingAdvice.append("Weekend mornings often have the best online deals")
        timingAdvice.append("Check for coupons before purchasing")
        
        return SmartRecommendations(
            recommendations: recommendations,
            priorityOrder: priorityOrder,
            timingAdvice: timingAdvice
        )
    }
    
    // MARK: - Prompt Creation Methods (unchanged)
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
    case rateLimitExceeded
    case subscriptionRequired
    
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
        case .rateLimitExceeded:
            return "API rate limit exceeded. Please try again later."
        case .subscriptionRequired:
            return "This feature requires a premium subscription."
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
