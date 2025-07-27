import SwiftUI

struct MainTabView: View {
    @State private var selectedTab = 0
    @EnvironmentObject var authManager: AuthenticationManager
    @EnvironmentObject var userPreferences: UserPreferences
    
    var body: some View {
        TabView(selection: $selectedTab) {
            // Home Dashboard
            HomeDashboardView()
                .tabItem {
                    Label("Home", systemImage: "house.fill")
                }
                .tag(0)
            
            // Shopping List
            ShoppingListView()
                .tabItem {
                    Label("Shopping", systemImage: "cart.fill")
                }
                .tag(1)
            
            // Deals
            DealsView()
                .tabItem {
                    Label("Deals", systemImage: "tag.fill")
                }
                .tag(2)
                .badge(5) // Show number of new deals
            
            // Inventory
            InventoryView()
                .tabItem {
                    Label("Inventory", systemImage: "shippingbox.fill")
                }
                .tag(3)
            
            // Profile
            ProfileView()
                .tabItem {
                    Label("Profile", systemImage: "person.fill")
                }
                .tag(4)
        }
        .accentColor(.blue)
    }
}

// MARK: - Home Dashboard View
struct HomeDashboardView: View {
    @StateObject private var viewModel = HomeDashboardViewModel()
    @EnvironmentObject var authManager: AuthenticationManager
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Daily Digest Card
                    DailyDigestCard(digest: viewModel.dailyDigest)
                        .padding(.horizontal)
                    
                    // Savings Summary
                    SavingsSummaryCard(
                        monthlySavings: viewModel.monthlySavings,
                        totalSavings: viewModel.totalSavings
                    )
                    .padding(.horizontal)
                    
                    // AI Recommendations
                    if !viewModel.recommendations.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("AI Recommendations")
                                .font(.headline)
                                .padding(.horizontal)
                            
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 12) {
                                    ForEach(viewModel.recommendations) { recommendation in
                                        RecommendationCard(recommendation: recommendation)
                                    }
                                }
                                .padding(.horizontal)
                            }
                        }
                    }
                    
                    // Recent Price Drops
                    if !viewModel.recentPriceDrops.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Text("Recent Price Drops")
                                    .font(.headline)
                                Spacer()
                                NavigationLink("See All", destination: DealsView())
                                    .font(.caption)
                            }
                            .padding(.horizontal)
                            
                            VStack(spacing: 10) {
                                ForEach(viewModel.recentPriceDrops.prefix(3)) { alert in
                                    PriceDropRow(alert: alert)
                                }
                            }
                            .padding(.horizontal)
                        }
                    }
                }
                .padding(.vertical)
            }
            .navigationTitle("ShopSense AI")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { viewModel.showNotifications = true }) {
                        Image(systemName: "bell.fill")
                            .foregroundColor(.blue)
                    }
                }
            }
        }
        .onAppear {
            viewModel.loadDashboard()
        }
    }
}

