import SwiftUI

struct InventoryView: View {
    @StateObject private var viewModel = InventoryViewModel()
    @State private var showingAddItem = false
    @State private var selectedCategory: Product.ProductCategory? = nil
    
    var body: some View {
        NavigationView {
            VStack {
                // Stats Overview
                InventoryStatsBar(
                    totalItems: viewModel.totalItems,
                    lowStockItems: viewModel.lowStockItems,
                    autoReorderEnabled: viewModel.autoReorderItems
                )
                
                // Category Filter
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        CategoryPill(
                            title: "All",
                            icon: "square.grid.2x2",
                            isSelected: selectedCategory == nil,
                            count: viewModel.inventory.count
                        ) {
                            selectedCategory = nil
                        }
                        
                        ForEach(Product.ProductCategory.allCases, id: \.self) { category in
                            let count = viewModel.itemCount(for: category)
                            if count > 0 {
                                CategoryPill(
                                    title: category.rawValue,
                                    icon: categoryIcon(for: category),
                                    isSelected: selectedCategory == category,
                                    count: count
                                ) {
                                    selectedCategory = category
                                }
                            }
                        }
                    }
                    .padding(.horizontal)
                }
                .padding(.vertical, 10)
                
                // Inventory List
                if viewModel.inventory.isEmpty {
                    EmptyInventoryView()
                } else {
                    List {
                        // Low Stock Section
                        if !viewModel.needsReorderItems.isEmpty && selectedCategory == nil {
                            Section {
                                ForEach(viewModel.needsReorderItems) { item in
                                    InventoryItemRow(item: item, viewModel: viewModel)
                                }
                            } header: {
                                HStack {
                                    Image(systemName: "exclamationmark.triangle.fill")
                                        .foregroundColor(.orange)
                                    Text("Low Stock")
                                        .foregroundColor(.orange)
                                }
                            }
                        }
                        
                        // Regular Items
                        Section {
                            ForEach(viewModel.filteredInventory(category: selectedCategory)) { item in
                                if !viewModel.needsReorderItems.contains(where: { $0.id == item.id }) {
                                    InventoryItemRow(item: item, viewModel: viewModel)
                                }
                            }
                            .onDelete(perform: viewModel.deleteItems)
                        } header: {
                            Text(selectedCategory?.rawValue ?? "All Items")
                        }
                    }
                    .listStyle(InsetGroupedListStyle())
                }
            }
            .navigationTitle("Inventory")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showingAddItem = true }) {
                        Image(systemName: "plus.circle.fill")
                            .foregroundColor(.blue)
                    }
                }
                
                ToolbarItem(placement: .navigationBarLeading) {
                    Menu {
                        Button(action: { viewModel.toggleAutoReorder() }) {
                            Label(
                                viewModel.globalAutoReorder ? "Disable Auto-Reorder" : "Enable Auto-Reorder",
                                systemImage: viewModel.globalAutoReorder ? "arrow.triangle.2.circlepath.circle.fill" : "arrow.triangle.2.circlepath.circle"
                            )
                        }
                        
                        Button(action: { viewModel.analyzeConsumption() }) {
                            Label("Analyze Consumption", systemImage: "chart.line.uptrend.xyaxis")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .foregroundColor(.blue)
                    }
                }
            }
            .sheet(isPresented: $showingAddItem) {
                AddInventoryItemView(viewModel: viewModel)
            }
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
        case .other: return "square.grid.2x2"
        }
    }
}

// MARK: - Inventory Stats Bar
struct InventoryStatsBar: View {
    let totalItems: Int
    let lowStockItems: Int
    let autoReorderEnabled: Int
    
    var body: some View {
        HStack(spacing: 0) {
            StatItem(
                title: "Total Items",
                value: "\(totalItems)",
                color: .blue,
                icon: "shippingbox"
            )
            
            Divider()
                .frame(height: 40)
            
            StatItem(
                title: "Low Stock",
                value: "\(lowStockItems)",
                color: .orange,
                icon: "exclamationmark.triangle"
            )
            
            Divider()
                .frame(height: 40)
            
            StatItem(
                title: "Auto-Reorder",
                value: "\(autoReorderEnabled)",
                color: .green,
                icon: "arrow.triangle.2.circlepath"
            )
        }
        .padding(.vertical, 8)
        .background(Color(.systemGray6))
    }
}

