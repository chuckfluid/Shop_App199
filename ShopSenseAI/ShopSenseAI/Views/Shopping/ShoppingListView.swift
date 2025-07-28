import SwiftUI
import Foundation

// MARK: - Enhanced Shopping List View
struct ShoppingListView: View {
    @StateObject private var viewModel = ShoppingListViewModel()
    @EnvironmentObject var authManager: AuthenticationManager
    @EnvironmentObject var priceTrackingService: PriceTrackingService
    @EnvironmentObject var notificationService: NotificationService
    
    @State private var showingAddItem = false
    @State private var searchText = ""
    @State private var selectedCategory: Product.ProductCategory? = nil
    @State private var showingFilters = false
    @State private var showingBatchActions = false
    @State private var selectedItems = Set<UUID>()
    @State private var isSelectionMode = false
    @State private var showingAIOptimization = false
    
    var body: some View {
        VStack {
            // Enhanced Search and Filter Bar
            VStack(spacing: 12) {
                HStack {
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.gray)
                        TextField("Search items...", text: $searchText)
                        
                        if !searchText.isEmpty {
                            Button(action: { searchText = "" }) {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.gray)
                            }
                        }
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
                
                // Category Filter Pills
                if !viewModel.items.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 10) {
                            CategoryFilterPill(
                                title: "All",
                                isSelected: selectedCategory == nil,
                                count: viewModel.items.count
                            ) {
                                selectedCategory = nil
                            }
                            
                            ForEach(viewModel.availableCategories, id: \.self) { category in
                                CategoryFilterPill(
                                    title: category.rawValue,
                                    isSelected: selectedCategory == category,
                                    count: viewModel.itemCount(for: category)
                                ) {
                                    selectedCategory = category
                                }
                            }
                        }
                    }
                }
            }
            .padding(.horizontal)
            
            // Smart Suggestions Banner (Premium)
            if authManager.subscriptionTier == .premium && viewModel.hasSmartSuggestions {
                SmartSuggestionsBar(
                    suggestionCount: viewModel.smartSuggestions.count,
                    potentialSavings: viewModel.totalPotentialSavings
                ) {
                    showingAIOptimization = true
                }
                .padding(.horizontal)
            }
            
            // Shopping List
            if viewModel.items.isEmpty {
                EmptyShoppingListView(onAddItem: { showingAddItem = true })
            } else {
                List(selection: $selectedItems) {
                    // Urgent Items Section
                    if !viewModel.urgentItems.isEmpty && selectedCategory == nil {
                        Section {
                            ForEach(viewModel.urgentItems) { item in
                                EnhancedShoppingListItemRow(
                                    item: item,
                                    viewModel: viewModel,
                                    isSelected: selectedItems.contains(item.id),
                                    isSelectionMode: isSelectionMode
                                )
                                .listRowBackground(Color.red.opacity(0.1))
                            }
                        } header: {
                            HStack {
                                Image(systemName: "exclamationmark.circle.fill")
                                    .foregroundColor(.red)
                                Text("Urgent Items")
                                    .foregroundColor(.red)
                            }
                        }
                    }
                    
                    // Regular Items
                    ForEach(viewModel.filteredItems(searchText: searchText, category: selectedCategory)) { item in
                        if !viewModel.urgentItems.contains(where: { $0.id == item.id }) {
                            EnhancedShoppingListItemRow(
                                item: item,
                                viewModel: viewModel,
                                isSelected: selectedItems.contains(item.id),
                                isSelectionMode: isSelectionMode
                            )
                        }
                    }
                    .onDelete(perform: viewModel.deleteItems)
                }
                .listStyle(PlainListStyle())
                .environment(\.editMode, .constant(isSelectionMode ? .active : .inactive))
            }
            
            // Enhanced Summary Bar
            if !viewModel.items.isEmpty {
                EnhancedShoppingSummaryBar(
                    itemCount: viewModel.items.count,
                    estimatedTotal: viewModel.estimatedTotal,
                    potentialSavings: viewModel.potentialSavings,
                    trackingCount: viewModel.trackingItemsCount,
                    showBatchActions: isSelectionMode
                ) {
                    if isSelectionMode {
                        showingBatchActions = true
                    }
                }
            }
        }
        .navigationTitle("Shopping List")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                HStack {
                    if !viewModel.items.isEmpty {
                        Button(action: {
                            isSelectionMode.toggle()
                            if !isSelectionMode {
                                selectedItems.removeAll()
                            }
                        }) {
                            Text(isSelectionMode ? "Done" : "Select")
                        }
                    }
                    
                    Button(action: { showingAddItem = true }) {
                        Image(systemName: "plus.circle.fill")
                            .foregroundColor(.blue)
                    }
                }
            }
            
            ToolbarItem(placement: .navigationBarLeading) {
                if !viewModel.items.isEmpty && !isSelectionMode {
                    Menu {
                        Button(action: { viewModel.sortBy(.priority) }) {
                            Label("Sort by Priority", systemImage: "flag")
                        }
                        Button(action: { viewModel.sortBy(.alphabetical) }) {
                            Label("Sort Alphabetically", systemImage: "a.square")
                        }
                        Button(action: { viewModel.sortBy(.category) }) {
                            Label("Sort by Category", systemImage: "square.grid.2x2")
                        }
                        Button(action: { viewModel.sortBy(.dateAdded) }) {
                            Label("Sort by Date Added", systemImage: "calendar")
                        }
                        
                        if authManager.subscriptionTier == .premium {
                            Divider()
                            Button(action: { showingAIOptimization = true }) {
                                Label("Optimize with AI", systemImage: "wand.and.stars")
                            }
                        }
                    } label: {
                        Image(systemName: "arrow.up.arrow.down.circle")
                            .foregroundColor(.blue)
                    }
                }
            }
        }
        .sheet(isPresented: $showingAddItem) {
            EnhancedAddItemView(viewModel: viewModel)
        }
        .sheet(isPresented: $showingBatchActions) {
            BatchActionsView(
                selectedItems: Array(selectedItems),
                viewModel: viewModel,
                onComplete: {
                    isSelectionMode = false
                    selectedItems.removeAll()
                }
            )
        }
        .sheet(isPresented: $showingAIOptimization) {
            AIShoppingOptimizationView(viewModel: viewModel)
        }
    }
}

// MARK: - Enhanced Shopping List Item Row
struct EnhancedShoppingListItemRow: View {
    let item: ShoppingListItem
    @ObservedObject var viewModel: ShoppingListViewModel
    let isSelected: Bool
    let isSelectionMode: Bool
    
    @State private var showingDetail = false
    @State private var isPriceCheckLoading = false
    @State private var currentBestPrice: PricePoint?
        
