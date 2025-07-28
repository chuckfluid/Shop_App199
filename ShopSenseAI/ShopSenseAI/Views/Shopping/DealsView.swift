import SwiftUI

struct DealsView: View {
    @StateObject private var viewModel = DealsViewModel()
    @EnvironmentObject var authManager: AuthenticationManager
    @State private var selectedCategory: Product.ProductCategory? = nil
    @State private var selectedDealType: DealAlert.DealType? = nil
    @State private var showingSavedDealsOnly = false
    @State private var showingFilters = false
    @State private var showingBatchEvaluation = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Enhanced Filter Section
                VStack(spacing: 12) {
                    // Filter Pills
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 10) {
                            FilterPill(title: "All", isSelected: selectedDealType == nil && !showingSavedDealsOnly) {
                                selectedDealType = nil
                                showingSavedDealsOnly = false
                            }
                            
                            FilterPill(
                                title: "Saved (\(viewModel.savedDeals.count))",
                                isSelected: showingSavedDealsOnly
                            ) {
                                showingSavedDealsOnly = true
                                selectedDealType = nil
                            }
                            
                            ForEach(DealAlert.DealType.allCases, id: \.self) { type in
                                FilterPill(
                                    title: type.rawValue,
                                    count: viewModel.dealCount(for: type),
                                    isSelected: selectedDealType == type && !showingSavedDealsOnly
                                ) {
                                    selectedDealType = type
                                    showingSavedDealsOnly = false
                                }
                            }
                        }
                        .padding(.horizontal)
                    }
                    .padding(.vertical, 10)
                    
                    // Advanced Filters Button
                    if !viewModel.deals.isEmpty {
                        HStack {
                            Text("\(viewModel.filteredDeals(type: selectedDealType, savedOnly: showingSavedDealsOnly).count) deals")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            Spacer()
                            
                            Button(action: { showingFilters = true }) {
                                Label("Filters", systemImage: "slider.horizontal.3")
                                    .font(.caption)
                            }
                        }
                        .padding(.horizontal)
                    }
                }
                
                // Deals List
                if viewModel.isLoading {
                    VStack {
                        ProgressView("Loading deals...")
                        Text("Finding the best prices for you")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if viewModel.filteredDeals(type: selectedDealType, savedOnly: showingSavedDealsOnly).isEmpty {
                    EmptyDealsView(showingSavedOnly: showingSavedDealsOnly)
                } else {
                    List {
                        // Premium Batch Evaluation Option
                        if authManager.subscriptionTier == .premium &&
                           viewModel.hasUnevaluatedDeals &&
                           !showingSavedDealsOnly {
                            BatchEvaluationBanner {
                                showingBatchEvaluation = true
                            }
                            .listRowSeparator(.hidden)
                            .listRowInsets(EdgeInsets(top: 5, leading: 16, bottom: 5, trailing: 16))
                        }
                        
                        // Deals
                        ForEach(viewModel.filteredDeals(type: selectedDealType, savedOnly: showingSavedDealsOnly)) { deal in
                            DealCard(
                                deal: deal,
                                viewModel: viewModel,
                                evaluation: viewModel.getCachedEvaluation(for: deal)
                            )
                            .listRowSeparator(.hidden)
                            .listRowInsets(EdgeInsets(top: 5, leading: 16, bottom: 5, trailing: 16))
                        }
                    }
                    .listStyle(PlainListStyle())
                    .refreshable {
                        await viewModel.refreshDeals()
                    }
                }
            }
            .navigationTitle("Deals")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Section("Sort By") {
                            Button(action: { viewModel.sortBy(.savings) }) {
                                Label("Highest Savings", systemImage: viewModel.currentSort == .savings ? "checkmark" : "")
                            }
                            Button(action: { viewModel.sortBy(.percentage) }) {
                                Label("Biggest Discount %", systemImage: viewModel.currentSort == .percentage ? "checkmark" : "")
                            }
                            Button(action: { viewModel.sortBy(.expiring) }) {
                                Label("Expiring Soon", systemImage: viewModel.currentSort == .expiring ? "checkmark" : "")
                            }
                            Button(action: { viewModel.sortBy(.newest) }) {
                                Label("Newest First", systemImage: viewModel.currentSort == .newest ? "checkmark" : "")
                            }
                            
                            if authManager.subscriptionTier == .premium {
                                Button(action: { viewModel.sortBy(.aiScore) }) {
                                    Label("AI Score", systemImage: viewModel.currentSort == .aiScore ? "checkmark" : "")
                                }
                            }
                        }
                    } label: {
                        Image(systemName: "arrow.up.arrow.down.circle")
                            .foregroundColor(.blue)
                    }
                }
                
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: {
                        Task {
                            await viewModel.refreshDeals()
                        }
                    }) {
                        Image(systemName: "arrow.clockwise")
                            .foregroundColor(.blue)
                    }
                }
            }
        }
        .onAppear {
            viewModel.loadDeals()
        }
        .sheet(isPresented: $showingFilters) {
            DealsFilterView(viewModel: viewModel)
        }
        .sheet(isPresented: $showingBatchEvaluation) {
            BatchEvaluationView(viewModel: viewModel)
        }
    }
}

