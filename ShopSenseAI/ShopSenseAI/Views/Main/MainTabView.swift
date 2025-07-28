import SwiftUI

struct MainTabView: View {
    @State private var selectedTab = 0
    @State private var showingAddItem = false
    @State private var showingPriceCheck = false
    @State private var showingAIInsights = false
    @State private var showingAlerts = false
    
    @EnvironmentObject var authManager: AuthenticationManager
    @EnvironmentObject var userPreferences: UserPreferencesManager
    @EnvironmentObject var notificationService: NotificationService
    @EnvironmentObject var priceTrackingService: PriceTrackingService
    
    var body: some View {
        TabView(selection: $selectedTab) {
            // Home Dashboard
            HomeDashboardView(
                showingAddItem: $showingAddItem,
                showingPriceCheck: $showingPriceCheck,
                showingAIInsights: $showingAIInsights,
                showingAlerts: $showingAlerts
            )
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
        .sheet(isPresented: $showingAddItem) {
            NavigationView {
                AddItemView(viewModel: ShoppingListViewModel())
            }
        }
        .sheet(isPresented: $showingPriceCheck) {
            NavigationView {
                PriceCheckView()
            }
        }
        .sheet(isPresented: $showingAIInsights) {
            NavigationView {
                AIInsightsView()
            }
        }
        .sheet(isPresented: $showingAlerts) {
            NavigationView {
                AlertsManagementView()
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
    
    @Binding var showingAddItem: Bool
    @Binding var showingPriceCheck: Bool
    @Binding var showingAIInsights: Bool
    @Binding var showingAlerts: Bool
    
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
                    
                    // Quick Actions - NOW FUNCTIONAL
                    QuickActionsSection(
                        showingAddItem: $showingAddItem,
                        showingPriceCheck: $showingPriceCheck,
                        showingAIInsights: $showingAIInsights,
                        showingAlerts: $showingAlerts
                    )
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
                                                .onTapGesture {
                                                    viewModel.selectedRecommendation = recommendation
                                                    viewModel.showingRecommendationDetail = true
                                                }
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
                                    NavigationLink(destination: DealDetailView(deal: alert, viewModel: DealsViewModel())) {
                                        PriceDropRow(alert: alert)
                                    }
                                    .buttonStyle(PlainButtonStyle())
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
                                        .onTapGesture {
                                            viewModel.selectedInventoryItem = item
                                            viewModel.showingInventoryDetail = true
                                        }
                                }
                            }
                            .padding(.horizontal)
                        }
                    }
                    
