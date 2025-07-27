import SwiftUI

struct DealsView: View {
    @StateObject private var viewModel = DealsViewModel()
    @State private var selectedCategory: Product.ProductCategory? = nil
    @State private var selectedDealType: DealAlert.DealType? = nil
    @State private var showingSavedDealsOnly = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Filter Pills
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        FilterPill(title: "All", isSelected: selectedDealType == nil && !showingSavedDealsOnly) {
                            selectedDealType = nil
                            showingSavedDealsOnly = false
                        }
                        
                        FilterPill(title: "Saved", isSelected: showingSavedDealsOnly) {
                            showingSavedDealsOnly = true
                            selectedDealType = nil
                        }
                        
                        ForEach(DealAlert.DealType.allCases, id: \.self) { type in
                            FilterPill(
                                title: type.rawValue,
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
                
                // Deals List
                if viewModel.isLoading {
                    ProgressView("Loading deals...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if viewModel.filteredDeals(type: selectedDealType, savedOnly: showingSavedDealsOnly).isEmpty {
                    EmptyDealsView(showingSavedOnly: showingSavedDealsOnly)
                } else {
                    List {
                        ForEach(viewModel.filteredDeals(type: selectedDealType, savedOnly: showingSavedDealsOnly)) { deal in
                            DealCard(deal: deal, viewModel: viewModel)
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
                        Button(action: { viewModel.sortBy(.savings) }) {
                            Label("Highest Savings", systemImage: "arrow.down.circle")
                        }
                        Button(action: { viewModel.sortBy(.percentage) }) {
                            Label("Biggest Discount %", systemImage: "percent")
                        }
                        Button(action: { viewModel.sortBy(.expiring) }) {
                            Label("Expiring Soon", systemImage: "clock")
                        }
                        Button(action: { viewModel.sortBy(.newest) }) {
                            Label("Newest First", systemImage: "calendar")
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
    }
}

// MARK: - Deal Card
struct DealCard: View {
    let deal: DealAlert
    @ObservedObject var viewModel: DealsViewModel
    @State private var showingDetail = false
    @State private var isEvaluating = false
    @State private var evaluation: DealEvaluation?
    
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
                        Text(deal.product.category.rawValue)
                            .font(.caption2)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color(.systemGray5))
                            .cornerRadius(4)
                    }
                }
                
                Spacer()
                
                // Discount Badge
                VStack {
                    Text("\(Int(deal.discountPercentage))%")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                    Text("OFF")
                        .font(.caption2)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                }
                .padding(8)
                .background(discountBadgeColor)
                .cornerRadius(8)
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
                    Label(deal.dealType.rawValue, systemImage: dealTypeIcon)
                        .font(.caption)
                        .foregroundColor(dealTypeColor)
                    
                    if let expiry = deal.expiryDate {
                        HStack(spacing: 2) {
                            Image(systemName: "clock")
                                .font(.caption2)
                            Text(expiryText(expiry))
                                .font(.caption2)
                        }
                        .foregroundColor(expiryColor(expiry))
                    }
                }
            }
            
            // AI Evaluation
            if let evaluation = evaluation {
                HStack {
                    Image(systemName: "sparkles")
                        .foregroundColor(.purple)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("AI Recommendation: \(evaluation.recommendation.rawValue.uppercased())")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(recommendationColor(evaluation.recommendation))
                        
                        Text(evaluation.reasoning)
                            .font(.caption)
                            .lineLimit(2)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    // Score Badge
                    Text("\(evaluation.score)/10")
                        .font(.caption)
                        .fontWeight(.bold)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(scoreColor(evaluation.score))
                        .foregroundColor(.white)
                        .cornerRadius(6)
                }
                .padding(.top, 8)
                .padding(.bottom, 4)
                .background(Color.purple.opacity(0.05))
                .cornerRadius(8)
            }
            
            // Action Buttons
            HStack(spacing: 12) {
                Button(action: { showingDetail = true }) {
                    Label("View Deal", systemImage: "arrow.right.circle")
                        .font(.caption)
                        .foregroundColor(.blue)
                }
                .buttonStyle(BorderlessButtonStyle())
                
                Button(action: {
                    if let url = URL(string: deal.retailer.websiteURL) {
                        UIApplication.shared.open(url)
                    }
                }) {
                    Label("Shop Now", systemImage: "cart")
                        .font(.caption)
                        .foregroundColor(.green)
                }
                .buttonStyle(BorderlessButtonStyle())
                
                Spacer()
                
                if evaluation == nil {
                    Button(action: evaluateDeal) {
                        if isEvaluating {
                            ProgressView()
                                .scaleEffect(0.8)
                        } else {
                            Label("AI Evaluate", systemImage: "wand.and.stars")
                                .font(.caption)
                                .foregroundColor(.purple)
                        }
                    }
                    .buttonStyle(BorderlessButtonStyle())
                    .disabled(isEvaluating)
                }
                
                Button(action: { viewModel.toggleSaveDeal(deal) }) {
                    Image(systemName: viewModel.isSaved(deal) ? "bookmark.fill" : "bookmark")
                        .foregroundColor(.blue)
                }
                .buttonStyle(BorderlessButtonStyle())
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
        .sheet(isPresented: $showingDetail) {
            DealDetailView(deal: deal, viewModel: viewModel)
        }
    }
    
    private var discountBadgeColor: Color {
        if deal.discountPercentage >= 50 {
            return .red
        } else if deal.discountPercentage >= 30 {
            return .orange
        } else {
            return .blue
        }
    }
    
    private var dealTypeIcon: String {
        switch deal.dealType {
        case .priceDropAlert: return "arrow.down.circle"
        case .flashSale: return "bolt.fill"
        case .couponAvailable: return "ticket.fill"
        case .bundleDeal: return "square.stack.3d.up"
        case .seasonalSale: return "leaf.fill"
        }
    }
    
    private var dealTypeColor: Color {
        switch deal.dealType {
        case .priceDropAlert: return .blue
        case .flashSale: return .orange
        case .couponAvailable: return .purple
        case .bundleDeal: return .green
        case .seasonalSale: return .red
        }
    }
    
    private func recommendationColor(_ recommendation: DealEvaluation.Recommendation) -> Color {
        switch recommendation {
        case .buy: return .green
        case .wait: return .orange
        case .skip: return .red
        }
    }
    
    private func expiryText(_ date: Date) -> String {
        let hours = Calendar.current.dateComponents([.hour], from: Date(), to: date).hour ?? 0
        if hours < 1 {
            return "Expires soon"
        } else if hours < 24 {
            return "\(hours)h left"
        } else {
            let days = hours / 24
            return "\(days)d left"
        }
    }
    
    private func expiryColor(_ date: Date) -> Color {
        let hours = Calendar.current.dateComponents([.hour], from: Date(), to: date).hour ?? 0
        if hours < 24 {
            return .red
        } else if hours < 72 {
            return .orange
        } else {
            return .secondary
        }
    }
    
    private func scoreColor(_ score: Int) -> Color {
        if score >= 8 {
            return .green
        } else if score >= 6 {
            return .orange
        } else {
            return .red
        }
    }
    
    private func evaluateDeal() {
        isEvaluating = true
        
        Task {
            do {
                // In production, this would call Claude API
                let userPreferences = UserPreferences() // Mock preferences
                let apiService = ClaudeAPIService.shared
                
                evaluation = try await apiService.evaluateDeal(deal, userPreferences: userPreferences)
                
                await MainActor.run {
                    isEvaluating = false
                }
            } catch {
                // Fallback to mock evaluation if API fails
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                
                await MainActor.run {
                    evaluation = DealEvaluation(
                        recommendation: mockRecommendation(),
                        score: Int.random(in: 5...9),
                        reasoning: mockReasoning()
                    )
                    isEvaluating = false
                }
            }
        }
    }
    
    private func mockRecommendation() -> DealEvaluation.Recommendation {
        if deal.discountPercentage >= 40 {
            return .buy
        } else if deal.discountPercentage >= 20 {
            return .wait
        } else {
            return .skip
        }
    }
    
    private func mockReasoning() -> String {
        let reasons = [
            "Great deal! This price is below the 90-day average.",
            "Good discount, but you might find better deals during seasonal sales.",
            "Price is okay, but this product frequently goes on sale.",
            "Excellent value! This is the lowest price we've seen.",
            "Consider waiting - similar deals often appear during holidays."
        ]
        return reasons.randomElement() ?? "Analysis complete."
    }
}

// MARK: - Filter Pill
struct FilterPill: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.caption)
                .fontWeight(isSelected ? .semibold : .regular)
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
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Deal Detail View
struct DealDetailView: View {
    let deal: DealAlert
    @ObservedObject var viewModel: DealsViewModel
    @Environment(\.dismiss) var dismiss
    @State private var showingShareSheet = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Product Image Placeholder
                    RoundedRectangle(cornerRadius: 12)
                        .fill(LinearGradient(
                            colors: [.blue.opacity(0.3), .purple.opacity(0.3)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ))
                        .frame(height: 200)
                        .overlay(
                            VStack {
                                Image(systemName: categoryIcon(for: deal.product.category))
                                    .font(.system(size: 50))
                                    .foregroundColor(.white)
                                Text(deal.product.category.rawValue)
                                    .font(.caption)
                                    .foregroundColor(.white.opacity(0.8))
                            }
                        )
                    
                    // Deal Information
                    VStack(alignment: .leading, spacing: 16) {
                        Text(deal.product.name)
                            .font(.title2)
                            .fontWeight(.bold)
                        
                        // Price Section
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Current Price")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Text("$\(deal.currentPrice, specifier: "%.2f")")
                                    .font(.title)
                                    .fontWeight(.bold)
                                    .foregroundColor(.green)
                            }
                            
                            Spacer()
                            
                            VStack(alignment: .trailing, spacing: 4) {
                                Text("You Save")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                HStack(spacing: 4) {
                                    Text("$\(deal.savings, specifier: "%.2f")")
                                        .font(.title3)
                                        .fontWeight(.semibold)
                                    Text("(\(Int(deal.discountPercentage))%)")
                                        .font(.subheadline)
                                        .foregroundColor(.green)
                                }
                            }
                        }
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
                        