// MARK: - Enhanced Deal Card
struct DealCard: View {
    let deal: DealAlert
    @ObservedObject var viewModel: DealsViewModel
    let evaluation: DealEvaluation?
    
    @State private var showingDetail = false
    @State private var isEvaluating = false
    @State private var localEvaluation: DealEvaluation?
    @State private var isExpanded = false
    
    private var displayEvaluation: DealEvaluation? {
        localEvaluation ?? evaluation
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(deal.product.name)
                        .font(.headline)
                        .lineLimit(2)
                    
                    HStack {
                        Image(systemName: "building.2")
                            .font(.caption)
                        Text(deal.retailer.name)
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Spacer()
                        
                        // Category Badge
                        CategoryBadge(category: deal.product.category)
                    }
                }
                
                Spacer()
                
                // Enhanced Discount Badge
                DiscountBadge(percentage: deal.discountPercentage)
            }
            
            // Price Information
            HStack {
                VStack(alignment: .leading) {
                    Text("$\(deal.currentPrice, specifier: "%.2f")")
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundColor(.green)
                    
                    HStack(spacing: 4) {
                        Text("Was $\(deal.previousPrice, specifier: "%.2f")")
                            .font(.caption)
                            .strikethrough()
                            .foregroundColor(.secondary)
                        
                        Text("Save $\(deal.savings, specifier: "%.2f")")
                            .font(.caption)
                            .foregroundColor(.green)
                            .fontWeight(.medium)
                    }
                }
                
                Spacer()
                
                // Deal Type & Expiry
                VStack(alignment: .trailing, spacing: 4) {
                    DealTypeBadge(dealType: deal.dealType)
                    
                    if let expiry = deal.expiryDate {
                        ExpiryBadge(expiryDate: expiry)
                    }
                }
            }
            
            // AI Evaluation (Cached or Live)
            if let eval = displayEvaluation {
                AIEvaluationView(evaluation: eval, isExpanded: $isExpanded)
            } else if AuthenticationManager.shared.subscriptionTier == .premium {
                Button(action: evaluateDeal) {
                    HStack {
                        if isEvaluating {
                            ProgressView()
                                .scaleEffect(0.8)
                        } else {
                            Image(systemName: "wand.and.stars")
                        }
                        Text(isEvaluating ? "Evaluating..." : "Get AI Analysis")
                            .font(.caption)
                    }
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .disabled(isEvaluating)
            }
            
            // Quick Actions
            HStack(spacing: 12) {
                Button(action: { showingDetail = true }) {
                    Label("Details", systemImage: "info.circle")
                        .font(.caption)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                
                Button(action: {
                    if let url = URL(string: deal.retailer.websiteURL) {
                        UIApplication.shared.open(url)
                    }
                }) {
                    Label("Shop", systemImage: "cart")
                        .font(.caption)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                
                Spacer()
                
                // Share Button
                ShareLink(item: createShareText()) {
                    Image(systemName: "square.and.arrow.up")
                        .font(.caption)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                
                // Save Button
                Button(action: { viewModel.toggleSaveDeal(deal) }) {
                    Image(systemName: viewModel.isSaved(deal) ? "bookmark.fill" : "bookmark")
                        .foregroundColor(viewModel.isSaved(deal) ? .blue : .gray)
                }
                .buttonStyle(.borderless)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
        .sheet(isPresented: $showingDetail) {
            EnhancedDealDetailView(deal: deal, viewModel: viewModel, evaluation: displayEvaluation)
        }
    }
    
    private func evaluateDeal() {
        isEvaluating = true
        
        Task {
            do {
                let userPreferences = UserPreferences()
                let evaluation = try await ClaudeAPIService.shared.evaluateDeal(
                    deal,
                    userPreferences: userPreferences,
                    forceRefresh: true
                )
                
                await MainActor.run {
                    withAnimation {
                        self.localEvaluation = evaluation
                        self.isEvaluating = false
                    }
                    
                    // Cache for future use
                    viewModel.cacheEvaluation(evaluation, for: deal)
                }
            } catch {
                await MainActor.run {
                    self.isEvaluating = false
                    // Show error toast
                }
            }
        }
    }
    
    private func createShareText() -> String {
        var text = "Check out this deal: \(deal.product.name) for $\(String(format: "%.2f", deal.currentPrice))"
        text += " (was $\(String(format: "%.2f", deal.previousPrice)))"
        text += " - Save \(Int(deal.discountPercentage))%"
        text += " at \(deal.retailer.name)"
        
        if let eval = displayEvaluation {
            text += "\n\nAI says: \(eval.recommendation.rawValue) (Score: \(eval.score)/10)"
        }
        
        return text
    }
}

// MARK: - Component Views
struct CategoryBadge: View {
    let category: Product.ProductCategory
    
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: category.icon)
                .font(.caption2)
            Text(category.rawValue)
                .font(.caption2)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(Color(category.color).opacity(0.2))
        .foregroundColor(Color(category.color))
        .cornerRadius(4)
    }
}

struct DiscountBadge: View {
    let percentage: Double
    
    private var badgeColor: Color {
        if percentage >= 50 {
            return .red
        } else if percentage >= 30 {
            return .orange
        } else {
            return .blue
        }
    }
    
    var body: some View {
        VStack(spacing: 2) {
            Text("\(Int(percentage))%")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.white)
            Text("OFF")
                .font(.caption2)
                .fontWeight(.semibold)
                .foregroundColor(.white)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(badgeColor)
        .cornerRadius(8)
    }
}

struct DealTypeBadge: View {
    let dealType: DealAlert.DealType
    
    private var icon: String {
        switch dealType {
        case .priceDropAlert: return "arrow.down.circle"
        case .flashSale: return "bolt.fill"
        case .couponAvailable: return "ticket.fill"
        case .bundleDeal: return "square.stack.3d.up"
        case .seasonalSale: return "leaf.fill"
        }
    }
    
    private var color: Color {
        switch dealType {
        case .priceDropAlert: return .blue
        case .flashSale: return .orange
        case .couponAvailable: return .purple
        case .bundleDeal: return .green
        case .seasonalSale: return .red
        }
    }
    
    var body: some View {
        Label(dealType.rawValue, systemImage: icon)
            .font(.caption)
            .foregroundColor(color)
    }
}

struct ExpiryBadge: View {
    let expiryDate: Date
    
    private var timeRemaining: String {
        let hours = Calendar.current.dateComponents([.hour], from: Date(), to: expiryDate).hour ?? 0
        if hours < 1 {
            return "Expires soon"
        } else if hours < 24 {
            return "\(hours)h left"
        } else {
            let days = hours / 24
            return "\(days)d left"
        }
    }
    
    private var urgencyColor: Color {
        let hours = Calendar.current.dateComponents([.hour], from: Date(), to: expiryDate).hour ?? 0
        if hours < 24 {
            return .red
        } else if hours < 72 {
            return .orange
        } else {
            return .secondary
        }
    }
    
    var body: some View {
        HStack(spacing: 2) {
            Image(systemName: "clock")
                .font(.caption2)
            Text(timeRemaining)
                .font(.caption2)
        }
        .foregroundColor(urgencyColor)
    }
}

struct AIEvaluationView: View {
    let evaluation: DealEvaluation
    @Binding var isExpanded: Bool
    
    private var recommendationIcon: String {
        switch evaluation.recommendation {
        case .buy: return "checkmark.circle.fill"
        case .wait: return "clock"
        case .skip: return "xmark.circle"
        }
    }
    
    private var recommendationColor: Color {
        switch evaluation.recommendation {
        case .buy: return .green
        case .wait: return .orange
        case .skip: return .red
        }
    }
    
    private var scoreColor: Color {
        if evaluation.score >= 8 {
            return .green
        } else if evaluation.score >= 6 {
            return .orange
        } else {
            return .red
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "sparkles")
                    .foregroundColor(.purple)
                
                HStack(spacing: 6) {
                    Image(systemName: recommendationIcon)
                        .foregroundColor(recommendationColor)
                    Text(evaluation.recommendation.rawValue.uppercased())
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(recommendationColor)
                }
                
                Spacer()
                
                // Score Badge
                HStack(spacing: 4) {
                    Text("\(evaluation.score)")
                        .font(.caption)
                        .fontWeight(.bold)
                    Text("/10")
                        .font(.caption2)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(scoreColor.opacity(0.2))
                .foregroundColor(scoreColor)
                .cornerRadius(6)
                
                Button(action: { withAnimation { isExpanded.toggle() } }) {
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption)
                        .foregroundColor(.blue)
                }
            }
            
            if isExpanded {
                Text(evaluation.reasoning)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .transition(.opacity)
            } else {
                Text(evaluation.reasoning)
                    .font(.caption)
                    .lineLimit(1)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color.purple.opacity(0.05))
        .cornerRadius(8)
    }
}

