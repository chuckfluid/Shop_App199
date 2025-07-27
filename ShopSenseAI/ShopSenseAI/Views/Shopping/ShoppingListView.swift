import SwiftUI
import Foundation

// MARK: - Views
struct ShoppingListView: View {
    @StateObject private var viewModel = ShoppingListViewModel()
    @State private var showingAddItem = false
    @State private var searchText = ""
    
    var body: some View {
        VStack {
            // Search and Filter Bar
            HStack {
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.gray)
                    TextField("Search items...", text: $searchText)
                }
                .padding(8)
                .background(Color(.systemGray6))
                .cornerRadius(8)
                
                Menu {
                    Button("All Items") { viewModel.filterBy(.all) }
                    Button("Tracking Only") { viewModel.filterBy(.tracking) }
                    Divider()
                    ForEach(ShoppingListItem.Priority.allCases, id: \.self) { priority in
                        Button(priority.rawValue) { viewModel.filterBy(.priority(priority)) }
                    }
                } label: {
                    Image(systemName: "line.3.horizontal.decrease.circle")
                        .foregroundColor(.blue)
                }
            }
            .padding(.horizontal)
            
            // Shopping List
            if viewModel.items.isEmpty {
                EmptyShoppingListView()
            } else {
                List {
                    ForEach(viewModel.filteredItems(searchText: searchText)) { item in
                        ShoppingListItemRow(item: item, viewModel: viewModel)
                    }
                    .onDelete(perform: viewModel.deleteItems)
                }
                .listStyle(PlainListStyle())
            }
            
            // Summary Bar
            if !viewModel.items.isEmpty {
                ShoppingSummaryBar(
                    itemCount: viewModel.items.count,
                    estimatedTotal: viewModel.estimatedTotal,
                    potentialSavings: viewModel.potentialSavings
                )
            }
        }
        .navigationTitle("Shopping List")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: { showingAddItem = true }) {
                    Image(systemName: "plus.circle.fill")
                        .foregroundColor(.blue)
                }
            }
            
            ToolbarItem(placement: .navigationBarLeading) {
                EditButton()
            }
        }
        .sheet(isPresented: $showingAddItem) {
            AddItemView(viewModel: viewModel)
        }
    }
}

// MARK: - Shopping List Item Row
struct ShoppingListItemRow: View {
    let item: ShoppingListItem
    @ObservedObject var viewModel: ShoppingListViewModel
    @State private var showingDetail = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                // Priority Indicator
                Circle()
                    .fill(priorityColor)
                    .frame(width: 8, height: 8)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(item.product.name)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    
                    HStack {
                        Text("Qty: \(item.quantity)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        if let targetPrice = item.targetPrice {
                            Text("Target: $\(targetPrice, specifier: "%.2f")")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                Spacer()
                
                // Price Tracking Toggle
                Toggle("", isOn: Binding(
                    get: { item.isTracking },
                    set: { viewModel.toggleTracking(for: item, isTracking: $0) }
                ))
                .labelsHidden()
                .toggleStyle(SwitchToggleStyle(tint: .blue))
                .scaleEffect(0.8)
            }
            
            // Current Best Price
            if item.isTracking, let currentPrice = item.product.currentLowestPrice {
                HStack {
                    Image(systemName: "tag.fill")
                        .foregroundColor(.green)
                        .font(.caption)
                    
                    Text("Best: $\(currentPrice.totalPrice, specifier: "%.2f") at \(currentPrice.retailer.name)")
                        .font(.caption)
                        .foregroundColor(.green)
                    
                    if let targetPrice = item.targetPrice,
                       currentPrice.totalPrice <= targetPrice {
                        Text("TARGET MET!")
                            .font(.caption2)
                            .fontWeight(.bold)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.green.opacity(0.2))
                            .foregroundColor(.green)
                            .cornerRadius(4)
                    }
                }
            }
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .onTapGesture {
            showingDetail = true
        }
        .sheet(isPresented: $showingDetail) {
            ItemDetailView(item: item)
        }
    }
    
    private var priorityColor: Color {
        switch item.priority {
        case .urgent: return .red
        case .high: return .orange
        case .medium: return .yellow
        case .low: return .green
        }
    }
}

// MARK: - Add Item View
struct AddItemView: View {
    @ObservedObject var viewModel: ShoppingListViewModel
    @Environment(\.dismiss) var dismiss
    
    @State private var productName = ""
    @State private var category: Product.ProductCategory = .other
    @State private var quantity = 1
    @State private var priority: ShoppingListItem.Priority = .medium
    @State private var targetPrice = ""
    @State private var notes = ""
    @State private var enableTracking = true
    