struct StatItem: View {
    let title: String
    let value: String
    let color: Color
    let icon: String
    
    var body: some View {
        VStack(spacing: 4) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.caption)
                    .foregroundColor(color)
                Text(value)
                    .font(.headline)
                    .foregroundColor(color)
            }
            Text(title)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Category Pill
struct CategoryPill: View {
    let title: String
    let icon: String
    let isSelected: Bool
    let count: Int
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.caption)
                Text(title)
                    .font(.caption)
                Text("(\(count))")
                    .font(.caption2)
            }
            .fontWeight(isSelected ? .semibold : .regular)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(isSelected ? Color.blue : Color(.systemGray6))
            .foregroundColor(isSelected ? .white : .primary)
            .cornerRadius(15)
        }
    }
}

// MARK: - Inventory Item Row
struct InventoryItemRow: View {
    let item: InventoryItem
    @ObservedObject var viewModel: InventoryViewModel
    @State private var showingDetail = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(item.product.name)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    
                    HStack(spacing: 12) {
                        // Quantity Status
                        HStack(spacing: 4) {
                            Circle()
                                .fill(quantityStatusColor)
                                .frame(width: 6, height: 6)
                            Text("\(item.currentQuantity)/\(item.preferredQuantity)")
                                .font(.caption)
                                .foregroundColor(quantityStatusColor)
                        }
                        
                        // Category
                        Text(item.product.category.rawValue)
                            .font(.caption2)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color(.systemGray5))
                            .cornerRadius(4)
                    }
                }
                
                Spacer()
                
                // Auto-reorder Toggle
                VStack(alignment: .trailing, spacing: 4) {
                    Toggle("", isOn: Binding(
                        get: { item.autoReorder },
                        set: { viewModel.toggleAutoReorder(for: item, enabled: $0) }
                    ))
                    .labelsHidden()
                    .toggleStyle(SwitchToggleStyle(tint: .green))
                    .scaleEffect(0.8)
                    
                    Text("Auto")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            
            // Consumption Info
            if let avgDays = item.averageConsumptionDays,
               let runOutDate = item.estimatedRunOutDate {
                HStack {
                    Image(systemName: "clock")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    
                    Text("~\(avgDays) days supply • Runs out \(runOutDate, style: .relative)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    if item.needsReorder {
                        Text("REORDER NOW")
                            .font(.caption2)
                            .fontWeight(.bold)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.orange.opacity(0.2))
                            .foregroundColor(.orange)
                            .cornerRadius(4)
                    }
                }
            }
            
            // Quick Actions
            if item.needsReorder {
                HStack(spacing: 12) {
                    Button(action: { viewModel.reorderItem(item) }) {
                        Label("Reorder Now", systemImage: "cart.fill.badge.plus")
                            .font(.caption)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                    
                    Button(action: { viewModel.updateQuantity(for: item, change: 1) }) {
                        Label("Mark Restocked", systemImage: "checkmark.circle")
                            .font(.caption)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
                .padding(.top, 4)
            }
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .onTapGesture {
            showingDetail = true
        }
        .sheet(isPresented: $showingDetail) {
            InventoryDetailView(item: item, viewModel: viewModel)
        }
    }
    
    private var quantityStatusColor: Color {
        let ratio = Double(item.currentQuantity) / Double(item.preferredQuantity)
        if ratio <= 0.25 {
            return .red
        } else if ratio <= 0.5 {
            return .orange
        } else {
            return .green
        }
    }
}

// MARK: - Add Inventory Item View
struct AddInventoryItemView: View {
    @ObservedObject var viewModel: InventoryViewModel
    @Environment(\.dismiss) var dismiss
    
    @State private var productName = ""
    @State private var category: Product.ProductCategory = .other
    @State private var currentQuantity = 1
    @State private var preferredQuantity = 5
    @State private var reorderThreshold = 2
    @State private var enableAutoReorder = false
    
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
                }
                
                Section("Quantity Management") {
                    Stepper("Current Quantity: \(currentQuantity)", value: $currentQuantity, in: 0...99)
                    Stepper("Preferred Quantity: \(preferredQuantity)", value: $preferredQuantity, in: 1...99)
                    Stepper("Reorder at: \(reorderThreshold) or less", value: $reorderThreshold, in: 0...preferredQuantity-1)
                }
                
                Section("Auto-Reorder") {
                    Toggle("Enable Auto-Reorder", isOn: $enableAutoReorder)
                    
                    if enableAutoReorder {
                        Text("ShopSense will automatically add this item to your shopping list when quantity falls below the reorder threshold.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .navigationTitle("Add Inventory Item")
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
                            currentQuantity: currentQuantity,
                            preferredQuantity: preferredQuantity,
                            reorderThreshold: reorderThreshold,
                            autoReorder: enableAutoReorder
                        )
                        dismiss()
                    }
                    .disabled(productName.isEmpty)
                }
            }
        }
    }
}

