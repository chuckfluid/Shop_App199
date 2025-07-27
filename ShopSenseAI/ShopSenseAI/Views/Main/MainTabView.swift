import SwiftUI

struct MainTabView: View {
    @State private var selectedTab = 0
    @EnvironmentObject var authManager: AuthenticationManager
    @EnvironmentObject var userPreferences: UserPreferencesManager
    @EnvironmentObject var notificationService: NotificationService
    @EnvironmentObject var priceTrackingService: PriceTrackingService
    
    var body: some View {
        TabView(selection: $selectedTab) {
            // Home Dashboard
            HomeDashboardView()
                .tabItem {
                    Label("Home", systemImage: "house.fill")
                }
                .tag(0)
            
            // Shopping List
            NavigationView {
                ShoppingListView()
            }
            .tabItem {
                Label("Shopping", systemImage: "cart.fill")
            }
            .tag(1)
            
            // Deals
            DealsView()
                .tabItem {
                    Label("Deals", systemImage: "tag.fill")
                }
                .badge(notificationService.unreadCount > 0 ? notificationService.unreadCount : 0)
                .tag(2)
            
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
        .onReceive(NotificationCenter.default.publisher(for: .navigateToDeals)) { _ in
            selectedTab = 2
        }
        .onReceive(NotificationCenter.default.publisher(for: .navigateToInventory)) { _ in
            selectedTab = 3
        }
        .onReceive(NotificationCenter.default.publisher(for: .navigateToProduct)) { notification in
            // Navigate to appropriate tab based on context
            if let userInfo = notification.userInfo,
               let action = userInfo["action"] as? String,
               action == "reorder" {
                selectedTab = 3 // Inventory tab
            } else {
                selectedTab = 1 // Shopping tab
            }
        }
    }
}

// MARK: - Home Dashboard View
struct HomeDashboardView: View {
    @StateObject private var viewModel = HomeDashboardViewModel()
    @EnvironmentObject var authManager: AuthenticationManager
    @EnvironmentObject var userPreferences: UserPreferencesManager
    @EnvironmentObject var notificationService: NotificationService
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Welcome Header
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            VStack(alignment: .leading) {
                                Text("Good \(timeOfDayGreeting())")
                                    .font(.title2)
                                    .fontWeight(.bold)
                                
                                Text("Ready to save money today?")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            // Notification Bell
                            Button(action: { viewModel.showNotifications = true }) {
                                ZStack {
                                    Image(systemName: "bell.fill")
                                        .foregroundColor(.blue)
                                        .font(.title3)
                                    
                                    if notificationService.unreadCount > 0 {
                                        Circle()
                                            .fill(Color.red)
                                            .frame(width: 8, height: 8)
                                            .offset(x: 8, y: -8)
                                    }
                                }
                            }
                        }
                        .padding(.horizontal)
                    }
                    
                    // Daily Digest Card
                    DailyDigestCard(digest: viewModel.dailyDigest)
                        .padding(.horizontal)
                    
                    // Savings Summary
                    SavingsSummaryCard(
                        monthlySavings: viewModel.monthlySavings,
                        totalSavings: viewModel.totalSavings
                    )
                    .padding(.horizontal)
                    
                    // Quick Actions
                    QuickActionsSection()
                        .padding(.horizontal)
                    