struct BatchEvaluationBanner: View {
    let action: () -> Void
    
    var body: some View {
        HStack {
            Image(systemName: "wand.and.stars")
                .foregroundColor(.purple)
            
            VStack(alignment: .leading, spacing: 2) {
                Text("AI Batch Analysis Available")
                    .font(.caption)
                    .fontWeight(.medium)
                Text("Evaluate all deals at once")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Button("Analyze") {
                action()
            }
            .font(.caption)
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
        }
        .padding()
        .background(Color.purple.opacity(0.1))
        .cornerRadius(8)
    }
}

// MARK: - Filter Pill
struct FilterPill: View {
    let title: String
    var count: Int? = nil
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Text(title)
                    .font(.caption)
                    .fontWeight(isSelected ? .semibold : .regular)
                
                if let count = count, count > 0 {
                    Text("(\(count))")
                        .font(.caption2)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(isSelected ? Color.blue : Color(.systemGray6))
            .foregroundColor(isSelected ? .white : .primary)
            .cornerRadius(15)
        }
    }
}

// MARK: - Empty Deals View
struct EmptyDealsView: View {
    let showingSavedOnly: Bool
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: showingSavedOnly ? "bookmark.slash" : "tag.slash")
                .font(.system(size: 60))
                .foregroundColor(.gray)
            
            Text(showingSavedOnly ? "No saved deals" : "No deals available")
                .font(.headline)
                .foregroundColor(.gray)
            
            Text(showingSavedOnly ?
                 "Save deals to view them here later" :
                 "Check back later or adjust your preferences to find more deals")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            if !showingSavedOnly {
                Button("Adjust Preferences") {
                    // Navigate to preferences
                }
                .buttonStyle(.bordered)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Enhanced Deal Detail View
struct EnhancedDealDetailView: View {
    let deal: DealAlert
    @ObservedObject var viewModel: DealsViewModel
    let evaluation: DealEvaluation?
    
    @Environment(\.dismiss) var dismiss
    @State private var selectedTab = 0
    @State private var priceHistory: [PricePoint] = []
    @State private var isLoadingHistory = false
    
    var body: some View {
        NavigationView {
            VStack {
                // Tab Selection
                Picker("View", selection: $selectedTab) {
                    Text("Overview").tag(0)
                    Text("Price History").tag(1)
                    Text("Similar Deals").tag(2)
                }
                .pickerStyle(SegmentedPickerStyle())
                .padding()
                
                ScrollView {
                    switch selectedTab {
                    case 0:
                        OverviewTab(deal: deal, viewModel: viewModel, evaluation: evaluation)
                    case 1:
                        PriceHistoryTab(deal: deal, priceHistory: $priceHistory, isLoading: $isLoadingHistory)
                    case 2:
                        SimilarDealsTab(deal: deal, viewModel: viewModel)
                    default:
                        EmptyView()
                    }
                }
            }
            .navigationTitle("Deal Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .onAppear {
            loadPriceHistory()
        }
    }
    
    private func loadPriceHistory() {
        isLoadingHistory = true
        
        // Simulate loading price history
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.priceHistory = generateMockPriceHistory()
            self.isLoadingHistory = false
        }
    }
    
    private func generateMockPriceHistory() -> [PricePoint] {
        var history: [PricePoint] = []
        for days in stride(from: 0, to: 30, by: 3) {
            let date = Date().addingTimeInterval(-TimeInterval(days * 86400))
            let basePrice = deal.previousPrice
            let variation = Double.random(in: -20...5)
            
            history.append(PricePoint(
                retailer: deal.retailer,
                price: basePrice + variation,
                timestamp: date,
                url: deal.retailer.websiteURL,
                inStock: true,
                shippingCost: nil
            ))
        }
        return history
    }
}

// Detail View Tabs
struct OverviewTab: View {
    let deal: DealAlert
    @ObservedObject var viewModel: DealsViewModel
    let evaluation: DealEvaluation?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Product Card
            ProductInfoCard(product: deal.product, retailer: deal.retailer)
            
            // Price Details
            PriceDetailsCard(deal: deal)
            
            // AI Analysis
            if let eval = evaluation {
                AIAnalysisCard(evaluation: eval)
            } else if AuthenticationManager.shared.subscriptionTier == .premium {
                GetAIAnalysisCard { evaluation in
                    viewModel.cacheEvaluation(evaluation, for: deal)
                }
            }
            
            // Action Buttons
            ActionButtonsSection(deal: deal)
        }
        .padding()
    }
}