    var body: some View {
        NavigationView {
            Form {
                Section("Product Information") {
                    TextField("Product Name", text: $productName)
                    
                    Picker("Category", selection: $category) {
                        ForEach(Product.ProductCategory.allCases, id: \.self) { cat in
                            Text(cat.rawValue).tag(cat)
                        }
                    }
                    
                    Stepper("Quantity: \(quantity)", value: $quantity, in: 1...99)
                }
                
                Section("Shopping Preferences") {
                    Picker("Priority", selection: $priority) {
                        ForEach(ShoppingListItem.Priority.allCases, id: \.self) { p in
                            Text(p.rawValue).tag(p)
                        }
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    
                    HStack {
                        Text("Target Price")
                        TextField("Optional", text: $targetPrice)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                    }
                    
                    Toggle("Enable Price Tracking", isOn: $enableTracking)
                }
                
                Section("Notes") {
                    TextEditor(text: $notes)
                        .frame(height: 80)
                }
            }
            .navigationTitle("Add Item")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Add") {
                        viewModel.addItem(
                            name: productName,
                            category: category,
                            quantity: quantity,
                            priority: priority,
                            targetPrice: Double(targetPrice),
                            notes: notes.isEmpty ? nil : notes,
                            enableTracking: enableTracking
                        )
                        dismiss()
                    }
                    .disabled(productName.isEmpty)
                }
            }
        }
    }
}

// MARK: - Item Detail View
struct ItemDetailView: View {
    let item: ShoppingListItem
    @Environment(\.dismiss) var dismiss
    @StateObject private var priceHistory = PriceHistoryViewModel()
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Product Info
                    VStack(alignment: .leading, spacing: 8) {
                        Text(item.product.name)
                            .font(.title2)
                            .fontWeight(.bold)
                        
                        HStack {
                            Label(item.product.category.rawValue, systemImage: "tag")
                            Spacer()
                            Label("Qty: \(item.quantity)", systemImage: "number")
                        }
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    }
                    .padding(.horizontal)
                    
                    // Current Prices Across Retailers
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Current Prices")
                            .font(.headline)
                            .padding(.horizontal)
                        
                        ForEach(priceHistory.currentPrices) { pricePoint in
                            HStack {
                                Text(pricePoint.retailer.name)
                                    .font(.subheadline)
                                
                                Spacer()
                                
                                VStack(alignment: .trailing) {
                                    Text("$\(pricePoint.totalPrice, specifier: "%.2f")")
                                        .font(.subheadline)
                                        .fontWeight(.semibold)
                                    
                                    if let shippingCost = pricePoint.shippingCost, shippingCost > 0 {
                                        Text("+ $\(shippingCost, specifier: "%.2f") shipping")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                }
                                
                                Button(action: {
                                    // Open retailer link
                                    if let url = URL(string: pricePoint.url) {
                                        UIApplication.shared.open(url)
                                    }
                                }) {
                                    Image(systemName: "arrow.up.right.square")
                                        .foregroundColor(.blue)
                                }
                            }
                            .padding()
                            .background(Color(.systemGray6))
                            .cornerRadius(8)
                        }
                        .padding(.horizontal)
                    }
                    
                    // Price History Chart
                    if !priceHistory.historicalData.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Price History")
                                .font(.headline)
                                .padding(.horizontal)
                            
                            // Placeholder for chart
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color(.systemGray6))
                                .frame(height: 200)
                                .overlay(
                                    Text("Price chart will be displayed here")
                                        .foregroundColor(.gray)
                                )
                                .padding(.horizontal)
                        }
                    }
                    
                    // AI Insights
                    if let prediction = priceHistory.pricePrediction {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Image(systemName: "sparkles")
                                    .foregroundColor(.purple)
                                Text("AI Insights")
                                    .font(.headline)
                            }
                            .padding(.horizontal)
                            
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Trend: \(prediction.trend)")
                                Text("Best time to buy: \(prediction.optimalBuyDate, style: .date)")
                                Text("Expected price: $\(prediction.expectedPriceRange.min, specifier: "%.2f") - $\(prediction.expectedPriceRange.max, specifier: "%.2f")")
                                
                                HStack {
                                    Text("Confidence:")
                                    ProgressView(value: prediction.confidence)
                                        .progressViewStyle(LinearProgressViewStyle(tint: .blue))
                                    Text("\(Int(prediction.confidence * 100))%")
                                        .font(.caption)
                                }
                            }
                            .padding()
                            .background(Color(.systemGray6))
                            .cornerRadius(8)
                            .padding(.horizontal)
                        }
                    }
                }
                .padding(.vertical)
            }
            .navigationTitle("Item Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .onAppear {
            priceHistory.loadPriceHistory(for: item.product)
        }
    }
}