                    // AI Recommendations
                    if !viewModel.recommendations.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Image(systemName: "sparkles")
                                    .foregroundColor(.purple)
                                Text("AI Recommendations")
                                    .font(.headline)
                                Spacer()
                                if authManager.subscriptionTier == .free {
                                    Text("Premium")
                                        .font(.caption2)
                                        .fontWeight(.bold)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(Color.purple.opacity(0.2))
                                        .foregroundColor(.purple)
                                        .cornerRadius(4)
                                }
                            }
                            .padding(.horizontal)
                            
                            if authManager.subscriptionTier == .premium {
                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 12) {
                                        ForEach(viewModel.recommendations) { recommendation in
                                            RecommendationCard(recommendation: recommendation)
                                        }
                                    }
                                    .padding(.horizontal)
                                }
                            } else {
                                // Upgrade prompt for free users
                                VStack(spacing: 8) {
                                    Text("Upgrade to see personalized AI recommendations")
                                        .font(.subheadline)
                                        .multilineTextAlignment(.center)
                                    
                                    Button("Upgrade to Premium") {
                                        viewModel.showUpgrade = true
                                    }
                                    .buttonStyle(.borderedProminent)
                                    .controlSize(.small)
                                }
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.purple.opacity(0.1))
                                .cornerRadius(12)
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
                    
                    // Low Stock Items
                    if !viewModel.lowStockItems.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundColor(.orange)
                                Text("Items Running Low")
                                    .font(.headline)
                                Spacer()
                                NavigationLink("View All", destination: InventoryView())
                                    .font(.caption)
                            }
                            .padding(.horizontal)
                            
                            VStack(spacing: 8) {
                                ForEach(viewModel.lowStockItems.prefix(3)) { item in
                                    LowStockRow(item: item)
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
            .refreshable {
                await viewModel.refreshDashboard()
            }
        }
        .onAppear {
            viewModel.loadDashboard()
        }
        .sheet(isPresented: $viewModel.showNotifications) {
            NotificationsView()
                .environmentObject(notificationService)
        }
        .sheet(isPresented: $viewModel.showUpgrade) {
            SubscriptionDetailsView()
                .environmentObject(authManager)
        }
    }
    
    private func timeOfDayGreeting() -> String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5..<12: return "Morning"
        case 12..<17: return "Afternoon"
        case 17..<22: return "Evening"
        default: return "Night"
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
                HStack {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("Loading today's insights...")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Spacer()
                }
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
            
            Image(systemName: "chart.line.uptrend.xyaxis")
                .foregroundColor(.blue)
                .font(.title2)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

struct QuickActionsSection: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Quick Actions")
                .font(.headline)
            
            HStack(spacing: 12) {
                QuickActionButton(
                    icon: "plus.circle.fill",
                    title: "Add Item",
                    color: .blue
                ) {
                    // Navigate to add item
                }
                
                QuickActionButton(
                    icon: "magnifyingglass",
                    title: "Price Check",
                    color: .green
                ) {
                    // Navigate to price check
                }
                
                QuickActionButton(
                    icon: "wand.and.stars",
                    title: "AI Insights",
                    color: .purple
                ) {
                    // Show AI insights
                }
                
                QuickActionButton(
                    icon: "bell.badge",
                    title: "Alerts",
                    color: .orange
                ) {
                    // Show alerts
                }
            }
        }
    }
}

struct QuickActionButton: View {
    let icon: String
    let title: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(color)
                
                Text(title)
                    .font(.caption)
                    .foregroundColor(.primary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(Color(.systemGray6))
            .cornerRadius(12)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct RecommendationCard: View {
    let recommendation: AIRecommendation
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Product image placeholder with category icon
            RoundedRectangle(cornerRadius: 8)
                .fill(LinearGradient(
                    colors: [.blue.opacity(0.3), .purple.opacity(0.3)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ))
                .frame(width: 150, height: 100)
                .overlay(
                    Image(systemName: recommendation.product.category.icon)
                        .font(.system(size: 30))
                        .foregroundColor(.white)
                )
            
            Text(recommendation.product.name)
                .font(.subheadline)
                .fontWeight(.semibold)
                .lineLimit(2)
            
            Text(recommendation.reason)
                .font(.caption)
                .foregroundColor(.secondary)
                .lineLimit(2)
            
            HStack {
                if let savings = recommendation.potentialSavings {
                    Text("Save $\(savings, specifier: "%.2f")")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(.green)
                }
                
                Spacer()
                
                Text(recommendation.type.rawValue)
                    .font(.caption2)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.purple.opacity(0.2))
                    .foregroundColor(.purple)
                    .cornerRadius(4)
            }
        }
        .frame(width: 150)
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(radius: 2)
    }
}

struct PriceDropRow: View {
    let alert: DealAlert
    