struct PriceHistoryTab: View {
    let deal: DealAlert
    @Binding var priceHistory: [PricePoint]
    @Binding var isLoading: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            if isLoading {
                HStack {
                    ProgressView()
                    Text("Loading price history...")
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding()
            } else {
                // Price Chart
                VStack(alignment: .leading, spacing: 12) {
                    Text("30-Day Price Trend")
                        .font(.headline)
                    
                    SimplePriceChart(data: priceHistory, currentPrice: deal.currentPrice)
                        .frame(height: 200)
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
                }
                .padding()
                
                // Historical Prices List
                VStack(alignment: .leading, spacing: 12) {
                    Text("Price History")
                        .font(.headline)
                        .padding(.horizontal)
                    
                    ForEach(priceHistory.prefix(10)) { point in
                        HStack {
                            VStack(alignment: .leading) {
                                Text(point.timestamp, style: .date)
                                    .font(.subheadline)
                                Text(point.timestamp, style: .time)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            Text("$\(point.price, specifier: "%.2f")")
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundColor(point.price <= deal.currentPrice ? .green : .primary)
                        }
                        .padding(.horizontal)
                        .padding(.vertical, 4)
                    }
                }
            }
        }
    }
}

struct SimilarDealsTab: View {
    let deal: DealAlert
    @ObservedObject var viewModel: DealsViewModel
    
    private var similarDeals: [DealAlert] {
        viewModel.deals.filter { otherDeal in
            otherDeal.id != deal.id &&
            (otherDeal.product.category == deal.product.category ||
             otherDeal.retailer.id == deal.retailer.id)
        }.prefix(5).map { $0 }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            if similarDeals.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 40))
                        .foregroundColor(.gray)
                    
                    Text("No similar deals found")
                        .font(.headline)
                        .foregroundColor(.gray)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding()
            } else {
                ForEach(similarDeals) { similarDeal in
                    CompactDealCard(deal: similarDeal)
                        .padding(.horizontal)
                }
            }
        }
        .padding(.vertical)
    }
}