                        // Retailer Info
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Label(deal.retailer.name, systemImage: "building.2")
                                    .fontWeight(.medium)
                                Text("Trusted retailer")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            Button("Visit Store") {
                                if let url = URL(string: deal.retailer.websiteURL) {
                                    UIApplication.shared.open(url)
                                }
                            }
                            .buttonStyle(.borderedProminent)
                        }
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
                        
                        // Deal Details
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Deal Details")
                                .font(.headline)
                            
                            VStack(alignment: .leading, spacing: 8) {
                                Label(deal.dealType.rawValue, systemImage: dealTypeIcon)
                                
                                if let expiry = deal.expiryDate {
                                    Label("Expires \(expiry, style: .relative)", systemImage: "clock")
                                        .foregroundColor(.orange)
                                }
                                
                                Label("Posted \(deal.alertDate, style: .relative)", systemImage: "calendar")
                                    .foregroundColor(.secondary)
                                
                                Label("Original price: $\(deal.previousPrice, specifier: "%.2f")", systemImage: "tag")
                                    .foregroundColor(.secondary)
                            }
                            .font(.subheadline)
                        }
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
                        
                        // Action Buttons
                        VStack(spacing: 12) {
                            Button(action: {
                                if let url = URL(string: deal.retailer.websiteURL) {
                                    UIApplication.shared.open(url)
                                }
                            }) {
                                Label("Shop This Deal", systemImage: "cart.fill")
                                    .font(.headline)
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(Color.green)
                                    .cornerRadius(12)
                            }
                            
                            HStack(spacing: 12) {
                                Button(action: { viewModel.toggleSaveDeal(deal) }) {
                                    Label(
                                        viewModel.isSaved(deal) ? "Remove from Saved" : "Save Deal",
                                        systemImage: viewModel.isSaved(deal) ? "bookmark.fill" : "bookmark"
                                    )
                                    .frame(maxWidth: .infinity)
                                }
                                .buttonStyle(.bordered)
                                
                                Button(action: { showingShareSheet = true }) {
                                    Label("Share", systemImage: "square.and.arrow.up")
                                        .frame(maxWidth: .infinity)
                                }
                                .buttonStyle(.bordered)
                            }
                        }
                    }
                    .padding(.horizontal)
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
        .sheet(isPresented: $showingShareSheet) {
            ShareSheet(deal: deal)
        }
    }
    
    private var dealTypeIcon: String {
        switch deal.dealType {
        case .priceDropAlert: return "arrow.down.circle"
        case .flashSale: return "bolt.fill"
        case .couponAvailable: return "ticket.fill"
        case .bundleDeal: return "square.stack.3d.up"
        case .seasonalSale: return "leaf.fill"
        }
    }
    
    private func categoryIcon(for category: Product.ProductCategory) -> String {
        switch category {
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
}

// MARK: - Share Sheet
struct ShareSheet: UIViewControllerRepresentable {
    let deal: DealAlert
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        let text = "Check out this deal: \(deal.product.name) for $\(String(format: "%.2f", deal.currentPrice)) (was $\(String(format: "%.2f", deal.previousPrice))) at \(deal.retailer.name)"
        let activityController = UIActivityViewController(activityItems: [text], applicationActivities: nil)
        return activityController
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

// MARK: - View Model
class DealsViewModel: ObservableObject {
    @Published var deals: [DealAlert] = []
    @Published var savedDeals: Set<UUID> = []
    @Published var isLoading = false
    
    enum SortOption {
        case savings
        case percentage
        case expiring
        case newest
    }
    
    init() {
        loadSavedDeals()
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
            Product(name: "Organic Bananas", description: "Fresh fruit", category: .food, imageURL: nil, barcode: nil, brand: nil)
        ]
        
        deals = mockProducts.enumerated().map { index, product in
            let previousPrice = Double.random(in: 100...300)
            let discountPercentage = Double.random(in: 15...60)
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
    
    func sortBy(_ option: SortOption) {
        switch option {
        case .savings:
            deals.sort { $0.savings > $1.savings }
        case .percentage:
            deals.sort { $0.discountPercentage > $1.discountPercentage }
        case .expiring:
            deals.sort { ($0.expiryDate ?? Date.distantFuture) < ($1.expiryDate ?? Date.distantFuture) }
        case .newest:
            deals.sort { $0.alertDate > $1.alertDate }
        }
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
