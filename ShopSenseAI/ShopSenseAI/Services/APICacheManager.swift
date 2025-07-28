import Foundation

// MARK: - API Cache Manager
class APICacheManager: ObservableObject {
    static let shared = APICacheManager()
    
    private let cacheDirectory: URL
    private let cacheExpirationTime: TimeInterval = 86400 // 24 hours
    private let batchProcessingQueue = DispatchQueue(label: "com.shopsenseai.batchprocessing", qos: .background)
    
    // Cache keys
    private let shoppingAnalysisCacheKey = "shopping_analysis_cache"
    private let pricePredictionCacheKey = "price_prediction_cache"
    private let dealEvaluationCacheKey = "deal_evaluation_cache"
    private let budgetOptimizationCacheKey = "budget_optimization_cache"
    
    private init() {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        self.cacheDirectory = documentsPath.appendingPathComponent("APICache")
        
        // Create cache directory if it doesn't exist
        try? FileManager.default.createDirectory(at: cacheDirectory, withIntermediateDirectories: true, attributes: nil)
        
        // Schedule daily batch processing
        scheduleDailyBatchProcessing()
    }
    
    // MARK: - Cache Management
    func getCachedResponse<T: Codable>(for key: String, type: T.Type) -> T? {
        let fileURL = cacheDirectory.appendingPathComponent("\(key).json")
        
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            return nil
        }
        
        do {
            let data = try Data(contentsOf: fileURL)
            let wrapper = try JSONDecoder().decode(CacheWrapper<T>.self, from: data)
            
            // Check if cache is still valid
            if Date().timeIntervalSince(wrapper.timestamp) < cacheExpirationTime {
                return wrapper.data
            } else {
                // Remove expired cache
                try? FileManager.default.removeItem(at: fileURL)
                return nil
            }
        } catch {
            print("Cache read error: \(error)")
            return nil
        }
    }
    
    func cacheResponse<T: Codable>(_ response: T, for key: String) {
        let fileURL = cacheDirectory.appendingPathComponent("\(key).json")
        let wrapper = CacheWrapper(data: response, timestamp: Date())
        
        do {
            let data = try JSONEncoder().encode(wrapper)
            try data.write(to: fileURL)
        } catch {
            print("Cache write error: \(error)")
        }
    }
    
    func clearCache() {
        try? FileManager.default.removeItem(at: cacheDirectory)
        try? FileManager.default.createDirectory(at: cacheDirectory, withIntermediateDirectories: true, attributes: nil)
    }
    
    // MARK: - Batch Processing
    private func scheduleDailyBatchProcessing() {
        // Schedule for 3 AM daily
        let calendar = Calendar.current
        var dateComponents = calendar.dateComponents([.hour, .minute], from: Date())
        dateComponents.hour = 3
        dateComponents.minute = 0
        
        if let scheduledTime = calendar.nextDate(after: Date(), matching: dateComponents, matchingPolicy: .nextTime) {
            let timeInterval = scheduledTime.timeIntervalSince(Date())
            
            DispatchQueue.main.asyncAfter(deadline: .now() + timeInterval) { [weak self] in
                self?.performBatchProcessing()
                // Reschedule for next day
                self?.scheduleDailyBatchProcessing()
            }
        }
    }
    
    func performBatchProcessing() {
        guard AuthenticationManager.shared.subscriptionTier == .premium else {
            print("Batch processing skipped - Premium feature only")
            return
        }
        
        batchProcessingQueue.async {
            self.batchUpdatePricePredictions()
            self.batchUpdateShoppingAnalysis()
            self.batchUpdateDealEvaluations()
        }
    }
    
    private func batchUpdatePricePredictions() {
        // Collect all products that need price predictions
        let products = collectProductsNeedingPredictions()
        
        guard !products.isEmpty else { return }
        
        // Process in batches of 10 to optimize API usage
        let batchSize = 10
        for i in stride(from: 0, to: products.count, by: batchSize) {
            let batch = Array(products[i..<min(i + batchSize, products.count)])
            
            Task {
                do {
                    let predictions = try await ClaudeAPIService.shared.batchPredictPrices(for: batch)
                    
                    // Cache each prediction
                    for (product, prediction) in predictions {
                        let key = "\(pricePredictionCacheKey)_\(product.id.uuidString)"
                        cacheResponse(prediction, for: key)
                    }
                } catch {
                    print("Batch price prediction error: \(error)")
                }
            }
        }
    }
    
    private func batchUpdateShoppingAnalysis() {
        // Get all users' shopping data (in production, this would be from backend)
        // For now, we'll use the current user's data
        
        Task {
            do {
                // Mock data - in production, fetch from backend
                let purchases: [Purchase] = []
                let inventory: [InventoryItem] = []
                
                let analysis = try await ClaudeAPIService.shared.analyzeShoppingPattern(
                    purchases: purchases,
                    inventory: inventory
                )
                
                cacheResponse(analysis, for: shoppingAnalysisCacheKey)
            } catch {
                print("Batch shopping analysis error: \(error)")
            }
        }
    }
    
    private func batchUpdateDealEvaluations() {
        // Collect all active deals
        let deals = collectActiveDeals()
        
        guard !deals.isEmpty else { return }
        
        Task {
            do {
                let userPreferences = UserPreferences()
                
                for deal in deals {
                    let evaluation = try await ClaudeAPIService.shared.evaluateDeal(
                        deal,
                        userPreferences: userPreferences
                    )
                    
                    let key = "\(dealEvaluationCacheKey)_\(deal.id.uuidString)"
                    cacheResponse(evaluation, for: key)
                }
            } catch {
                print("Batch deal evaluation error: \(error)")
            }
        }
    }
    
    // MARK: - Helper Methods
    private func collectProductsNeedingPredictions() -> [Product] {
        // In production, this would query the database
        // For now, return empty array
        return []
    }
    
    private func collectActiveDeals() -> [DealAlert] {
        // In production, this would query the database
        // For now, return empty array
        return []
    }
}