    var body: some View {
        HStack {
            // Product image placeholder
            RoundedRectangle(cornerRadius: 8)
                .fill(LinearGradient(
                    colors: [.green.opacity(0.3), .blue.opacity(0.3)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ))
                .frame(width: 60, height: 60)
                .overlay(
                    Image(systemName: alert.product.category.icon)
                        .foregroundColor(.white)
                        .font(.title3)
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
        .shadow(radius: 1)
    }
}

struct LowStockRow: View {
    let item: InventoryItem
    
    var body: some View {
        HStack {
            Circle()
                .fill(Color.orange)
                .frame(width: 8, height: 8)
            
            Text(item.product.name)
                .font(.subheadline)
                .fontWeight(.medium)
            
            Spacer()
            
            Text("\(item.currentQuantity)/\(item.preferredQuantity)")
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.orange.opacity(0.1))
                .cornerRadius(6)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }
}

// MARK: - Notifications View
struct NotificationsView: View {
    @EnvironmentObject var notificationService: NotificationService
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            List {
                ForEach(notificationService.deliveredNotifications, id: \.request.identifier) { notification in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(notification.request.content.title)
                            .font(.subheadline)
                            .fontWeight(.semibold)
                        
                        Text(notification.request.content.body)
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Text(notification.date, style: .relative)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 4)
                }
                .onDelete(perform: deleteNotifications)
            }
            .navigationTitle("Notifications")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Clear All") {
                        notificationService.removeAllNotifications()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
    
    private func deleteNotifications(at offsets: IndexSet) {
        for index in offsets {
            let notification = notificationService.deliveredNotifications[index]
            notificationService.removeNotification(withIdentifier: notification.request.identifier)
        }
    }
}

// MARK: - View Model
class HomeDashboardViewModel: ObservableObject {
    @Published var dailyDigest: DailyDigest?
    @Published var monthlySavings: Double = 0
    @Published var totalSavings: Double = 0
    @Published var recommendations: [AIRecommendation] = []
    @Published var recentPriceDrops: [DealAlert] = []
    @Published var lowStockItems: [InventoryItem] = []
    @Published var showNotifications = false
    @Published var showUpgrade = false
    
    private let claudeService = ClaudeAPIService.shared
    
    func loadDashboard() {
        // Simulate loading data
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.dailyDigest = DailyDigest(
                dealCount: 5,
                totalSavings: 127.50,
                urgentDeals: 2,
                restockReminders: 3
            )
            
            self.monthlySavings = 245.80
            self.totalSavings = 1893.45
            
            self.loadMockRecommendations()
            self.loadMockPriceDrops()
            self.loadMockLowStockItems()
        }
    }
    
    func refreshDashboard() async {
        // Simulate network refresh
        try? await Task.sleep(nanoseconds: 1_000_000_000)
        
        await MainActor.run {
            loadDashboard()
        }
    }
    
    private func loadMockRecommendations() {
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
                bestTimeToBuy: nil,
                createdAt: Date(),
                type: .priceDrop
            ),
            AIRecommendation(
                product: Product(
                    name: "Vitamin D3 Supplements",
                    description: "Health supplement",
                    category: .health,
                    imageURL: nil,
                    barcode: nil,
                    brand: "Nature Made"
                ),
                reason: "Price dropped 30% below average",
                confidenceScore: 0.92,
                potentialSavings: 12.50,
                alternativeProducts: [],
                bestTimeToBuy: nil,
                createdAt: Date(),
                type: .stockUp
            )
        ]
    }
    
    private func loadMockPriceDrops() {
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
    
    private func loadMockLowStockItems() {
        lowStockItems = [
            InventoryItem(
                product: Product(
                    name: "Laundry Detergent",
                    description: "Household cleaning",
                    category: .home,
                    imageURL: nil,
                    barcode: nil,
                    brand: "Tide"
                ),
                currentQuantity: 1,
                preferredQuantity: 3,
                lastPurchaseDate: Date().addingTimeInterval(-30 * 86400),
                averageConsumptionDays: 21,
                autoReorder: true,
                reorderThreshold: 1
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
        .environmentObject(AuthenticationManager.shared)
        .environmentObject(UserPreferencesManager.shared)
        .environmentObject(NotificationService.shared)
        .environmentObject(PriceTrackingService.shared)
}