// MARK: - Component Views
struct DailyDigestCard: View {
    let digest: DailyDigest?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "sparkles")
                    .foregroundColor(.yellow)
                Text("Daily Digest")
                    .font(.headline)
                Spacer()
                Text(Date(), style: .date)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            if let digest = digest {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "tag.fill")
                            .foregroundColor(.green)
                        Text("\(digest.dealCount) deals worth $\(digest.totalSavings, specifier: "%.2f")")
                            .font(.subheadline)
                    }
                    
                    if digest.urgentDeals > 0 {
                        HStack {
                            Image(systemName: "exclamationmark.circle.fill")
                                .foregroundColor(.orange)
                            Text("\(digest.urgentDeals) expiring today!")
                                .font(.subheadline)
                                .foregroundColor(.orange)
                        }
                    }
                    
                    if digest.restockReminders > 0 {
                        HStack {
                            Image(systemName: "arrow.triangle.2.circlepath")
                                .foregroundColor(.blue)
                            Text("\(digest.restockReminders) items to restock")
                                .font(.subheadline)
                        }
                    }
                }
            } else {
                ProgressView()
                    .frame(maxWidth: .infinity)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

struct SavingsSummaryCard: View {
    let monthlySavings: Double
    let totalSavings: Double
    
    var body: some View {
        HStack(spacing: 20) {
            VStack(alignment: .leading) {
                Text("This Month")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text("$\(monthlySavings, specifier: "%.2f")")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.green)
            }
            
            Divider()
                .frame(height: 40)
            
            VStack(alignment: .leading) {
                Text("All Time")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text("$\(totalSavings, specifier: "%.2f")")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.blue)
            }
            
            Spacer()
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

struct RecommendationCard: View {
    let recommendation: AIRecommendation
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let imageURL = recommendation.product.imageURL {
                // Placeholder for image
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 150, height: 100)
                    .overlay(
                        Image(systemName: "photo")
                            .foregroundColor(.gray)
                    )
            }
            
            Text(recommendation.product.name)
                .font(.subheadline)
                .fontWeight(.semibold)
                .lineLimit(2)
            
            Text(recommendation.reason)
                .font(.caption)
                .foregroundColor(.secondary)
                .lineLimit(2)
            
            if let savings = recommendation.potentialSavings {
                Text("Save $\(savings, specifier: "%.2f")")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(.green)
            }
        }
        .frame(width: 150)
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

struct PriceDropRow: View {
    let alert: DealAlert
    
    var body: some View {
        HStack {
            // Product image placeholder
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.gray.opacity(0.3))
                .frame(width: 60, height: 60)
                .overlay(
                    Image(systemName: "photo")
                        .foregroundColor(.gray)
                )
            
            VStack(alignment: .leading, spacing: 4) {
                Text(alert.product.name)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .lineLimit(1)
                
                HStack {
                    Text("$\(alert.currentPrice, specifier: "%.2f")")
                        .font(.subheadline)
                        .fontWeight(.bold)
                        .foregroundColor(.green)
                    
                    Text("$\(alert.previousPrice, specifier: "%.2f")")
                        .font(.caption)
                        .strikethrough()
                        .foregroundColor(.secondary)
                    
                    Text("\(Int(alert.discountPercentage))% off")
                        .font(.caption)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.red.opacity(0.1))
                        .foregroundColor(.red)
                        .cornerRadius(4)
                }
                
                Text(alert.retailer.name)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .foregroundColor(.gray)
                .font(.caption)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(10)
        .shadow(radius: 2)
    }
}

// MARK: - View Model
class HomeDashboardViewModel: ObservableObject {
    @Published var dailyDigest: DailyDigest?
    @Published var monthlySavings: Double = 0
    @Published var totalSavings: Double = 0
    @Published var recommendations: [AIRecommendation] = []
    @Published var recentPriceDrops: [DealAlert] = []
    @Published var showNotifications = false
    
    private let claudeService = ClaudeAPIService.shared
    
    func loadDashboard() {
        // Simulate loading data
        // In production, this would fetch from your backend
        
        dailyDigest = DailyDigest(
            dealCount: 5,
            totalSavings: 127.50,
            urgentDeals: 2,
            restockReminders: 3
        )
        
        monthlySavings = 245.80
        totalSavings = 1893.45
        
        // Load mock recommendations
        loadMockRecommendations()
        loadMockPriceDrops()
    }
    
    private func loadMockRecommendations() {
        // In production, this would call Claude API
        recommendations = [
            AIRecommendation(
                product: Product(
                    name: "Instant Pot Duo 7-in-1",
                    description: "Multi-cooker",
                    category: .home,
                    imageURL: nil,
                    barcode: nil,
                    brand: "Instant Pot"
                ),
                reason: "Based on your cooking habits",
                confidenceScore: 0.85,
                potentialSavings: 35.00,
                alternativeProducts: [],
                bestTimeToBy: nil,
                createdAt: Date()
            )
        ]
    }
    
    private func loadMockPriceDrops() {
        // Mock data for demo
        let mockProduct = Product(
            name: "AirPods Pro (2nd Gen)",
            description: "Wireless earbuds",
            category: .electronics,
            imageURL: nil,
            barcode: nil,
            brand: "Apple"
        )
        
        recentPriceDrops = [
            DealAlert(
                product: mockProduct,
                retailer: Retailer.allRetailers[0],
                currentPrice: 199.99,
                previousPrice: 249.99,
                discount: 50.00,
                discountPercentage: 20,
                alertDate: Date(),
                expiryDate: Date().addingTimeInterval(86400),
                dealType: .priceDropAlert
            )
        ]
    }
}

// MARK: - Supporting Models
struct DailyDigest {
    let dealCount: Int
    let totalSavings: Double
    let urgentDeals: Int
    let restockReminders: Int
}

#Preview {
    MainTabView()
        .environmentObject(AuthenticationManager())
        .environmentObject(UserPreferences())
}