                    // Batch Processing Status (Premium Only)
                    if authManager.subscriptionTier == .premium {
                        BatchProcessingStatusCard()
                            .padding(.horizontal)
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
        .sheet(isPresented: $viewModel.showingRecommendationDetail) {
            if let recommendation = viewModel.selectedRecommendation {
                RecommendationDetailView(recommendation: recommendation)
            }
        }
        .sheet(isPresented: $viewModel.showingInventoryDetail) {
            if let item = viewModel.selectedInventoryItem {
                InventoryDetailView(item: item, viewModel: InventoryViewModel())
            }
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
            
            NavigationLink(destination: AnalyticsView()) {
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .foregroundColor(.blue)
                    .font(.title2)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

struct QuickActionsSection: View {
    @Binding var showingAddItem: Bool
    @Binding var showingPriceCheck: Bool
    @Binding var showingAIInsights: Bool
    @Binding var showingAlerts: Bool
    
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
                    showingAddItem = true
                }
                
                QuickActionButton(
                    icon: "magnifyingglass",
                    title: "Price Check",
                    color: .green
                ) {
                    showingPriceCheck = true
                }
                
                QuickActionButton(
                    icon: "wand.and.stars",
                    title: "AI Insights",
                    color: .purple
                ) {
                    showingAIInsights = true
                }
                
                QuickActionButton(
                    icon: "bell.badge",
                    title: "Alerts",
                    color: .orange
                ) {
                    showingAlerts = true
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

struct BatchProcessingStatusCard: View {
    @State private var lastBatchProcessingTime: Date? = APICacheManager.shared.lastBatchProcessingTime
    @State private var nextScheduledTime: Date? = APICacheManager.shared.nextScheduledBatchTime
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "gearshape.2")
                    .foregroundColor(.purple)
                Text("AI Processing Status")
                    .font(.caption)
                    .fontWeight(.semibold)
                Spacer()
                Text("Premium")
                    .font(.caption2)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.purple.opacity(0.2))
                    .foregroundColor(.purple)
                    .cornerRadius(4)
            }
            
            HStack {
                if let lastTime = lastBatchProcessingTime {
                    Text("Last update: \(lastTime, style: .relative)")
                } else {
                    Text("No batch processing yet")
                }
                
                Spacer()
                
                if let nextTime = nextScheduledTime {
                    Text("Next: \(nextTime, style: .relative)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .font(.caption)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }
}

// MARK: - New Views for Quick Actions

struct PriceCheckView: View {
    @State private var searchText = ""
    @State private var scannedBarcode = ""
    @State private var isScanning = false
    @State private var searchResults: [Product] = []
    @State private var isSearching = false
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        VStack {
            // Search Bar
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.gray)
                TextField("Search product or enter barcode...", text: $searchText)
                    .onSubmit {
                        searchProduct()
                    }
                
                Button(action: { isScanning = true }) {
                    Image(systemName: "barcode.viewfinder")
                        .foregroundColor(.blue)
                }
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(10)
            .padding()
            
            if isSearching {
                ProgressView("Searching...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if searchResults.isEmpty {
                VStack(spacing: 20) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 60))
                        .foregroundColor(.gray)
                    
                    Text("Search for any product")
                        .font(.headline)
                        .foregroundColor(.gray)
                    
                    Text("Enter a product name or scan a barcode to check prices across all retailers")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(searchResults) { product in
                    ProductPriceRow(product: product)
                }
            }
        }
        .navigationTitle("Price Check")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Done") { dismiss() }
            }
        }
        .sheet(isPresented: $isScanning) {
            BarcodeScannerView(scannedCode: $scannedBarcode)
                .onDisappear {
                    if !scannedBarcode.isEmpty {
                        searchText = scannedBarcode
                        searchProduct()
                    }
                }
        }
    }
    
    private func searchProduct() {
        isSearching = true
        
        // Simulate search
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            // Mock results
            searchResults = [
                Product(
                    name: searchText,
                    description: "Search result",
                    category: .other,
                    imageURL: nil,
                    barcode: scannedBarcode.isEmpty ? nil : scannedBarcode,
                    brand: "Various"
                )
            ]
            isSearching = false
        }
    }
}

struct BarcodeScannerView: View {
    @Binding var scannedCode: String
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        VStack {
            Text("Barcode Scanner")
                .font(.title2)
                .fontWeight(.bold)
                .padding()
            
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemGray6))
                .frame(height: 300)
                .overlay(
                    VStack {
                        Image(systemName: "barcode.viewfinder")
                            .font(.system(size: 60))
                            .foregroundColor(.gray)
                        Text("Camera view would appear here")
                            .foregroundColor(.gray)
                    }
                )
                .padding()
            
            Text("Point camera at barcode")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            // Mock scan button for demo
            Button("Simulate Scan") {
                scannedCode = "123456789012"
                dismiss()
            }
            .buttonStyle(.borderedProminent)
            .padding()
            
            Spacer()
        }
    }
}

struct ProductPriceRow: View {
    let product: Product
    @State private var priceData: [PricePoint] = []
    @State private var isLoading = true
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(product.name)
                .font(.headline)
            