// MARK: - Component Cards
struct ProductInfoCard: View {
    let product: Product
    let retailer: Retailer
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Product Image Placeholder
            RoundedRectangle(cornerRadius: 12)
                .fill(LinearGradient(
                    colors: [Color(product.category.color).opacity(0.3), .blue.opacity(0.3)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ))
                .frame(height: 150)
                .overlay(
                    VStack {
                        Image(systemName: product.category.icon)
                            .font(.system(size: 50))
                            .foregroundColor(.white)
                        Text(product.category.rawValue)
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.8))
                    }
                )
            
            VStack(alignment: .leading, spacing: 8) {
                Text(product.name)
                    .font(.title3)
                    .fontWeight(.bold)
                
                if let brand = product.brand {
                    Text(brand)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                HStack {
                    Image(systemName: "building.2")
                        .font(.caption)
                    Text(retailer.name)
                        .font(.caption)
                }
                .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(radius: 1)
    }
}

struct PriceDetailsCard: View {
    let deal: DealAlert
    
    var body: some View {
        VStack(spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Current Price")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("$\(deal.currentPrice, specifier: "%.2f")")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.green)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text("Original Price")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("$\(deal.previousPrice, specifier: "%.2f")")
                        .font(.title3)
                        .strikethrough()
                        .foregroundColor(.secondary)
                }
            }
            
            Divider()
            
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("You Save")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    HStack(spacing: 8) {
                        Text("$\(deal.savings, specifier: "%.2f")")
                            .font(.headline)
                            .foregroundColor(.green)
                        Text("(\(Int(deal.discountPercentage))%)")
                            .font(.subheadline)
                            .foregroundColor(.green)
                    }
                }
                
                Spacer()
                
                if let expiry = deal.expiryDate {
                    VStack(alignment: .trailing, spacing: 4) {
                        Text("Expires")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(expiry, style: .relative)
                            .font(.subheadline)
                            .foregroundColor(.orange)
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

struct AIAnalysisCard: View {
    let evaluation: DealEvaluation
    @State private var showFullAnalysis = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "sparkles")
                    .foregroundColor(.purple)
                Text("AI Analysis")
                    .font(.headline)
                Spacer()
            }
            
            // Recommendation
            HStack {
                Text("Recommendation:")
                    .font(.subheadline)
                Spacer()
                Text(evaluation.recommendation.rawValue.uppercased())
                    .font(.subheadline)
                    .fontWeight(.bold)
                    .foregroundColor(recommendationColor)
            }
            
            // Score
            HStack {
                Text("Deal Score:")
                    .font(.subheadline)
                Spacer()
                ScoreIndicator(score: evaluation.score)
            }
            
            // Reasoning
            VStack(alignment: .leading, spacing: 8) {
                Text("Analysis:")
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text(evaluation.reasoning)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(showFullAnalysis ? nil : 3)
                
                if evaluation.reasoning.count > 100 {
                    Button(showFullAnalysis ? "Show Less" : "Show More") {
                        withAnimation {
                            showFullAnalysis.toggle()
                        }
                    }
                    .font(.caption)
                    .foregroundColor(.blue)
                }
            }
        }
        .padding()
        .background(Color.purple.opacity(0.05))
        .cornerRadius(12)
    }
    
    private var recommendationColor: Color {
        switch evaluation.recommendation {
        case .buy: return .green
        case .wait: return .orange
        case .skip: return .red
        }
    }
}

struct ScoreIndicator: View {
    let score: Int
    
    private var scoreColor: Color {
        if score >= 8 {
            return .green
        } else if score >= 6 {
            return .orange
        } else {
            return .red
        }
    }
    
    var body: some View {
        HStack(spacing: 2) {
            ForEach(1...10, id: \.self) { index in
                Circle()
                    .fill(index <= score ? scoreColor : Color(.systemGray4))
                    .frame(width: 8, height: 8)
            }
            
            Text("\(score)/10")
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.leading, 4)
        }
    }
}