// MARK: - Cache Wrapper
struct CacheWrapper<T: Codable>: Codable {
    let data: T
    let timestamp: Date
}

// MARK: - Batch API Extensions
extension ClaudeAPIService {
    func batchPredictPrices(for products: [Product]) async throws -> [(Product, PricePrediction)] {
        // Create a batch prompt for multiple products
        let batchPrompt = createBatchPricePredictionPrompt(products: products)
        let response = try await sendRequest(prompt: batchPrompt)
        return try parseBatchPricePredictions(from: response, products: products)
    }
    
    private func createBatchPricePredictionPrompt(products: [Product]) -> String {
        let productList = products.enumerated().map { index, product in
            "Product \(index + 1): \(product.name) (Category: \(product.category.rawValue))"
        }.joined(separator: "\n")
        
        return """
        Analyze price predictions for the following products in batch:
        
        \(productList)
        
        For each product, provide:
        1. Price trend (Increasing/Decreasing/Stable/Volatile)
        2. Optimal buying date (within next 30 days, YYYY-MM-DD format)
        3. Expected price range (min and max)
        4. Confidence score (0.0 to 1.0)
        
        Format as JSON array with objects containing: productIndex, trend, optimalBuyDate, expectedPriceRange (min/max), confidence
        """
    }
    
    private func parseBatchPricePredictions(from response: ClaudeResponse, products: [Product]) throws -> [(Product, PricePrediction)] {
        // Parse batch response and match with products
        // This is a simplified version - implement full parsing logic
        var results: [(Product, PricePrediction)] = []
        
        // Mock implementation
        for product in products {
            let prediction = PricePrediction(
                trend: "Stable",
                optimalBuyDate: Date().addingTimeInterval(7 * 86400),
                expectedPriceRange: PricePrediction.PriceRange(min: 50, max: 100),
                confidence: 0.8
            )
            results.append((product, prediction))
        }
        
        return results
    }
}
