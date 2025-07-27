import SwiftUI

struct DealsView: View {
    @StateObject private var viewModel = DealsViewModel()
    @State private var selectedCategory: Product.ProductCategory? = nil
    @State private var selectedDealType: DealAlert.DealType? = nil
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Filter Pills
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        FilterPill(title: "All", isSelected: selectedDealType == nil) {
                            selectedDealType = nil
                        }
                        
                        ForEach(DealAlert.DealType.allCases, id: \.self) { type in
                            FilterPill(
                                title: type.rawValue,
                                isSelected: selectedDealType == type
                            ) {
                                selectedDealType = type
                            }
                        }
                    }
                    .padding(.horizontal)
                }
                .padding(.vertical, 10)
                
                // Deals List
                if viewModel.deals.isEmpty {
                    EmptyDealsView()
                } else {
                    List {
                        ForEach(viewModel.filteredDeals(type: selectedDealType)) { deal in
                            DealCard(deal: deal, viewModel: viewModel)
                                .listRowSeparator(.hidden)
                                .listRowInsets(EdgeInsets(top: 5, leading: 16, bottom: 5, trailing: 16))
                        }
                    }
                    .listStyle(PlainListStyle())
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
                    } label: {
                        Image(systemName: "arrow.up.arrow.down.circle")
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
                .background(Color.red)
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
                    
                    Text(evaluation.reasoning)
                        .font(.caption)
                        .lineLimit(2)
                    
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
            }
            
            // Action Buttons
            HStack {
                Button(action: { showingDetail = true }) {
                    Label("View Deal", systemImage: "arrow.right.circle")
                        .font(.caption)
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
                        }
                    }
                    .buttonStyle(BorderlessButtonStyle())
                    .disabled(isEvaluating)
                }
                
                Button(action: { viewModel.saveDeal(deal) }) {
                    Image(systemName: deal.isSaved ? "bookmark.fill" : "bookmark")
                        .foregroundColor(.blue)
                }
                .buttonStyle(BorderlessButtonStyle())
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(radius: 2)
        .sheet(isPresented: $showingDetail) {
            DealDetailView(deal: deal)
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
    
    private func expiryText(_ date: Date) -> String {
        let hours = Calendar.current.dateComponents([.hour], from: Date(), to: date).hour ?? 0
        if hours < 24 {
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
                // For now, simulate with delay
                try await Task.sleep(nanoseconds: 2_000_000_000)
                
                await MainActor.run {
                    evaluation = DealEvaluation(
                        recommendation: .buy,
                        score: 8,
                        reasoning: "Great deal! This price is 15% below the 90-day average."
                    )
                    isEvaluating = false
                }
            } catch {
                isEvaluating = false
            }
        }
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
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "tag.slash")
                .font(.system(size: 60))
                .foregroundColor(.gray)
            
            Text("No deals available")
                .font(.headline)
                .foregroundColor(.gray)
            
            Text("Check back later or adjust your preferences")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Deal Detail View
struct DealDetailView: View {
    let deal: DealAlert
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Product Image Placeholder
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.gray.opacity(0.3))
                        .frame(height: 200)
                        .overlay(
                            Image(systemName: "photo")
                                .font(.system(size: 50))
                                .foregroundColor(.gray)
                        )
                    
                    // Deal Information
                    VStack(alignment: .leading, spacing: 16) {
                        Text(deal.product.name)
                            .font(.title2)
                            .fontWeight(.bold)
                        
                        HStack {
                            VStack(alignment: .leading) {
                                Text("Current Price")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Text("$\(deal.currentPrice, specifier: "%.2f")")
                                    .font(.title)
                                    .fontWeight(.bold)
                                    .foregroundColor(.green)
                            }
                            
                            Spacer()
                            
                            VStack(alignment: .trailing) {
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
                            Image(systemName: "building.2")
                            Text(deal.retailer.name)
                                .fontWeight(.medium)
                            Spacer()
                            Button("Visit Store") {
                                // Open retailer URL
                            }
                            .buttonStyle(.borderedProminent)
                        }
                        
                        // Deal Details
                        VStack(alignment: .leading, spacing: 8) {
                            Label(deal.dealType.rawValue, systemImage: "tag.fill")
                            
                            if let expiry = deal.expiryDate {
                                Label("Expires \(expiry, style: .relative)", systemImage: "clock")
                                    .foregroundColor(.orange)
                            }
                            
                            Label("Posted \(deal.alertDate, style: .relative)", systemImage: "calendar")
                                .foregroundColor(.secondary)
                        }
                        .font(.subheadline)
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
    }
}

// MARK: - View Model
class DealsViewModel: ObservableObject {
    @Published var deals: [DealAlert] = []
    @Published var savedDeals: Set<UUID> = []
    
    enum SortOption {
        case savings
        case percentage
        case expiring
    }
    
    func loadDeals() {
        // In production, fetch from backend
        // Mock data for demo
        let mockProducts = [
            Product(name: "iPad Air", description: "Tablet", category: .electronics, imageURL: nil, barcode: nil, brand: "Apple"),
            Product(name: "Instant Pot", description: "Pressure Cooker", category: .home, imageURL: nil, barcode: nil, brand: "Instant Pot"),
            Product(name: "Running Shoes", description: "Athletic footwear", category: .clothing, imageURL: nil, barcode: nil, brand: "Nike")
        ]
        
        deals = mockProducts.enumerated().map { index, product in
            DealAlert(
                product: product,
                retailer: Retailer.allRetailers[index % Retailer.allRetailers.count],
                currentPrice: Double.random(in: 50...200),
                previousPrice: Double.random(in: 100...300),
                discount: 0,
                discountPercentage: Double.random(in: 10...50),
                alertDate: Date().addingTimeInterval(-Double.random(in: 0...86400)),
                expiryDate: Date().addingTimeInterval(Double.random(in: 3600...259200)),
                dealType: DealAlert.DealType.allCases.randomElement()!
            )
        }
    }
    
    func filteredDeals(type: DealAlert.DealType?) -> [DealAlert] {
        guard let type = type else { return deals }
        return deals.filter { $0.dealType == type }
    }
    
    func sortBy(_ option: SortOption) {
        switch option {
        case .savings:
            deals.sort { $0.savings > $1.savings }
        case .percentage:
            deals.sort { $0.discountPercentage > $1.discountPercentage }
        case .expiring:
            deals.sort { ($0.expiryDate ?? Date.distantFuture) < ($1.expiryDate ?? Date.distantFuture) }
        }
    }
    
    func saveDeal(_ deal: DealAlert) {
        if savedDeals.contains(deal.id) {
            savedDeals.remove(deal.id)
        } else {
            savedDeals.insert(deal.id)
        }
    }
}

// MARK: - Extensions
extension DealAlert.DealType: CaseIterable {
    static var allCases: [DealAlert.DealType] {
        return [.priceDropAlert, .flashSale, .couponAvailable, .bundleDeal, .seasonalSale]
    }
}

extension DealAlert {
    var isSaved: Bool {
        // This would check against saved deals in the view model
        return false
    }
}