        var body: some View {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    // Selection Indicator
                    if isSelectionMode {
                        Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                            .foregroundColor(isSelected ? .blue : .gray)
                            .font(.title3)
                    }
                    
                    // Item Info
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(item.product.name)
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .strikethrough(item.isPurchased)
                                .foregroundColor(item.isPurchased ? .secondary : .primary)
                            
                            if item.priority == .urgent {
                                Image(systemName: "exclamationmark.circle.fill")
                                    .font(.caption)
                                    .foregroundColor(.red)
                            }
                        }
                        
                        HStack(spacing: 12) {
                            // Quantity Badge
                            HStack(spacing: 4) {
                                Image(systemName: "number")
                                    .font(.caption2)
                                Text("Qty: \(item.quantity)")
                                    .font(.caption)
                            }
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color(.systemGray5))
                            .cornerRadius(4)
                            
                            // Category
                            CategoryBadge(category: item.product.category)
                            
                            // Tracking Status
                            if item.isTracking {
                                HStack(spacing: 2) {
                                    Image(systemName: "chart.line.uptrend.xyaxis")
                                        .font(.caption2)
                                    Text("Tracking")
                                        .font(.caption2)
                                }
                                .foregroundColor(.blue)
                            }
                        }
                        
                        // Price Info
                        if let bestPrice = currentBestPrice ?? item.product.currentLowestPrice {
                            HStack {
                                Text("$\(bestPrice.totalPrice, specifier: "%.2f")")
                                    .font(.caption)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.green)
                                
                                Text("at \(bestPrice.retailer.name)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                
                                if isPriceCheckLoading {
                                    ProgressView()
                                        .scaleEffect(0.7)
                                }
                            }
                        }
                    }
                    
                    Spacer()
                    
                    // Quick Actions
                    if !isSelectionMode {
                        HStack(spacing: 12) {
                            // Toggle Purchased
                            Button(action: {
                                withAnimation {
                                    viewModel.togglePurchased(item)
                                }
                            }) {
                                Image(systemName: item.isPurchased ? "checkmark.circle.fill" : "circle")
                                    .foregroundColor(item.isPurchased ? .green : .gray)
                                    .font(.title3)
                            }
                            
                            // Price Check
                            Button(action: { checkPrice() }) {
                                Image(systemName: "tag.circle")
                                    .foregroundColor(.blue)
                                    .font(.title3)
                            }
                        }
                    }
                }
                
                // Notes
                if let notes = item.notes, !notes.isEmpty {
                    Text(notes)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
                
                // Smart Suggestion (Premium)
                if AuthenticationManager.shared.subscriptionTier == .premium,
                   let suggestion = viewModel.getSuggestion(for: item) {
                    SmartSuggestionBanner(suggestion: suggestion)
                }
            }
            .padding(.vertical, 4)
            .contentShape(Rectangle())
            .onTapGesture {
                if isSelectionMode {
                    viewModel.toggleSelection(item.id, in: &selectedItems)
                } else {
                    showingDetail = true
                }
            }
            .sheet(isPresented: $showingDetail) {
                EnhancedItemDetailView(item: item, viewModel: viewModel)
            }
            .onAppear {
                loadBestPrice()
            }
        }
        
        private func checkPrice() {
            isPriceCheckLoading = true
            
            Task {
                // Simulate price check
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                
                await MainActor.run {
                    // Update with fresh price
                    loadBestPrice()
                    isPriceCheckLoading = false
                }
            }
        }
        
        private func loadBestPrice() {
            // In production, fetch real price data
            if let lowestPrice = item.product.currentLowestPrice {
                currentBestPrice = lowestPrice
            }
        }
    }

    // MARK: - Smart Suggestion Banner
    struct SmartSuggestionBanner: View {
        let suggestion: SmartSuggestion
        
        var body: some View {
            HStack(spacing: 8) {
                Image(systemName: "sparkles")
                    .font(.caption)
                    .foregroundColor(.purple)
                
                Text(suggestion.message)
                    .font(.caption)
                    .foregroundColor(.purple)
                
                if let savings = suggestion.potentialSavings {
                    Text("Save $\(savings, specifier: "%.2f")")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.green)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color.purple.opacity(0.1))
            .cornerRadius(6)
        }
    }

    // MARK: - Enhanced Add Item View
    struct EnhancedAddItemView: View {
        @ObservedObject var viewModel: ShoppingListViewModel
        @Environment(\.dismiss) var dismiss
        @EnvironmentObject var authManager: AuthenticationManager
        
        @State private var productName = ""
        @State private var category: Product.ProductCategory = .other
        @State private var quantity = 1
        @State private var priority: ShoppingListItem.Priority = .normal
        @State private var notes = ""
        @State private var enablePriceTracking = true
        @State private var targetPrice: String = ""
        @State private var barcode = ""
        @State private var isScanning = false
        @State private var productSuggestions: [Product] = []
        @State private var showingAISuggestions = false
        
        var body: some View {
            NavigationView {
                Form {
                    Section("Product Information") {
                        HStack {
                            TextField("Product Name", text: $productName)
                                .onChange(of: productName) { _ in
                                    searchProducts()
                                }
                            
                            Button(action: { isScanning = true }) {
                                Image(systemName: "barcode.viewfinder")
                                    .foregroundColor(.blue)
                            }
                        }
                        
                        if !productSuggestions.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Suggestions")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                
                                ForEach(productSuggestions.prefix(3)) { suggestion in
                                    Button(action: { selectProduct(suggestion) }) {
                                        HStack {
                                            Text(suggestion.name)
                                                .font(.subheadline)
                                                .foregroundColor(.primary)
                                            Spacer()
                                            Text(suggestion.category.rawValue)
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                        }
                                    }
                                }
                            }
                        }
                        
                        Picker("Category", selection: $category) {
                            ForEach(Product.ProductCategory.allCases, id: \.self) { cat in
                                Text(cat.rawValue).tag(cat)
                            }
                        }
                    }
                    
                    Section("Shopping Details") {
                        Stepper("Quantity: \(quantity)", value: $quantity, in: 1...99)
                        
                        Picker("Priority", selection: $priority) {
                            ForEach(ShoppingListItem.Priority.allCases, id: \.self) { pri in
                                Text(pri.rawValue).tag(pri)
                            }
                        }
                        
                        TextField("Notes (optional)", text: $notes, axis: .vertical)
                            .lineLimit(2...4)
                    }
                    
                    Section("Price Tracking") {
                        Toggle("Enable Price Tracking", isOn: $enablePriceTracking)
                        
                        if enablePriceTracking {
                            HStack {
                                Text("Target Price")
                                TextField("Optional", text: $targetPrice)
                                    .keyboardType(.decimalPad)
                                    .multilineTextAlignment(.trailing)
                            }
                            
                            Text("Get notified when the price drops to your target")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    if authManager.subscriptionTier == .premium {
                        Section("AI Assistance") {
                            Button(action: { showingAISuggestions = true }) {
                                HStack {
                                    Image(systemName: "sparkles")
                                        .foregroundColor(.purple)
                                    Text("Get AI Suggestions")
                                }
                            }
                        }
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
                            addItem()
                            dismiss()
                        }
                        .disabled(productName.isEmpty)
                    }
                }
                .sheet(isPresented: $isScanning) {
                    BarcodeScannerView(scannedCode: $barcode)
                        .onDisappear {
                            if !barcode.isEmpty {
                                lookupProduct(barcode: barcode)
                            }
                        }
                }
                .sheet(isPresented: $showingAISuggestions) {
                    AIProductSuggestionsView(
                        productName: productName,
                        category: category,
                        onSelect: { suggestion in
                            productName = suggestion.name
                            if let target = suggestion.targetPrice {
                                targetPrice = String(format: "%.2f", target)
                            }
                        }
                    )
                }
            }
        }
        
        private func searchProducts() {
            guard productName.count >= 3 else {
                productSuggestions = []
                return
            }
            
            // Mock product search
            productSuggestions = [
                Product(name: "\(productName) - Brand A", description: "", category: category, imageURL: nil, barcode: nil, brand: "Brand A"),
                Product(name: "\(productName) - Generic", description: "", category: category, imageURL: nil, barcode: nil, brand: nil),
                Product(name: "\(productName) - Premium", description: "", category: category, imageURL: nil, barcode: nil, brand: "Premium Brand")
            ]
        }
        
        private func selectProduct(_ product: Product) {
            productName = product.name
            category = product.category
            productSuggestions = []
        }
        
        private func lookupProduct(barcode: String) {
            // Simulate barcode lookup
            productName = "Scanned Product"
            category = .groceries
        }
        
        private func addItem() {
            let targetPriceValue = Double(targetPrice)
            
            viewModel.addItem(
                name: productName,
                category: category,
                quantity: quantity,
                priority: priority,
                notes: notes.isEmpty ? nil : notes,
                enableTracking: enablePriceTracking,
                targetPrice: targetPriceValue
            )
        }
    }

    // MARK: - AI Product Suggestions View
    struct AIProductSuggestionsView: View {
        let productName: String
        let category: Product.ProductCategory
        let onSelect: (ProductSuggestion) -> Void
        
        @Environment(\.dismiss) var dismiss
        @State private var isLoading = true
        @State private var suggestions: [ProductSuggestion] = []
        
        struct ProductSuggestion: Identifiable {
            let id = UUID()
            let name: String
            let brand: String?
            let estimatedPrice: Double
            let targetPrice: Double?
            let reason: String
        }
        
        var body: some View {
            NavigationView {
                if isLoading {
                    VStack {
                        ProgressView()
                        Text("Analyzing shopping patterns...")
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List(suggestions) { suggestion in
                        Button(action: {
                            onSelect(suggestion)
                            dismiss()
                        }) {
                            VStack(alignment: .leading, spacing: 8) {
                                Text(suggestion.name)
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.primary)
                                
                                if let brand = suggestion.brand {
                                    Text(brand)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                
                                HStack {
                                    Text("Est. $\(suggestion.estimatedPrice, specifier: "%.2f")")
                                        .font(.caption)
                                    
                                    if let target = suggestion.targetPrice {
                                        Text("Target: $\(target, specifier: "%.2f")")
                                            .font(.caption)
                                            .foregroundColor(.green)
                                    }
                                }
                                
                                Text(suggestion.reason)
                                    .font(.caption)
                                    .foregroundColor(.blue)
                                    .italic()
                            }
                            .padding(.vertical, 4)
                        }
                    }
                    .navigationTitle("AI Suggestions")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .navigationBarTrailing) {
                            Button("Cancel") { dismiss() }
                        }
                    }
                }
            }
            .onAppear {
                loadSuggestions()
            }
        }
        
        private func loadSuggestions() {
            // Simulate AI analysis
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                suggestions = [
                    ProductSuggestion(
                        name: "\(productName) - Store Brand",
                        brand: "Great Value",
                        estimatedPrice: 12.99,
                        targetPrice: 10.99,
                        reason: "Best value based on your purchase history"
                    ),
                    ProductSuggestion(
                        name: "\(productName) - Premium",
                        brand: "Kirkland",
                        estimatedPrice: 18.99,
                        targetPrice: 15.99,
                        reason: "Higher quality, often on sale at Costco"
                    ),
                    ProductSuggestion(
                        name: "\(productName) - Organic",
                        brand: "365 Whole Foods",
                        estimatedPrice: 22.99,
                        targetPrice: 19.99,
                        reason: "Matches your preference for organic products"
                    )
                ]
                isLoading = false
            }
        }
    }

    // MARK: - Enhanced Item Detail View
    struct EnhancedItemDetailView: View {
        let item: ShoppingListItem
        @ObservedObject var viewModel: ShoppingListViewModel
        @Environment(\.dismiss) var dismiss
        @State private var isEditing = false
        @State private var editedQuantity: Int
        @State private var editedPriority: ShoppingListItem.Priority
        @State private var editedNotes: String
        @State private var priceHistory: [PricePoint] = []
        @State private var isLoadingPrices = true
        @State private var selectedTab = 0
        
        init(item: ShoppingListItem, viewModel: ShoppingListViewModel) {
            self.item = item
            self.viewModel = viewModel
            self._editedQuantity = State(initialValue: item.quantity)
            self._editedPriority = State(initialValue: item.priority)
            self._editedNotes = State(initialValue: item.notes ?? "")
        }
        
        var body: some View {
            NavigationView {
                ScrollView {
                    VStack(spacing: 20) {
                        // Product Header
                        ProductHeaderCard(product: item.product)
                        
                        // Tab Selection
                        Picker("View", selection: $selectedTab) {
                            Text("Details").tag(0)
                            Text("Price History").tag(1)
                            Text("Alternatives").tag(2)
                        }
                        .pickerStyle(SegmentedPickerStyle())
                        .padding(.horizontal)
                        
                        switch selectedTab {
                        case 0:
                            ItemDetailsTab(
                                item: item,
                                editedQuantity: $editedQuantity,
                                editedPriority: $editedPriority,
                                editedNotes: $editedNotes,
                                isEditing: $isEditing,
                                viewModel: viewModel
                            )
                        case 1:
                            PriceHistoryTab(
                                product: item.product,
                                priceHistory: $priceHistory,
                                isLoading: $isLoadingPrices
                            )
                        case 2:
                            AlternativesTab(
                                product: item.product,
                                viewModel: viewModel
                            )
                        default:
                            EmptyView()
                        }
                    }
                }
                .navigationTitle(item.product.name)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button("Done") { dismiss() }
                    }
                    
                    ToolbarItem(placement: .navigationBarTrailing) {
                        if isEditing {
                            Button("Save") {
                                saveChanges()
                                isEditing = false
                            }
                        } else {
                            Button("Edit") {
                                isEditing = true
                            }
                        }
                    }
                }
            }
            .onAppear {
                loadPriceHistory()
            }
        }
        
        private func saveChanges() {
            viewModel.updateItem(
                item,
                quantity: editedQuantity,
                priority: editedPriority,
                notes: editedNotes.isEmpty ? nil : editedNotes
            )
        }
        
        private func loadPriceHistory() {
            // Simulate loading price history
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                self.priceHistory = generateMockPriceHistory()
                self.isLoadingPrices = false
            }
        }
        
        private func generateMockPriceHistory() -> [PricePoint] {
            var history: [PricePoint] = []
            let retailers = Retailer.allRetailers.prefix(3)
            
            for days in stride(from: 0, to: 30, by: 3) {
                for retailer in retailers {
                    let basePrice = Double.random(in: 10...50)
                    let variation = Double.random(in: -5...5)
                    
                    history.append(PricePoint(
                        retailer: retailer,
                        price: basePrice + variation,
                        timestamp: Date().addingTimeInterval(-TimeInterval(days * 86400)),
                        url: retailer.websiteURL,
                        inStock: Bool.random(),
                        shippingCost: Bool.random() ? nil : Double.random(in: 3...10)
                    ))
                }
            }
            
            return history.sorted { $0.timestamp > $1.timestamp }
        }
    }

    // MARK: - Detail View Components
    struct ProductHeaderCard: View {
        let product: Product
        
        var body: some View {
            VStack(spacing: 12) {
                // Product Image Placeholder
                RoundedRectangle(cornerRadius: 12)
                    .fill(LinearGradient(
                        colors: [Color(product.category.color).opacity(0.3), .blue.opacity(0.3)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ))
                    .frame(height: 120)
                    .overlay(
                        VStack {
                            Image(systemName: product.category.icon)
                                .font(.system(size: 40))
                                .foregroundColor(.white)
                            Text(product.category.rawValue)
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.8))
                        }
                    )
                
                VStack(alignment: .leading, spacing: 4) {
                    if let brand = product.brand {
                        Text(brand)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    if let description = product.description, !description.isEmpty {
                        Text(description)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding()
            .background(Color(.systemBackground))
            .cornerRadius(12)
            .shadow(radius: 1)
            .padding(.horizontal)
        }
    }

    struct ItemDetailsTab: View {
        let item: ShoppingListItem
        @Binding var editedQuantity: Int
        @Binding var editedPriority: ShoppingListItem.Priority
        @Binding var editedNotes: String
        @Binding var isEditing: Bool
        @ObservedObject var viewModel: ShoppingListViewModel
        
        var body: some View {
            VStack(spacing: 16) {
                // Shopping Details
                VStack(alignment: .leading, spacing: 12) {
                    DetailRow(
                        title: "Quantity",
                        content: isEditing ? nil : "\(item.quantity)"
                    ) {
                        if isEditing {
                            Stepper("\(editedQuantity)", value: $editedQuantity, in: 1...99)
                        }
                    }
                    
                    DetailRow(
                        title: "Priority",
                        content: isEditing ? nil : item.priority.rawValue
                    ) {
                        if isEditing {
                            Picker("Priority", selection: $editedPriority) {
                                ForEach(ShoppingListItem.Priority.allCases, id: \.self) { priority in
                                    Text(priority.rawValue).tag(priority)
                                }
                            }
                            .pickerStyle(SegmentedPickerStyle())
                        }
                    }
                    
                    DetailRow(title: "Notes", content: nil) {
                        if isEditing {
                            TextField("Add notes...", text: $editedNotes, axis: .vertical)
                                .lineLimit(2...4)
                        } else {
                            Text(item.notes ?? "No notes")
                                .foregroundColor(item.notes == nil ? .secondary : .primary)
                        }
                    }
                    
                    DetailRow(
                        title: "Status",
                        content: item.isPurchased ? "Purchased" : "Pending"
                    ) {
                        Image(systemName: item.isPurchased ? "checkmark.circle.fill" : "circle")
                            .foregroundColor(item.isPurchased ? .green : .gray)
                    }
                    
                    DetailRow(
                        title: "Added",
                        content: item.dateAdded.formatted(date: .abbreviated, time: .omitted)
                    ) { }
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
                .padding(.horizontal)
                
                // Price Tracking Status
                if item.isTracking {
                    PriceTrackingCard(item: item, viewModel: viewModel)
                        .padding(.horizontal)
                }
                
                // Actions
                if !isEditing {
                    VStack(spacing: 12) {
                        Button(action: {
                            viewModel.togglePurchased(item)
                        }) {
                            Label(
                                item.isPurchased ? "Mark as Pending" : "Mark as Purchased",
                                systemImage: item.isPurchased ? "xmark.circle" : "checkmark.circle"
                            )
                            .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        
                        if !item.isTracking {
                            Button(action: {
                                viewModel.enableTracking(for: item)
                            }) {
                                Label("Enable Price Tracking", systemImage: "chart.line.uptrend.xyaxis")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.bordered)
                        }
                        
                        Button(action: {
                            // Find best price
                            viewModel.findBestPrice(for: item)
                        }) {
                            Label("Find Best Price", systemImage: "magnifyingglass")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                    }
                    .padding(.horizontal)
                }
            }
        }
    }

    struct DetailRow<Content: View>: View {
        let title: String
        let content: String?
        @ViewBuilder let customContent: () -> Content
        
        var body: some View {
            HStack {
                Text(title)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                if let content = content {
                    Text(content)
                        .font(.subheadline)
                } else {
                    customContent()
                        .font(.subheadline)
                }
            }
        }
    }

    struct PriceTrackingCard: View {
        let item: ShoppingListItem
        @ObservedObject var viewModel: ShoppingListViewModel
        
        var body: some View {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: "chart.line.uptrend.xyaxis")
                        .foregroundColor(.blue)
                    Text("Price Tracking Active")
                        .font(.headline)
                }
                
                if let targetPrice = item.targetPrice {
                    HStack {
                        Text("Target Price:")
                        Spacer()
                        Text("$\(targetPrice, specifier: "%.2f")")
                            .fontWeight(.semibold)
                            .foregroundColor(.green)
                    }
                    .font(.subheadline)
                }
                
                if let currentPrice = item.product.currentLowestPrice {
                    HStack {
                        Text("Current Best:")
                        Spacer()
                        VStack(alignment: .trailing) {
                            Text("$\(currentPrice.totalPrice, specifier: "%.2f")")
                                .fontWeight(.semibold)
                            Text(currentPrice.retailer.name)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .font(.subheadline)
                    
                    if let target = item.targetPrice {
                        let difference = currentPrice.totalPrice - target
                        if difference <= 0 {
                            HStack {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                                Text("Target price reached!")
                                    .font(.caption)
                                    .foregroundColor(.green)
                            }
                            .padding(.top, 4)
                        }
                    }
                }
            }
            .padding()
            .background(Color.blue.opacity(0.1))
            .cornerRadius(12)
        }
    }

    struct AlternativesTab: View {
        let product: Product
        @ObservedObject var viewModel: ShoppingListViewModel
        @State private var alternatives: [ProductAlternatives.Alternative] = []
        @State private var isLoading = true
        
        var body: some View {
            VStack(spacing: 16) {
                if isLoading {
                    ProgressView("Finding alternatives...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .padding()
                } else if alternatives.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 40))
                            .foregroundColor(.gray)
                        
                        Text("No alternatives found")
                            .font(.headline)
                            .foregroundColor(.gray)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding()
                } else {
                    ForEach(alternatives, id: \.name) { alternative in
                        AlternativeProductCard(
                            alternative: alternative,
                            onAdd: {
                                viewModel.addAlternativeToList(alternative, replacing: product)
                            }
                        )
                    }
                    .padding(.horizontal)
                }
            }
            .onAppear {
                loadAlternatives()
            }
        }
        
        private func loadAlternatives() {
            // Simulate loading alternatives
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                alternatives = [
                    ProductAlternatives.Alternative(
                        name: "Generic \(product.category.rawValue)",
                        estimatedPrice: 15.99,
                        reason: "Best value option"
                    ),
                    ProductAlternatives.Alternative(
                        name: "Store Brand \(product.name)",
                        estimatedPrice: 18.99,
                        reason: "Good quality at lower price"
                    ),
                    ProductAlternatives.Alternative(
                        name: "Premium \(product.category.rawValue)",
                        estimatedPrice: 28.99,
                        reason: "Higher quality, longer lasting"
                    )
                ]
                isLoading = false
            }
        }
    }

    struct AlternativeProductCard: View {
        let alternative: ProductAlternatives.Alternative
        let onAdd: () -> Void
        
        var body: some View {
            VStack(alignment: .leading, spacing: 8) {
                Text(alternative.name)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                
                HStack {
                    Text("Est. $\(alternative.estimatedPrice, specifier: "%.2f")")
                        .font(.subheadline)
                        .foregroundColor(.green)
                    
                    Spacer()
                    
                    Button("Add to List") {
                        onAdd()
                    }
                    .font(.caption)
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
                
                Text(alternative.reason)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(12)
        }
    }

    // MARK: - Supporting Components
    struct CategoryFilterPill: View {
        let title: String
        let isSelected: Bool
        let count: Int
        let action: () -> Void
        
        var body: some View {
            Button(action: action) {
                HStack(spacing: 4) {
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

    struct EmptyShoppingListView: View {
        let onAddItem: () -> Void
        
        var body: some View {
            VStack(spacing: 20) {
                Image(systemName: "cart")
                    .font(.system(size: 60))
                    .foregroundColor(.gray)
                
                Text("Your shopping list is empty")
                    .font(.headline)
                    .foregroundColor(.gray)
                
                Text("Add items to start saving money")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                Button(action: onAddItem) {
                    Label("Add First Item", systemImage: "plus.circle.fill")
                }
                .buttonStyle(.borderedProminent)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    struct SmartSuggestionsBar: View {
        let suggestionCount: Int
        let potentialSavings: Double
        let action: () -> Void
        
        var body: some View {
            HStack {
                Image(systemName: "sparkles")
                    .foregroundColor(.purple)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(suggestionCount) smart suggestions")
                        .font(.caption)
                        .fontWeight(.medium)
                    Text("Save up to $\(potentialSavings, specifier: "%.2f")")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Button("View") {
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

    struct EnhancedShoppingSummaryBar: View {
        let itemCount: Int
        let estimatedTotal: Double
        let potentialSavings: Double
        let trackingCount: Int
        let showBatchActions: Bool
        let action: () -> Void
        
        var body: some View {
            VStack(spacing: 0) {
                Divider()
                
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text("\(itemCount) items")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            if trackingCount > 0 {
                                Text("•")
                                    .foregroundColor(.secondary)
                                HStack(spacing: 2) {
                                    Image(systemName: "chart.line.uptrend.xyaxis")
                                        .font(.caption2)
                                    Text("\(trackingCount) tracking")
                                        .font(.caption)
                                }
                                .foregroundColor(.blue)
                            }
                        }
                        
                        HStack {
                            Text("Est. Total: $\(estimatedTotal, specifier: "%.2f")")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                            
                            if potentialSavings > 0 {
                                Text("Save $\(potentialSavings, specifier: "%.2f")")
                                    .font(.caption)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Color.green.opacity(0.2))
                                    .foregroundColor(.green)
                                    .cornerRadius(4)
                            }
                        }
                    }
                    
                    Spacer()
                    
                    if showBatchActions {
                        Button("Actions") {
                            action()
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                    } else {
                        NavigationLink(destination: ShoppingTripView(viewModel: viewModel)) {
                            Label("Shop", systemImage: "cart.fill")
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                    }
                }
                .padding()
            }
            .background(Color(.systemBackground))
        }
    }

    // MARK: - Batch Actions View
    struct BatchActionsView: View {
        let selectedItems: [UUID]
        @ObservedObject var viewModel: ShoppingListViewModel
        let onComplete: () -> Void
        @Environment(\.dismiss) var dismiss
        
        var body: some View {
            NavigationView {
                List {
                    Section("Quick Actions") {
                        Button(action: {
                            viewModel.markAsPurchased(items: selectedItems)
                            onComplete()
                            dismiss()
                        }) {
                            Label("Mark as Purchased", systemImage: "checkmark.circle")
                        }
                        
                        Button(action: {
                            viewModel.enableTracking(for: selectedItems)
                            onComplete()
                            dismiss()
                        }) {
                            Label("Enable Price Tracking", systemImage: "chart.line.uptrend.xyaxis")
                        }
                        
                        Button(action: {
                            viewModel.changePriority(for: selectedItems, to: .urgent)
                            onComplete()
                            dismiss()
                        }) {
                            Label("Mark as Urgent", systemImage: "exclamationmark.circle")
                        }
                    }
                    
                    Section("Organize") {
                        Menu {
                            ForEach(Product.ProductCategory.allCases, id: \.self) { category in
                                Button(category.rawValue) {
                                    viewModel.changeCategory(for: selectedItems, to: category)
                                    onComplete()
                                    dismiss()
                                }
                            }
                        } label: {
                            Label("Change Category", systemImage: "folder")
                        }
                        
                        Button(action: {
                            viewModel.deleteItems(ids: selectedItems)
                            onComplete()
                            dismiss()
                        }) {
                            Label("Delete Items", systemImage: "trash")
                                .foregroundColor(.red)
                        }
                    }
                }
                .navigationTitle("Batch Actions")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Cancel") { dismiss() }
                    }
                }
            }
        }
    }

    // MARK: - AI Shopping Optimization View
    struct AIShoppingOptimizationView: View {
        @ObservedObject var viewModel: ShoppingListViewModel
        @Environment(\.dismiss) var dismiss
        @State private var isAnalyzing = true
        @State private var optimization: ShoppingOptimization?
        
        struct ShoppingOptimization {
            let recommendations: [String]
            let suggestedOrder: [String]
            let estimatedSavings: Double
            let timingAdvice: String
            let bundleOpportunities: [BundleOpportunity]
            
            struct BundleOpportunity {
                let items: [String]
                let retailer: String
                let savings: Double
            }
        }
        
        var body: some View {
            NavigationView {
                if isAnalyzing {
                    VStack {
                        ProgressView()
                        Text("Analyzing your shopping list...")
                            .foregroundColor(.secondary)
                        Text("Finding the best deals and timing")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let optimization = optimization {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 20) {
                            // Summary Card
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Image(systemName: "sparkles")
                                        .foregroundColor(.purple)
                                    Text("AI Optimization Complete")
                                        .font(.headline)
                                }
                                
                                Text("Potential savings: $\(optimization.estimatedSavings, specifier: "%.2f")")
                                    .font(.subheadline)
                                    .foregroundColor(.green)
                            }
                            .padding()
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.purple.opacity(0.1))
                            .cornerRadius(12)
                            .padding(.horizontal)
                            
                            // Timing Advice
                            VStack(alignment: .leading, spacing: 8) {
                                Label("Best Time to Shop", systemImage: "clock")
                                    .font(.headline)
                                Text(optimization.timingAdvice)
                                    .font(.subheadline)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            .padding()
                            .background(Color(.systemGray6))
                            .cornerRadius(12)
                            .padding(.horizontal)
                            
                            // Recommendations
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Recommendations")
                                    .font(.headline)
                                    .padding(.horizontal)
                                
                                ForEach(optimization.recommendations, id: \.self) { recommendation in
                                    HStack(alignment: .top) {
                                        Circle()
                                            .fill(Color.purple)
                                            .frame(width: 6, height: 6)
                                            .padding(.top, 6)
                                        
                                        Text(recommendation)
                                            .font(.subheadline)
                                            .fixedSize(horizontal: false, vertical: true)
                                    }
                                    .padding(.horizontal)
                                }
                            }
                            
                            // Bundle Opportunities
                            if !optimization.bundleOpportunities.isEmpty {
                                VStack(alignment: .leading, spacing: 12) {
                                    Text("Bundle Deals")
                                        .font(.headline)
                                        .padding(.horizontal)
                                    
                                    ForEach(optimization.bundleOpportunities, id: \.retailer) { bundle in
                                        BundleOpportunityCard(bundle: bundle)
                                            .padding(.horizontal)
                                    }
                                }
                            }
                            
                            // Suggested Shopping Order
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Optimized Shopping Order")
                                    .font(.headline)
                                    .padding(.horizontal)
                                
                                ForEach(Array(optimization.suggestedOrder.enumerated()), id: \.offset) { index, item in
                                    HStack {
                                        Text("\(index + 1).")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                            .frame(width: 20)
                                        
                                        Text(item)
                                            .font(.subheadline)
                                        
                                        Spacer()
                                    }
                                    .padding(.horizontal)
                                }
                            }
                            .padding(.bottom)
                        }
                    }
                }
                .navigationTitle("AI Optimization")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Done") { dismiss() }
                    }
                }
            }
            .onAppear {
                performOptimization()
            }
        }
        
        private func performOptimization() {
            // Simulate AI optimization
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                optimization = ShoppingOptimization(
                    recommendations: [
                        "Buy produce items at Farmers Market on Saturday for 30% savings",
                        "Wait 3 days for electronics - price drop predicted",
                        "Bundle household items at Target for additional 15% off",
                        "Consider generic alternatives for 5 items to save $18.50"
                    ],
                    suggestedOrder: viewModel.items.map { $0.product.name },
                    estimatedSavings: 47.80,
                    timingAdvice: "Shop Saturday morning for best deals and freshest produce. Avoid Friday evenings when prices are highest.",
                    bundleOpportunities: [
                        ShoppingOptimization.BundleOpportunity(
                            items: ["Paper Towels", "Toilet Paper", "Tissues"],
                            retailer: "Costco",
                            savings: 12.50
                        ),
                        ShoppingOptimization.BundleOpportunity(
                            items: ["Shampoo", "Conditioner", "Body Wash"],
                            retailer: "CVS",
                            savings: 8.00
                        )
                    ]
                )
                isAnalyzing = false
            }
        }
    }

    struct BundleOpportunityCard: View {
        let bundle: AIShoppingOptimizationView.ShoppingOptimization.BundleOpportunity
        
        var body: some View {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(bundle.retailer)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    
                    Spacer()
                    
                    Text("Save $\(bundle.savings, specifier: "%.2f")")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.green.opacity(0.2))
                        .foregroundColor(.green)
                        .cornerRadius(6)
                }
                
                Text(bundle.items.joined(separator: ", "))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(8)
        }
    }

    // MARK: - Shopping Trip View
    struct ShoppingTripView: View {
        @ObservedObject var viewModel: ShoppingListViewModel
        @State private var activeRetailer: Retailer?
        @State private var checkedItems = Set<UUID>()
        
        var body: some View {
            VStack {
                // Retailer Selection
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(Retailer.allRetailers, id: \.id) { retailer in
                            RetailerChip(
                                retailer: retailer,
                                isSelected: activeRetailer?.id == retailer.id,
                                itemCount: viewModel.itemsAvailableAt(retailer).count
                            ) {
                                activeRetailer = retailer
                            }
                        }
                    }
                    .padding(.horizontal)
                }
                .padding(.vertical)
                
                // Shopping List for Selected Retailer
                if let retailer = activeRetailer {
                    List {
                        ForEach(viewModel.itemsAvailableAt(retailer)) { item in
                            ShoppingTripItemRow(
                                item: item,
                                isChecked: checkedItems.contains(item.id)
                            ) {
                                toggleItem(item.id)
                            }
                        }
                    }
                    .listStyle(PlainListStyle())
                } else {
                    VStack(spacing: 16) {
                        Image(systemName: "building.2")
                            .font(.system(size: 50))
                            .foregroundColor(.gray)
                        
                        Text("Select a retailer to start shopping")
                            .font(.headline)
                            .foregroundColor(.gray)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                
                // Progress Bar
                if activeRetailer != nil {
                    ShoppingProgressBar(
                        completed: checkedItems.count,
                        total: viewModel.itemsAvailableAt(activeRetailer!).count
                    )
                }
            }
            .navigationTitle("Shopping Trip")
            .navigationBarTitleDisplayMode(.inline)
        }
        
        private func toggleItem(_ id: UUID) {
            if checkedItems.contains(id) {
                checkedItems.remove(id)
            } else {
                checkedItems.insert(id)
            }
        }
    }

    struct RetailerChip: View {
        let retailer: Retailer
        let isSelected: Bool
        let itemCount: Int
        let action: () -> Void
        
        var body: some View {
            Button(action: action) {
                VStack(spacing: 4) {
                    Text(retailer.name)
                        .font(.subheadline)
                        .fontWeight(isSelected ? .semibold : .regular)
                    
                    Text("\(itemCount) items")
                        .font(.caption)
                        .foregroundColor(isSelected ? .white.opacity(0.8) : .secondary)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(isSelected ? Color.blue : Color(.systemGray6))
                .foregroundColor(isSelected ? .white : .primary)
                .cornerRadius(20)
            }
        }
    }

    struct ShoppingTripItemRow: View {
        let item: ShoppingListItem
        let isChecked: Bool
        let action: () -> Void
        
        var body: some View {
            Button(action: action) {
                HStack {
                    Image(systemName: isChecked ? "checkmark.circle.fill" : "circle")
                        .foregroundColor(isChecked ? .green : .gray)
                        .font(.title3)
                    
                    VStack(alignment: .leading) {
                        Text(item.product.name)
                            .font(.subheadline)
                            .strikethrough(isChecked)
                            .foregroundColor(isChecked ? .secondary : .primary)
                        
                        Text("Qty: \(item.quantity)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    if let price = item.product.currentLowestPrice?.totalPrice {
                        Text("$\(price, specifier: "%.2f")")
                            .font(.subheadline)
                            .foregroundColor(isChecked ? .secondary : .primary)
                    }
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(PlainButtonStyle())
        }
    }

    struct ShoppingProgressBar: View {
        let completed: Int
        let total: Int
        
        private var progress: Double {
            guard total > 0 else { return 0 }
            return Double(completed) / Double(total)
        }
        
        var body: some View {
            VStack(spacing: 8) {
                HStack {
                    Text("\(completed) of \(total) items")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    Text("\(Int(progress * 100))%")
                        .font(.caption)
                        .fontWeight(.semibold)
                }
                
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color(.systemGray5))
                        
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.green)
                            .frame(width: geometry.size.width * progress)
                            .animation(.easeInOut(duration: 0.3), value: progress)
                    }
                }
                .frame(height: 8)
            }
            .padding()
            .background(Color(.systemBackground))
        }
    }

    // MARK: - View Model
    class ShoppingListViewModel: ObservableObject {
        @Published var items: [ShoppingListItem] = []
        @Published var smartSuggestions: [SmartSuggestion] = []
        @Published var currentFilter: FilterOption = .all
        @Published var currentSort: SortOption = .dateAdded
        
        private let priceTrackingService = PriceTrackingService.shared
        private let claudeService = ClaudeAPIService.shared
        
        enum FilterOption {
            case all
            case tracking
            case priority(ShoppingListItem.Priority)
        }
        
        enum SortOption {
            case priority
            case alphabetical
            case category
            case dateAdded
        }
        
        var hasSmartSuggestions: Bool {
            !smartSuggestions.isEmpty
        }
        
        var totalPotentialSavings: Double {
            smartSuggestions.compactMap { $0.potentialSavings }.reduce(0, +)
        }
        
        var estimatedTotal: Double {
            items.reduce(0) { total, item in
                let price = item.product.currentLowestPrice?.totalPrice ?? 0
                return total + (price * Double(item.quantity))
            }
        }
        
        var potentialSavings: Double {
            // Calculate potential savings based on tracked items
            items.filter { $0.isTracking }.reduce(0) { total, item in
                guard let current = item.product.currentLowestPrice?.price,
                      let target = item.targetPrice else { return total }
                let savings = max(0, current - target) * Double(item.quantity)
                return total + savings
            }
        }
        
        var trackingItemsCount: Int {
            items.filter { $0.isTracking }.count
        }
        
        var urgentItems: [ShoppingListItem] {
            items.filter { $0.priority == .urgent && !$0.isPurchased }
        }
        
        var availableCategories: [Product.ProductCategory] {
            let categories = Set(items.map { $0.product.category })
            return Array(categories).sorted { $0.rawValue < $1.rawValue }
        }
        
        init() {
            loadSampleData()
        }
        
        func addItem(name: String, category: Product.ProductCategory, quantity: Int,
                     priority: ShoppingListItem.Priority, notes: String?,
                     enableTracking: Bool, targetPrice: Double?) {
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
                quantity: quantity,
                priority: priority,
                notes: notes,
                isTracking: enableTracking,
                targetPrice: targetPrice
            )
            
            items.append(item)
            
            if enableTracking {
                priceTrackingService.startTracking(for: product, targetPrice: targetPrice)
            }
            
            // Generate smart suggestions if premium
            if AuthenticationManager.shared.subscriptionTier == .premium {
                generateSmartSuggestions()
            }
        }
        
        func updateItem(_ item: ShoppingListItem, quantity: Int, priority: ShoppingListItem.Priority, notes: String?) {
            if let index = items.firstIndex(where: { $0.id == item.id }) {
                items[index].quantity = quantity
                items[index].priority = priority
                items[index].notes = notes.isEmpty ? nil : notes
            }
        }
        
        func deleteItems(at offsets: IndexSet) {
            items.remove(atOffsets: offsets)
        }
        
        func deleteItems(ids: [UUID]) {
            items.removeAll { ids.contains($0.id) }
        }
        
        func togglePurchased(_ item: ShoppingListItem) {
            if let index = items.firstIndex(where: { $0.id == item.id }) {
                items[index].isPurchased.toggle()
            }
        }
        
        func enableTracking(for item: ShoppingListItem) {
            if let index = items.firstIndex(where: { $0.id == item.id }) {
                items[index].isTracking = true
                priceTrackingService.startTracking(for: item.product, targetPrice: item.targetPrice)
            }
        }
        
        func enableTracking(for itemIds: [UUID]) {
            for id in itemIds {
                if let item = items.first(where: { $0.id == id }) {
                    enableTracking(for: item)
                }
            }
        }
        
        func findBestPrice(for item: ShoppingListItem) {
            // Trigger price check
            priceTrackingService.checkPriceNow(for: item.product)
        }
        
        func filteredItems(searchText: String, category: Product.ProductCategory?) -> [ShoppingListItem] {
            var filtered = items
            
            // Apply search filter
            if !searchText.isEmpty {
                filtered = filtered.filter {
                    $0.product.name.localizedCaseInsensitiveContains(searchText)
                }
            }
            
            // Apply category filter
            if let category = category {
                filtered = filtered.filter { $0.product.category == category }
            }
            
            // Apply current filter
            switch currentFilter {
            case .all:
                break
            case .tracking:
                filtered = filtered.filter { $0.isTracking }
            case .priority(let priority):
                filtered = filtered.filter { $0.priority == priority }
            }
            
            // Apply sort
            switch currentSort {
            case .priority:
                filtered.sort { $0.priority.rawValue < $1.priority.rawValue }
            case .alphabetical:
                filtered.sort { $0.product.name < $1.product.name }
            case .category:
                filtered.sort { $0.product.category.rawValue < $1.product.category.rawValue }
            case .dateAdded:
                filtered.sort { $0.dateAdded > $1.dateAdded }
            }
            
            return filtered
        }
        
        func itemCount(for category: Product.ProductCategory) -> Int {
            items.filter { $0.product.category == category }.count
        }
        
        func filterBy(_ option: FilterOption) {
            currentFilter = option
        }
        
        func sortBy(_ option: SortOption) {
            currentSort = option
        }
        
        func getSuggestion(for item: ShoppingListItem) -> SmartSuggestion? {
            smartSuggestions.first { $0.productId == item.id }
        }
        
        func generateSmartSuggestions() {
            // Generate AI-powered suggestions
            Task {
                do {
                    let recommendations = try await claudeService.getSmartRecommendations(
                        items: items,
                        budget: Budget(monthlyLimit: 1000, categories: [:], currentMonthSpending: 0, alerts: [])
                    )
                    
                    await MainActor.run {
                        // Convert to smart suggestions
                        self.smartSuggestions = recommendations.recommendations.enumerated().map { index, rec in
                            SmartSuggestion(
                                productId: items[safe: index]?.id ?? UUID(),
                                message: rec,
                                potentialSavings: Double.random(in: 5...50)
                            )
                        }
                    }
                } catch {
                    print("Error generating suggestions: \(error)")
                }
            }
        }
        
        func markAsPurchased(items: [UUID]) {
            for id in items {
                if let index = self.items.firstIndex(where: { $0.id == id }) {
                    self.items[index].isPurchased = true
                }
            }
        }
        
        func changePriority(for items: [UUID], to priority: ShoppingListItem.Priority) {
            for id in items {
                if let index = self.items.firstIndex(where: { $0.id == id }) {
                    self.items[index].priority = priority
                }
            }
        }
        
        func changeCategory(for items: [UUID], to category: Product.ProductCategory) {
            for id in items {
                if let index = self.items.firstIndex(where: { $0.id == id }) {
                    self.items[index].product = Product(
                        name: self.items[index].product.name,
                        description: self.items[index].product.description,
                        category: category,
                        imageURL: self.items[index].product.imageURL,
                        barcode: self.items[index].product.barcode,
                        brand: self.items[index].product.brand
                    )
                }
            }
        }
        
        func toggleSelection(_ itemId: UUID, in selection: inout Set<UUID>) {
            if selection.contains(itemId) {
                selection.remove(itemId)
            } else {
                selection.insert(itemId)
            }
        }
        
        func addAlternativeToList(_ alternative: ProductAlternatives.Alternative, replacing product: Product) {
            // Add alternative product to list
            let newProduct = Product(
                name: alternative.name,
                description: "Alternative to \(product.name)",
                category: product.category,
                imageURL: nil,
                barcode: nil,
                brand: nil
            )
            
            let item = ShoppingListItem(
                product: newProduct,
                quantity: 1,
                priority: .normal,
                notes: alternative.reason,
                isTracking: true,
                targetPrice: alternative.estimatedPrice * 0.9 // Target 10% below estimate
            )
            
            items.append(item)
        }
        
        func itemsAvailableAt(_ retailer: Retailer) -> [ShoppingListItem] {
            // In production, this would check actual availability
            // For now, return a subset based on retailer type
            items.filter { !$0.isPurchased }
        }
        
        private func loadSampleData() {
            // Load sample shopping list items
            let sampleItems = [
                ShoppingListItem(
                    product: Product(name: "Milk", description: "Dairy", category: .groceries, imageURL: nil, barcode: nil, brand: "Organic Valley"),
                    quantity: 2,
                    priority: .urgent,
                    notes: "2% preferred",
                    isTracking: true,
                    targetPrice: 3.99
                ),
                ShoppingListItem(
                    product: Product(name: "Paper Towels", description: "Household", category: .home, imageURL: nil, barcode: nil, brand: "Bounty"),
                    quantity: 1,
                    priority: .normal,
                    notes: nil,
                    isTracking: true,
                    targetPrice: 15.99
                ),
                ShoppingListItem(
                    product: Product(name: "iPhone Charger", description: "Electronics", category: .electronics, imageURL: nil, barcode: nil, brand: "Apple"),
                    quantity: 1,
                    priority: .low,
                    notes: "USB-C to Lightning",
                    isTracking: true,
                    targetPrice: 19.99
                )
            ]
            
            items = sampleItems
            
            // Generate initial suggestions for premium users
            if AuthenticationManager.shared.subscriptionTier == .premium {
                generateSmartSuggestions()
            }
        }
    }

    // MARK: - Supporting Models
    struct SmartSuggestion {
        let productId: UUID
        let message: String
        let potentialSavings: Double?
    }

    // MARK: - Extensions
    extension Collection {
        subscript(safe index: Index) -> Element? {
            return indices.contains(index) ? self[index] : nil
        }
    }

    // MARK: - Additional Views
    struct DealDetailView: View {
        let deal: DealAlert
        @ObservedObject var viewModel: DealsViewModel
        
        var body: some View {
            Text("Deal Detail View")
                .navigationTitle(deal.product.name)
        }
    }

    struct InventoryDetailView: View {
        let item: InventoryItem
        @ObservedObject var viewModel: InventoryViewModel
        
        var body: some View {
            Text("Inventory Detail View")
                .navigationTitle(item.product.name)
        }
    }

    // MARK: - AddItemView (for backward compatibility)
    struct AddItemView: View {
        @ObservedObject var viewModel: ShoppingListViewModel
        
        var body: some View {
            EnhancedAddItemView(viewModel: viewModel)
        }
    }

    #Preview {
        NavigationView {
            ShoppingListView()
                .environmentObject(AuthenticationManager.shared)
                .environmentObject(PriceTrackingService.shared)
                .environmentObject(NotificationService.shared)
        }
    }