struct GetAIAnalysisCard: View {
    let onEvaluation: (DealEvaluation) -> Void
    @State private var isEvaluating = false
    
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "wand.and.stars")
                .font(.title2)
                .foregroundColor(.purple)
            
            Text("Get AI Analysis")
                .font(.headline)
            
            Text("See if this deal is worth it based on your preferences")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            Button(action: evaluateDeal) {
                if isEvaluating {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                } else {
                    Text("Analyze Deal")
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(isEvaluating)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    private func evaluateDeal() {
        // Implement evaluation
    }
}

struct ActionButtonsSection: View {
    let deal: DealAlert
    
    var body: some View {
        VStack(spacing: 12) {
            Button(action: {
                if let url = URL(string: deal.retailer.websiteURL) {
                    UIApplication.shared.open(url)
                }
            }) {
                Label("Shop This Deal", systemImage: "cart.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            
            HStack(spacing: 12) {
                ShareLink(item: createShareText()) {
                    Label("Share", systemImage: "square.and.arrow.up")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                
                Button(action: { /* Add to list */ }) {
                    Label("Add to List", systemImage: "plus.circle")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
            }
        }
    }
    
    private func createShareText() -> String {
        "Check out this deal: \(deal.product.name) for $\(String(format: "%.2f", deal.currentPrice)) at \(deal.retailer.name) - Save \(Int(deal.discountPercentage))%!"
    }
}

struct CompactDealCard: View {
    let deal: DealAlert
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(deal.product.name)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .lineLimit(1)
                
                HStack {
                    Text("$\(deal.currentPrice, specifier: "%.2f")")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(.green)
                    
                    Text("$\(deal.previousPrice, specifier: "%.2f")")
                        .font(.caption)
                        .strikethrough()
                        .foregroundColor(.secondary)
                }
                
                Text(deal.retailer.name)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                Text("\(Int(deal.discountPercentage))% OFF")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.red)
                    .cornerRadius(4)
                
                if let expiry = deal.expiryDate {
                    Text(expiry, style: .relative)
                        .font(.caption2)
                        .foregroundColor(.orange)
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }
}

struct SimplePriceChart: View {
    let data: [PricePoint]
    let currentPrice: Double
    
    var body: some View {
        GeometryReader { geometry in
            if data.isEmpty {
                Text("No data available")
                    .foregroundColor(.gray)
                    .frame(width: geometry.size.width, height: geometry.size.height)
            } else {
                // Simple line chart implementation
                ZStack {
                    // Current price line
                    Path { path in
                        let y = geometry.size.height * 0.5
                        path.move(to: CGPoint(x: 0, y: y))
                        path.addLine(to: CGPoint(x: geometry.size.width, y: y))
                    }
                    .stroke(Color.green, style: StrokeStyle(lineWidth: 1, dash: [5]))
                    
                    // Price trend line
                    Path { path in
                        let sortedData = data.sorted { $0.timestamp < $1.timestamp }
                        guard let minPrice = sortedData.map({ $0.price }).min(),
                              let maxPrice = sortedData.map({ $0.price }).max() else { return }
                        
                        let priceRange = maxPrice - minPrice
                        let xStep = geometry.size.width / CGFloat(sortedData.count - 1)
                        
                        for (index, point) in sortedData.enumerated() {
                            let x = CGFloat(index) * xStep
                            let y = geometry.size.height - ((point.price - minPrice) / priceRange * geometry.size.height)
                            
                            if index == 0 {
                                path.move(to: CGPoint(x: x, y: y))
                            } else {
                                path.addLine(to: CGPoint(x: x, y: y))
                            }
                        }
                    }
                    .stroke(Color.blue, lineWidth: 2)
                }
            }
        }
    }
}

// MARK: - Advanced Filters View
struct DealsFilterView: View {
    @ObservedObject var viewModel: DealsViewModel
    @Environment(\.dismiss) var dismiss
    
    @State private var selectedCategories = Set<Product.ProductCategory>()
    @State private var selectedRetailers = Set<String>()
    @State private var minDiscount: Double = 0
    @State private var maxPrice: Double = 1000
    @State private var onlyExpiring = false
    
    var body: some View {
        NavigationView {
            Form {
                Section("Categories") {
                    ForEach(Product.ProductCategory.allCases, id: \.self) { category in
                        HStack {
                            Image(systemName: category.icon)
                                .foregroundColor(Color(category.color))
                                .frame(width: 30)
                            
                            Text(category.rawValue)
                            
                            Spacer()
                            
                            if selectedCategories.contains(category) {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.blue)
                            }
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            if selectedCategories.contains(category) {
                                selectedCategories.remove(category)
                            } else {
                                selectedCategories.insert(category)
                            }
                        }
                    }
                }
                
                Section("Retailers") {
                    ForEach(Retailer.allRetailers, id: \.id) { retailer in
                        HStack {
                            Text(retailer.name)
                            
                            Spacer()
                            
                            if selectedRetailers.contains(retailer.id) {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.blue)
                            }
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            if selectedRetailers.contains(retailer.id) {
                                selectedRetailers.remove(retailer.id)
                            } else {
                                selectedRetailers.insert(retailer.id)
                            }
                        }
                    }
                }
                
                Section("Price & Discount") {
                    VStack(alignment: .leading) {
                        Text("Minimum Discount: \(Int(minDiscount))%")
                            .font(.subheadline)
                        Slider(value: $minDiscount, in: 0...90, step: 5)
                    }
                    
                    VStack(alignment: .leading) {
                        Text("Maximum Price: $\(Int(maxPrice))")
                            .font(.subheadline)
                        Slider(value: $maxPrice, in: 0...1000, step: 10)
                    }
                }
                
                Section("Other") {
                    Toggle("Only Expiring Soon", isOn: $onlyExpiring)
                }
            }
            .navigationTitle("Filter Deals")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Reset") {
                        resetFilters()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Apply") {
                        applyFilters()
                        dismiss()
                    }
                }
            }
        }
    }
    
    private func resetFilters() {
        selectedCategories.removeAll()
        selectedRetailers.removeAll()
        minDiscount = 0
        maxPrice = 1000
        onlyExpiring = false
    }
    
    private func applyFilters() {
        viewModel.applyFilters(
            categories: selectedCategories,
            retailers: selectedRetailers,
            minDiscount: minDiscount,
            maxPrice: maxPrice,
            onlyExpiring: onlyExpiring
        )
    }
}