// MARK: - Supporting Views
struct EmptyShoppingListView: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "cart")
                .font(.system(size: 60))
                .foregroundColor(.gray)
            
            Text("Your shopping list is empty")
                .font(.headline)
                .foregroundColor(.gray)
            
            Text("Add items to start tracking prices and finding deals")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct ShoppingSummaryBar: View {
    let itemCount: Int
    let estimatedTotal: Double
    let potentialSavings: Double
    
    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text("\(itemCount) items")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text("~$\(estimatedTotal, specifier: "%.2f")")
                    .font(.subheadline)
                    .fontWeight(.semibold)
            }
            
            Spacer()
            
            if potentialSavings > 0 {
                VStack(alignment: .trailing) {
                    Text("Potential savings")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("$\(potentialSavings, specifier: "%.2f")")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.green)
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
    }
}

// MARK: - View Models
class ShoppingListViewModel: ObservableObject {
    @Published var items: [ShoppingListItem] = []
    @Published var filter: FilterOption = .all
    
    var estimatedTotal: Double {
        items.reduce(0) { total, item in
            let price = item.product.currentLowestPrice?.totalPrice ?? 0
            return total + (price * Double(item.quantity))
        }
    }
    
    var potentialSavings: Double {
        // Calculate based on historical averages vs current prices
        return items.reduce(0) { total, item in
            guard let current = item.product.currentLowestPrice?.totalPrice,
                  let average = item.product.averagePrice else { return total }
            let saving = max(0, (average - current) * Double(item.quantity))
            return total + saving
        }
    }
    
    enum FilterOption {
        case all
        case tracking
        case priority(ShoppingListItem.Priority)
    }
    
    func filteredItems(searchText: String) -> [ShoppingListItem] {
        var filtered = items
        
        // Apply filter
        switch filter {
        case .all:
            break
        case .tracking:
            filtered = filtered.filter { $0.isTracking }
        case .priority(let p):
            filtered = filtered.filter { $0.priority == p }
        }
        
        // Apply search
        if !searchText.isEmpty {
            filtered = filtered.filter {
                $0.product.name.localizedCaseInsensitiveContains(searchText)
            }
        }
        
        return filtered
    }
    
    func filterBy(_ option: FilterOption) {
        filter = option
    }
    
    func addItem(name: String, category: Product.ProductCategory, quantity: Int,
                 priority: ShoppingListItem.Priority, targetPrice: Double?,
                 notes: String?, enableTracking: Bool) {
        let product = Product(
            name: name,
            description: "",
            category: category,
            imageURL: nil,
            barcode: nil,
            brand: nil
        )
        
        let item = ShoppingListItem(
            product: product,
            targetPrice: targetPrice,
            quantity: quantity,
            priority: priority,
            notes: notes,
            addedDate: Date(),
            isTracking: enableTracking
        )
        
        items.append(item)
    }
    
    func toggleTracking(for item: ShoppingListItem, isTracking: Bool) {
        if let index = items.firstIndex(where: { $0.id == item.id }) {
            items[index].isTracking = isTracking
        }
    }
    
    func deleteItems(at offsets: IndexSet) {
        items.remove(atOffsets: offsets)
    }
}

class PriceHistoryViewModel: ObservableObject {
    @Published var currentPrices: [PricePoint] = []
    @Published var historicalData: [PricePoint] = []
    @Published var pricePrediction: PricePrediction?
    
    func loadPriceHistory(for product: Product) {
        // Simulate loading price data
        // In production, this would fetch from your backend
        
        let retailers = Retailer.allRetailers.prefix(3)
        currentPrices = retailers.map { retailer in
            PricePoint(
                retailer: retailer,
                price: Double.random(in: 50...200),
                timestamp: Date(),
                url: retailer.websiteURL,
                inStock: true,
                shippingCost: Bool.random() ? 0 : Double.random(in: 5...15)
            )
        }
        
        // Mock prediction
        pricePrediction = PricePrediction(
            trend: "Declining",
            optimalBuyDate: Date().addingTimeInterval(7 * 86400),
            expectedPriceRange: PricePrediction.PriceRange(min: 45, max: 65),
            confidence: 0.82
        )
    }
}