            if isLoading {
                HStack {
                    ProgressView()
                    Text("Checking prices...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.vertical)
            } else {
                ForEach(priceData) { price in
                    HStack {
                        Text(price.retailer.name)
                            .font(.subheadline)
                        
                        Spacer()
                        
                        VStack(alignment: .trailing) {
                            Text("$\(price.totalPrice, specifier: "%.2f")")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                            
                            if price.inStock {
                                Text("In Stock")
                                    .font(.caption)
                                    .foregroundColor(.green)
                            } else {
                                Text("Out of Stock")
                                    .font(.caption)
                                    .foregroundColor(.red)
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .onAppear {
            loadPrices()
        }
    }
    
    private func loadPrices() {
        // Simulate price loading
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            priceData = Retailer.allRetailers.map { retailer in
                PricePoint(
                    retailer: retailer,
                    price: Double.random(in: 50...200),
                    timestamp: Date(),
                    url: retailer.websiteURL,
                    inStock: Bool.random(),
                    shippingCost: Bool.random() ? nil : Double.random(in: 5...15)
                )
            }
            isLoading = false
        }
    }
}

struct AIInsightsView: View {
    @StateObject private var viewModel = AIInsightsViewModel()
    @EnvironmentObject var authManager: AuthenticationManager
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                if authManager.subscriptionTier == .premium {
                    // Shopping Patterns
                    InsightSection(
                        title: "Shopping Patterns",
                        icon: "chart.xyaxis.line",
                        loading: viewModel.isLoadingPatterns
                    ) {
                        if let analysis = viewModel.shoppingAnalysis {
                            ForEach(analysis.patterns, id: \.self) { pattern in
                                InsightRow(text: pattern)
                            }
                        }
                    }
                    
                    // Savings Opportunities
                    InsightSection(
                        title: "Savings Opportunities",
                        icon: "dollarsign.circle",
                        loading: viewModel.isLoadingOpportunities
                    ) {
                        if let analysis = viewModel.shoppingAnalysis {
                            ForEach(analysis.savingsOpportunities, id: \.item) { opportunity in
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(opportunity.item)
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                    Text(opportunity.recommendation)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    Text("Save ~$\(opportunity.potentialSaving, specifier: "%.2f")")
                                        .font(.caption)
                                        .foregroundColor(.green)
                                }
                                .padding(.vertical, 4)
                            }
                        }
                    }
                    
                    // Budget Optimization
                    InsightSection(
                        title: "Budget Optimization",
                        icon: "chart.pie",
                        loading: viewModel.isLoadingBudget
                    ) {
                        if let recommendation = viewModel.budgetRecommendation {
                            ForEach(recommendation.recommendations, id: \.self) { rec in
                                InsightRow(text: rec)
                            }
                        }
                    }
                } else {
                    // Free user prompt
                    VStack(spacing: 20) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 60))
                            .foregroundColor(.purple)
                        
                        Text("AI Insights")
                            .font(.title2)
                            .fontWeight(.bold)
                        
                        Text("Get personalized shopping insights powered by Claude AI")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                        
                        VStack(alignment: .leading, spacing: 12) {
                            FeatureRow(icon: "chart.xyaxis.line", text: "Shopping pattern analysis")
                            FeatureRow(icon: "dollarsign.circle", text: "Personalized savings recommendations")
                            FeatureRow(icon: "calendar", text: "Optimal buying time predictions")
                            FeatureRow(icon: "chart.pie", text: "Budget optimization strategies")
                        }
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
                        
                        Button("Upgrade to Premium") {
                            dismiss()
                            // Show upgrade sheet
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .padding()
                }
            }
            .padding()
        }
        .navigationTitle("AI Insights")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Done") { dismiss() }
            }
        }
        .onAppear {
            if authManager.subscriptionTier == .premium {
                viewModel.loadInsights()
            }
        }
    }
}