// MARK: - Batch Evaluation View
struct BatchEvaluationView: View {
    @ObservedObject var viewModel: DealsViewModel
    @Environment(\.dismiss) var dismiss
    
    @State private var isEvaluating = false
    @State private var progress: Double = 0
    @State private var evaluatedCount = 0
    @State private var results: [DealEvaluation] = []
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                if isEvaluating {
                    VStack(spacing: 16) {
                        ProgressView(value: progress)
                            .progressViewStyle(LinearProgressViewStyle())
                        
                        Text("Evaluating \(evaluatedCount) of \(viewModel.unevaluatedDeals.count) deals...")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        Text("This may take a moment")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding()
                } else if !results.isEmpty {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Evaluation Complete!")
                                .font(.headline)
                            
                            // Summary
                            HStack(spacing: 20) {
                                SummaryCard(
                                    title: "Buy Now",
                                    count: results.filter { $0.recommendation == .buy }.count,
                                    color: .green
                                )
                                
                                SummaryCard(
                                    title: "Wait",
                                    count: results.filter { $0.recommendation == .wait }.count,
                                    color: .orange
                                )
                                
                                SummaryCard(
                                    title: "Skip",
                                    count: results.filter { $0.recommendation == .skip }.count,
                                    color: .red
                                )
                            }
                            
                            Text("Top recommendations have been highlighted in your deals list")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding()
                    }
                } else {
                    VStack(spacing: 20) {
                        Image(systemName: "wand.and.stars")
                            .font(.system(size: 60))
                            .foregroundColor(.purple)
                        
                        Text("Batch AI Analysis")
                            .font(.title2)
                            .fontWeight(.bold)
                        
                        Text("Evaluate all \(viewModel.unevaluatedDeals.count) deals at once using AI")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                        
                        Text("This will help you quickly identify the best deals")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Button("Start Analysis") {
                            startBatchEvaluation()
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(viewModel.unevaluatedDeals.isEmpty)
                    }
                    .padding()
                }
            }
            .navigationTitle("Batch Analysis")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
    
    private func startBatchEvaluation() {
        isEvaluating = true
        evaluatedCount = 0
        progress = 0
        
        Task {
            let userPreferences = UserPreferences()
            let deals = viewModel.unevaluatedDeals
            let totalCount = deals.count
            
            for (index, deal) in deals.enumerated() {
                do {
                    let evaluation = try await ClaudeAPIService.shared.evaluateDeal(
                        deal,
                        userPreferences: userPreferences
                    )
                    
                    await MainActor.run {
                        results.append(evaluation)
                        viewModel.cacheEvaluation(evaluation, for: deal)
                        evaluatedCount = index + 1
                        progress = Double(evaluatedCount) / Double(totalCount)
                    }
                    
                    // Small delay to prevent rate limiting
                    try await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
                    
                } catch {
                    print("Error evaluating deal: \(error)")
                }
            }
            
            await MainActor.run {
                isEvaluating = false
            }
        }
    }
}

struct SummaryCard: View {
    let title: String
    let count: Int
    let color: Color
    
    var body: some View {
        VStack {
            Text("\(count)")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(color)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(color.opacity(0.1))
        .cornerRadius(8)
    }
}

// MARK: - View Model
class DealsViewModel: ObservableObject {
    @Published var deals: [DealAlert] = []
    @Published var savedDeals: Set<UUID> = []
    @Published var isLoading = false
    @Published var currentSort: SortOption = .newest
    
    private var evaluationCache: [UUID: DealEvaluation] = [:]
    private let cacheManager = APICacheManager.shared
    
    enum SortOption {
        case savings
        case percentage
        case expiring
        case newest
        case aiScore
    }
    
    var unevaluatedDeals: [DealAlert] {
        deals.filter { evaluationCache[$0.id] == nil }
    }
    
    var hasUnevaluatedDeals: Bool {
        !unevaluatedDeals.isEmpty
    }
    
    init() {
        loadSavedDeals()
        loadCachedEvaluations()
    }
    
    func loadDeals() {
        isLoading = true
        
        // In production, fetch from backend
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.generateMockDeals()
            self.isLoading = false
        }
    }
    
    func refreshDeals() async {
        await MainActor.run {
            isLoading = true
        }
        
        // Simulate network delay
        try? await Task.sleep(nanoseconds: 1_000_000_000)
        
        await MainActor.run {
            generateMockDeals()
            isLoading = false
        }
    }
    