// MARK: - Inventory Detail View
struct InventoryDetailView: View {
    let item: InventoryItem
    @ObservedObject var viewModel: InventoryViewModel
    @Environment(\.dismiss) var dismiss
    @State private var currentQuantity: Int
    @State private var showingEditSheet = false
    
    init(item: InventoryItem, viewModel: InventoryViewModel) {
        self.item = item
        self.viewModel = viewModel
        self._currentQuantity = State(initialValue: item.currentQuantity)
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Quantity Control
                    VStack(spacing: 16) {
                        Text("Current Quantity")
                            .font(.headline)
                        
                        HStack(spacing: 20) {
                            Button(action: {
                                if currentQuantity > 0 {
                                    currentQuantity -= 1
                                    viewModel.updateQuantity(for: item, newQuantity: currentQuantity)
                                }
                            }) {
                                Image(systemName: "minus.circle.fill")
                                    .font(.title)
                                    .foregroundColor(currentQuantity > 0 ? .red : .gray)
                            }
                            .disabled(currentQuantity == 0)
                            
                            Text("\(currentQuantity)")
                                .font(.system(size: 48, weight: .bold))
                                .frame(minWidth: 80)
                            
                            Button(action: {
                                currentQuantity += 1
                                viewModel.updateQuantity(for: item, newQuantity: currentQuantity)
                            }) {
                                Image(systemName: "plus.circle.fill")
                                    .font(.title)
                                    .foregroundColor(.green)
                            }
                        }
                        
                        // Visual Indicator
                        GeometryReader { geometry in
                            ZStack(alignment: .leading) {
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color(.systemGray5))
                                    .frame(height: 12)
                                
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(quantityColor)
                                    .frame(
                                        width: geometry.size.width * (Double(currentQuantity) / Double(item.preferredQuantity)),
                                        height: 12
                                    )
                            }
                        }
                        .frame(height: 12)
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                    
                    // Info Cards
                    VStack(spacing: 12) {
                        InfoCard(
                            title: "Preferred Quantity",
                            value: "\(item.preferredQuantity)",
                            icon: "star",
                            color: .blue
                        )
                        
                        InfoCard(
                            title: "Reorder Threshold",
                            value: "\(item.reorderThreshold)",
                            icon: "arrow.triangle.2.circlepath",
                            color: .orange
                        )
                        
                        if let avgDays = item.averageConsumptionDays {
                            InfoCard(
                                title: "Average Consumption",
                                value: "\(avgDays) days",
                                icon: "chart.line.uptrend.xyaxis",
                                color: .purple
                            )
                        }
                        
                        if let lastPurchase = item.lastPurchaseDate {
                            InfoCard(
                                title: "Last Purchased",
                                value: lastPurchase.formatted(date: .abbreviated, time: .omitted),
                                icon: "calendar",
                                color: .green
                            )
                        }
                    }
                    
                    // Purchase History
                    if !viewModel.getPurchaseHistory(for: item).isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Purchase History")
                                .font(.headline)
                            
                            ForEach(viewModel.getPurchaseHistory(for: item).prefix(5)) { purchase in
                                HStack {
                                    VStack(alignment: .leading) {
                                        Text(purchase.retailer.name)
                                            .font(.subheadline)
                                        Text(purchase.purchaseDate, style: .date)
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                    
                                    Spacer()
                                    
                                    VStack(alignment: .trailing) {
                                        Text("$\(purchase.price, specifier: "%.2f")")
                                            .font(.subheadline)
                                            .fontWeight(.semibold)
                                        Text("Qty: \(purchase.quantity)")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                }
                                .padding()
                                .background(Color(.systemGray6))
                                .cornerRadius(8)
                            }
                        }
                    }
                }
                .padding()
            }
            .navigationTitle(item.product.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button(action: { showingEditSheet = true }) {
                            Label("Edit Item", systemImage: "pencil")
                        }
                        
                        Button(role: .destructive, action: {
                            viewModel.deleteItem(item)
                            dismiss()
                        }) {
                            Label("Delete Item", systemImage: "trash")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
                
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
    
    private var quantityColor: Color {
        let ratio = Double(currentQuantity) / Double(item.preferredQuantity)
        if ratio <= 0.25 {
            return .red
        } else if ratio <= 0.5 {
            return .orange
        } else {
            return .green
        }
    }
}

// MARK: - Info Card
struct InfoCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(color)
                .frame(width: 30)
            
            Text(title)
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            Spacer()
            
            Text(value)
                .font(.subheadline)
                .fontWeight(.semibold)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }
}