struct InsightSection<Content: View>: View {
    let title: String
    let icon: String
    let loading: Bool
    @ViewBuilder let content: () -> Content
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(.purple)
                Text(title)
                    .font(.headline)
                Spacer()
            }
            
            if loading {
                HStack {
                    ProgressView()
                    Text("Analyzing...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.vertical)
            } else {
                content()
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

struct InsightRow: View {
    let text: String
    
    var body: some View {
        HStack {
            Circle()
                .fill(Color.purple.opacity(0.2))
                .frame(width: 6, height: 6)
            Text(text)
                .font(.subheadline)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.vertical, 2)
    }
}

struct FeatureRow: View {
    let icon: String
    let text: String
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(.purple)
                .frame(width: 30)
            Text(text)
                .font(.subheadline)
            Spacer()
        }
    }
}

struct AlertsManagementView: View {
    @EnvironmentObject var notificationService: NotificationService
    @EnvironmentObject var priceTrackingService: PriceTrackingService
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        List {
            Section("Active Price Alerts") {
                if priceTrackingService.priceAlerts.isEmpty {
                    Text("No active price alerts")
                        .foregroundColor(.secondary)
                } else {
                    ForEach(priceTrackingService.priceAlerts.filter { !$0.isRead }) { alert in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(alert.product.name)
                                .font(.subheadline)
                                .fontWeight(.medium)
                            Text(alert.message)
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text(alert.timestamp, style: .relative)
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
            
            Section("Tracking Items") {
                ForEach(priceTrackingService.trackingItems) { item in
                    HStack {
                        VStack(alignment: .leading) {
                            Text(item.product.name)
                                .font(.subheadline)
                            if let targetPrice = item.targetPrice {
                                Text("Target: $\(targetPrice, specifier: "%.2f")")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        Spacer()
                        
                        Toggle("", isOn: .constant(item.isActive))
                            .labelsHidden()
                    }
                }
            }
            
            Section {
                Button("Clear Read Alerts") {
                    priceTrackingService.clearReadAlerts()
                }
                .foregroundColor(.red)
            }
        }
        .navigationTitle("Alerts Management")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Done") { dismiss() }
            }
        }
    }
}

struct RecommendationDetailView: View {
    let recommendation: AIRecommendation
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Product Info
                    VStack(alignment: .center) {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(LinearGradient(
                                colors: [.blue.opacity(0.3), .purple.opacity(0.3)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ))
                            .frame(height: 200)
                            .overlay(
                                VStack {
                                    Image(systemName: recommendation.product.category.icon)
                                        .font(.system(size: 60))
                                        .foregroundColor(.white)
                                    Text(recommendation.product.category.rawValue)
                                        .foregroundColor(.white.opacity(0.8))
                                }
                            )
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text(recommendation.product.name)
                            .font(.title2)
                            .fontWeight(.bold)
                        
                        Label(recommendation.type.rawValue, systemImage: "sparkles")
                            .font(.subheadline)
                            .foregroundColor(.purple)
                    }
                    .padding(.horizontal)
                    
                    // Recommendation Details
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Why This Recommendation")
                            .font(.headline)
                        
                        Text(recommendation.reason)
                            .font(.subheadline)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                    .padding(.horizontal)
                    
                    // Potential Savings
                    if let savings = recommendation.potentialSavings {
                        HStack {
                            VStack(alignment: .leading) {
                                Text("Potential Savings")
                                    .font(.headline)
                                Text("Based on historical data")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            Text("$\(savings, specifier: "%.2f")")
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(.green)
                        }
                        .padding()
                        .background(Color.green.opacity(0.1))
                        .cornerRadius(12)
                        .padding(.horizontal)
                    }
                    
                    // Best Time to Buy
                    if let dateRange = recommendation.bestTimeToBuy {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Optimal Purchase Window")
                                .font(.headline)
                            
                            Text(dateRange.description)
                                .font(.subheadline)
                                .padding()
                                .frame(maxWidth: .infinity)
                                .background(Color.blue.opacity(0.1))
                                .cornerRadius(8)
                        }
                        .padding(.horizontal)
                    }
                    
                    // Alternative Products
                    if !recommendation.alternativeProducts.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Alternative Options")
                                .font(.headline)
                                .padding(.horizontal)
                            
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 12) {
                                    ForEach(recommendation.alternativeProducts) { alternative in
                                        VStack(alignment: .leading) {
                                            Text(alternative.name)
                                                .font(.subheadline)
                                                .fontWeight(.medium)
                                            Text("Save more")
                                                .font(.caption)
                                                .foregroundColor(.green)
                                        }
                                        .padding()
                                        .background(Color(.systemGray6))
                                        .cornerRadius(8)
                                    }
                                }
                                .padding(.horizontal)
                            }
                        }
                    }
                    
                    // Actions
                    VStack(spacing: 12) {
                        Button(action: { /* Add to shopping list */ }) {
                            Label("Add to Shopping List", systemImage: "cart.badge.plus")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        
                        Button(action: { /* Start tracking */ }) {
                            Label("Track Price", systemImage: "chart.line.uptrend.xyaxis")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                    }
                    .padding()
                }
            }
            .navigationTitle("Recommendation")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
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
                    .disabled(notificationService.deliveredNotifications.isEmpty)
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

// MARK: - View Models
class HomeDashboardViewModel: ObservableObject {
    @Published var dailyDigest: DailyDigest?
    @Published var monthlySavings: Double = 0
    @Published var totalSavings: Double = 0
    @Published var recommendations: [AIRecommendation] = []
    @Published var recentPriceDrops: [DealAlert] = []
    @Published var lowStockItems: [InventoryItem] = []
    @Published var showNotifications = false
    @Published var showUpgrade = false
    @Published var showingRecommendationDetail = false
    @Published var selectedRecommendation: AIRecommendation?
    @Published var showingInventoryDetail = false
    @Published var selectedInventoryItem: InventoryItem?
    
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
                reason: "Based on your cooking habits and frequent grocery purchases, this could save you time and money on meal prep",
                confidenceScore: 0.85,
                potentialSavings: 35.00,
                alternativeProducts: [],
                bestTimeToBuy: AIRecommendation.DateRange(
                    start: Date(),
                    end: Date().addingTimeInterval(7 * 86400)
                ),
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
                reason: "Price dropped 30% below 90-day average. Perfect time to stock up on your regularly purchased vitamins",
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

class AIInsightsViewModel: ObservableObject {
    @Published var shoppingAnalysis: ShoppingAnalysis?
    @Published var budgetRecommendation: BudgetRecommendation?
    @Published var isLoadingPatterns = false
    @Published var isLoadingOpportunities = false
    @Published var isLoadingBudget = false
    
    private let claudeService = ClaudeAPIService.shared
    
    func loadInsights() {
        loadShoppingPatterns()
        loadBudgetOptimization()
    }
    
    private func loadShoppingPatterns() {
        isLoadingPatterns = true
        isLoadingOpportunities = true
        
        Task {
            do {
                // Mock data for now
                let purchases: [Purchase] = []
                let inventory: [InventoryItem] = []
                
                let analysis = try await claudeService.analyzeShoppingPattern(
                    purchases: purchases,
                    inventory: inventory
                )
                
                await MainActor.run {
                    self.shoppingAnalysis = analysis
                    self.isLoadingPatterns = false
                    self.isLoadingOpportunities = false
                }
            } catch {
                print("Error loading shopping patterns: \(error)")
                await MainActor.run {
                    self.isLoadingPatterns = false
                    self.isLoadingOpportunities = false
                }
            }
        }
    }
    
    private func loadBudgetOptimization() {
        isLoadingBudget = true
        
        Task {
            do {
                let budget = Budget(
                    monthlyLimit: 1000,
                    categories: [:],
                    currentMonthSpending: 750,
                    alerts: []
                )
                
                let recommendation = try await claudeService.optimizeBudget(
                    currentBudget: budget,
                    purchases: [],
                    goals: ["Save for vacation", "Reduce grocery spending"]
                )
                
                await MainActor.run {
                    self.budgetRecommendation = recommendation
                    self.isLoadingBudget = false
                }
            } catch {
                print("Error loading budget optimization: \(error)")
                await MainActor.run {
                    self.isLoadingBudget = false
                }
            }
        }
    }
}

// MARK: - Supporting Models
struct DailyDigest {
    let dealCount: Int
    let totalSavings: Double
    let urgentDeals: Int
    let restockReminders: Int
}

// MARK: - APICacheManager Extension
extension APICacheManager {
    var lastBatchProcessingTime: Date? {
        UserDefaults.standard.object(forKey: "LastBatchProcessingTime") as? Date
    }
    
    var nextScheduledBatchTime: Date? {
        guard let lastTime = lastBatchProcessingTime else {
            // If never run, schedule for 3 AM tomorrow
            let calendar = Calendar.current
            var components = calendar.dateComponents([.year, .month, .day], from: Date())
            components.hour = 3
            components.minute = 0
            return calendar.date(byAdding: .day, value: 1, to: calendar.date(from: components)!)
        }
        
        // Next run is 24 hours after last run
        return lastTime.addingTimeInterval(86400)
    }
}

#Preview {
    MainTabView()
        .environmentObject(AuthenticationManager.shared)
        .environmentObject(UserPreferencesManager.shared)
        .environmentObject(NotificationService.shared)
        .environmentObject(PriceTrackingService.shared)
}