    private func generateMockDeals() {
        let mockProducts = [
            Product(name: "iPad Air 5th Gen", description: "Tablet with M1 chip", category: .electronics, imageURL: nil, barcode: nil, brand: "Apple"),
            Product(name: "Instant Pot Duo 7-in-1", description: "Electric Pressure Cooker", category: .home, imageURL: nil, barcode: nil, brand: "Instant Pot"),
            Product(name: "Nike Air Max 270", description: "Running Shoes", category: .sports, imageURL: nil, barcode: nil, brand: "Nike"),
            Product(name: "The Great Gatsby", description: "Classic novel", category: .books, imageURL: nil, barcode: nil, brand: nil),
            Product(name: "Vitamin D3 Supplements", description: "Health supplement", category: .health, imageURL: nil, barcode: nil, brand: "Nature Made"),
            Product(name: "Organic Bananas", description: "Fresh fruit", category: .food, imageURL: nil, barcode: nil, brand: nil),
            Product(name: "Sony WH-1000XM5", description: "Noise Cancelling Headphones", category: .electronics, imageURL: nil, barcode: nil, brand: "Sony"),
            Product(name: "Dyson V15 Detect", description: "Cordless Vacuum", category: .home, imageURL: nil, barcode: nil, brand: "Dyson")
        ]
        
        deals = mockProducts.enumerated().map { index, product in
            let previousPrice = Double.random(in: 100...500)
            let discountPercentage = Double.random(in: 10...60)
            let currentPrice = previousPrice * (1 - discountPercentage / 100)
            
            return DealAlert(
                product: product,
                retailer: Retailer.allRetailers[index % Retailer.allRetailers.count],
                currentPrice: currentPrice,
                previousPrice: previousPrice,
                discount: previousPrice - currentPrice,
                discountPercentage: discountPercentage,
                alertDate: Date().addingTimeInterval(-Double.random(in: 0...86400 * 3)),
                expiryDate: Bool.random() ? Date().addingTimeInterval(Double.random(in: 3600...259200)) : nil,
                dealType: DealAlert.DealType.allCases.randomElement()!
            )
        }
        
        sortBy(currentSort)
    }
    
    func filteredDeals(type: DealAlert.DealType?, savedOnly: Bool) -> [DealAlert] {
        var filteredDeals = deals
        
        if savedOnly {
            filteredDeals = filteredDeals.filter { savedDeals.contains($0.id) }
        }
        
        if let type = type {
            filteredDeals = filteredDeals.filter { $0.dealType == type }
        }
        
        return filteredDeals
    }
    
    func dealCount(for type: DealAlert.DealType) -> Int {
        deals.filter { $0.dealType == type }.count
    }
    
    func sortBy(_ option: SortOption) {
        currentSort = option
        
        switch option {
        case .savings:
            deals.sort { $0.savings > $1.savings }
        case .percentage:
            deals.sort { $0.discountPercentage > $1.discountPercentage }
        case .expiring:
            deals.sort { ($0.expiryDate ?? Date.distantFuture) < ($1.expiryDate ?? Date.distantFuture) }
        case .newest:
            deals.sort { $0.alertDate > $1.alertDate }
        case .aiScore:
            // Sort by AI evaluation score if available
            deals.sort { deal1, deal2 in
                let score1 = evaluationCache[deal1.id]?.score ?? 0
                let score2 = evaluationCache[deal2.id]?.score ?? 0
                return score1 > score2
            }
        }
    }
    
    func applyFilters(categories: Set<Product.ProductCategory>, retailers: Set<String>,
                     minDiscount: Double, maxPrice: Double, onlyExpiring: Bool) {
        // Apply filters to deals
        // This would be implemented based on the filter criteria
    }
    
    func toggleSaveDeal(_ deal: DealAlert) {
        if savedDeals.contains(deal.id) {
            savedDeals.remove(deal.id)
        } else {
            savedDeals.insert(deal.id)
        }
        saveDealsToPersistence()
    }
    
    func isSaved(_ deal: DealAlert) -> Bool {
        return savedDeals.contains(deal.id)
    }
    
    // MARK: - Evaluation Cache
    func getCachedEvaluation(for deal: DealAlert) -> DealEvaluation? {
        return evaluationCache[deal.id]
    }
    
    func cacheEvaluation(_ evaluation: DealEvaluation, for deal: DealAlert) {
        evaluationCache[deal.id] = evaluation
        saveCachedEvaluations()
    }
    
    private func loadCachedEvaluations() {
        // Load from cache manager
        for deal in deals {
            let cacheKey = "deal_evaluation_\(deal.id.uuidString)"
            if let cached: DealEvaluation = cacheManager.getCachedResponse(for: cacheKey, type: DealEvaluation.self) {
                evaluationCache[deal.id] = cached
            }
        }
    }
    
    private func saveCachedEvaluations() {
        // Save to cache manager
        for (dealId, evaluation) in evaluationCache {
            let cacheKey = "deal_evaluation_\(dealId.uuidString)"
            cacheManager.cacheResponse(evaluation, for: cacheKey)
        }
    }
    
    private func loadSavedDeals() {
        // Load from UserDefaults
        if let data = UserDefaults.standard.data(forKey: "SavedDeals"),
           let savedArray = try? JSONDecoder().decode([UUID].self, from: data) {
            savedDeals = Set(savedArray)
        }
    }
    
    private func saveDealsToPersistence() {
        // Save to UserDefaults
        let savedArray = Array(savedDeals)
        if let data = try? JSONEncoder().encode(savedArray) {
            UserDefaults.standard.set(data, forKey: "SavedDeals")
        }
    }
}