// MARK: - Empty Inventory View
struct EmptyInventoryView: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "shippingbox")
                .font(.system(size: 60))
                .foregroundColor(.gray)
            
            Text("No items in inventory")
                .font(.headline)
                .foregroundColor(.gray)
            
            Text("Add household items to track quantities and automate reordering")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - View Model
class InventoryViewModel: ObservableObject {
    @Published var inventory: [InventoryItem] = []
    @Published var globalAutoReorder = true
    
    var totalItems: Int {
        inventory.reduce(0) { $0 + $1.currentQuantity }
    }
    
    var lowStockItems: Int {
        inventory.filter { $0.needsReorder }.count
    }
    
    var autoReorderItems: Int {
        inventory.filter { $0.autoReorder }.count
    }
    
    var needsReorderItems: [InventoryItem] {
        inventory.filter { $0.needsReorder }
    }
    
    func itemCount(for category: Product.ProductCategory) -> Int {
        inventory.filter { $0.product.category == category }.count
    }
    
    func filteredInventory(category: Product.ProductCategory?) -> [InventoryItem] {
        guard let category = category else { return inventory }
        return inventory.filter { $0.product.category == category }
    }
    
    func addItem(name: String, category: Product.ProductCategory,
                 currentQuantity: Int, preferredQuantity: Int,
                 reorderThreshold: Int, autoReorder: Bool) {
        let product = Product(
            name: name,
            description: "",
            category: category,
            imageURL: nil,
            barcode: nil,
            brand: nil
        )
        
        let item = InventoryItem(
            product: product,
            currentQuantity: currentQuantity,
            preferredQuantity: preferredQuantity,
            lastPurchaseDate: nil,
            averageConsumptionDays: nil,
            autoReorder: autoReorder,
            reorderThreshold: reorderThreshold
        )
        
        inventory.append(item)
    }
    
    func updateQuantity(for item: InventoryItem, newQuantity: Int) {
        if let index = inventory.firstIndex(where: { $0.id == item.id }) {
            inventory[index].currentQuantity = newQuantity
        }
    }
    
    func updateQuantity(for item: InventoryItem, change: Int) {
        if let index = inventory.firstIndex(where: { $0.id == item.id }) {
            inventory[index].currentQuantity += change
        }
    }
    
    func toggleAutoReorder(for item: InventoryItem, enabled: Bool) {
        if let index = inventory.firstIndex(where: { $0.id == item.id }) {
            inventory[index].autoReorder = enabled
        }
    }
    
    func toggleAutoReorder() {
        globalAutoReorder.toggle()
        // Apply to all items
        for index in inventory.indices {
            inventory[index].autoReorder = globalAutoReorder
        }
    }
    
    func reorderItem(_ item: InventoryItem) {
        // Add to shopping list
        print("Adding \(item.product.name) to shopping list")
    }
    
    func deleteItem(_ item: InventoryItem) {
        inventory.removeAll { $0.id == item.id }
    }
    
    func deleteItems(at offsets: IndexSet) {
        inventory.remove(atOffsets: offsets)
    }
    
    func analyzeConsumption() {
        // Call Claude API to analyze consumption patterns
    }
    
    func getPurchaseHistory(for item: InventoryItem) -> [Purchase] {
        // Mock data - in production, fetch from database
        return []
    }
}
