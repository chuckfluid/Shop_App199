import SwiftUI

struct ProfileView: View {
    @EnvironmentObject var authManager: AuthenticationManager
    @EnvironmentObject var userPreferences: UserPreferences
    @StateObject private var viewModel = ProfileViewModel()
    @State private var showingSubscriptionDetails = false
    
    var body: some View {
        NavigationView {
            List {
                // Profile Header
                Section {
                    ProfileHeaderView(
                        userName: viewModel.userName,
                        email: viewModel.userEmail,
                        memberSince: viewModel.memberSince,
                        subscriptionTier: authManager.subscriptionTier
                    )
                }
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets())
                
                // Subscription Status
                Section {
                    SubscriptionStatusRow(
                        tier: authManager.subscriptionTier,
                        showingDetails: $showingSubscriptionDetails
                    )
                }
                
                // Savings Summary
                Section("Savings Summary") {
                    SavingsSummaryRow(
                        title: "Total Saved",
                        amount: viewModel.totalSaved,
                        icon: "dollarsign.circle.fill",
                        color: .green
                    )
                    
                    SavingsSummaryRow(
                        title: "This Month",
                        amount: viewModel.monthSaved,
                        icon: "calendar",
                        color: .blue
                    )
                    
                    SavingsSummaryRow(
                        title: "Average per Month",
                        amount: viewModel.averageMonthlySavings,
                        icon: "chart.line.uptrend.xyaxis",
                        color: .purple
                    )
                }
                
                // Preferences
                Section("Preferences") {
                    NavigationLink(destination: NotificationSettingsView()) {
                        Label("Notifications", systemImage: "bell")
                    }
                    
                    NavigationLink(destination: RetailerPreferencesView()) {
                        Label("Preferred Retailers", systemImage: "building.2")
                    }
                    
                    NavigationLink(destination: BudgetSettingsView()) {
                        Label("Budget & Goals", systemImage: "dollarsign.square")
                    }
                    
                    NavigationLink(destination: PrivacySettingsView()) {
                        Label("Privacy", systemImage: "lock")
                    }
                }
                
                // Support
                Section("Support") {
                    Link(destination: URL(string: "https://shopsenseai.com/help")!) {
                        Label("Help Center", systemImage: "questionmark.circle")
                    }
                    
                    Button(action: { viewModel.contactSupport() }) {
                        Label("Contact Support", systemImage: "envelope")
                    }
                    
                    NavigationLink(destination: AboutView()) {
                        Label("About ShopSense AI", systemImage: "info.circle")
                    }
                }
                
                // Account Actions
                Section {
                    Button(action: { viewModel.exportData() }) {
                        Label("Export My Data", systemImage: "square.and.arrow.up")
                    }
                    
                    Button(action: { authManager.signOut() }) {
                        Label("Sign Out", systemImage: "arrow.right.square")
                            .foregroundColor(.red)
                    }
                }
            }
            .navigationTitle("Profile")
            .sheet(isPresented: $showingSubscriptionDetails) {
                SubscriptionDetailsView()
            }
        }
    }
}

// MARK: - Profile Header View
struct ProfileHeaderView: View {
    let userName: String
    let email: String
    let memberSince: Date
    let subscriptionTier: AuthenticationManager.SubscriptionTier
    
    var body: some View {
        VStack(spacing: 16) {
            // Avatar
            Circle()
                .fill(LinearGradient(
                    colors: [.blue, .purple],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ))
                .frame(width: 80, height: 80)
                .overlay(
                    Text(userName.prefix(2).uppercased())
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                )
            
            // User Info
            VStack(spacing: 4) {
                Text(userName)
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Text(email)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                HStack {
                    Image(systemName: "calendar")
                        .font(.caption)
                    Text("Member since \(memberSince, format: .dateTime.month().year())")
                        .font(.caption)
                }
                .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 20)
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Subscription Status Row
struct SubscriptionStatusRow: View {
    let tier: AuthenticationManager.SubscriptionTier
    @Binding var showingDetails: Bool
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Image(systemName: tier == .premium ? "crown.fill" : "person.circle")
                        .foregroundColor(tier == .premium ? .yellow : .gray)
                    
                    Text(tier == .premium ? "Premium Member" : "Free Plan")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                }
                
                if tier == .free {
                    Text("Upgrade for AI insights")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            Button(tier == .premium ? "Manage" : "Upgrade") {
                showingDetails = true
            }
            .font(.caption)
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Savings Summary Row
struct SavingsSummaryRow: View {
    let title: String
    let amount: Double
    let icon: String
    let color: Color
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(color)
                .frame(width: 30)
            
            Text(title)
                .font(.subheadline)
            
            Spacer()
            
            Text("$\(amount, specifier: "%.2f")")
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(color)
        }
    }
}

// MARK: - Notification Settings View
struct NotificationSettingsView: View {
    @EnvironmentObject var userPreferences: UserPreferences
    @State private var dailyDigest = true
    @State private var priceDrops = true
    @State private var inventoryAlerts = true
    @State private var dealExpiring = true
    @State private var digestTime = Date()
    
    var body: some View {
        Form {
            Section {
                Toggle("Enable Notifications", isOn: $userPreferences.notificationsEnabled)
                    .onChange(of: userPreferences.notificationsEnabled) { _ in
                        userPreferences.savePreferences()
                    }
            }
            
            Section("Notification Types") {
                Toggle("Daily Digest", isOn: $dailyDigest)
                
                if dailyDigest {
                    DatePicker("Digest Time", selection: $digestTime, displayedComponents: .hourAndMinute)
                }
                
                Toggle("Price Drop Alerts", isOn: $priceDrops)
                
                Toggle("Inventory Reminders", isOn: $inventoryAlerts)
                
                Toggle("Expiring Deals", isOn: $dealExpiring)
            }
            .disabled(!userPreferences.notificationsEnabled)
            
            Section("Alert Preferences") {
                HStack {
                    Text("Price Drop Threshold")
                    Spacer()
                    Text("\(Int(userPreferences.priceDropThreshold))%")
                        .foregroundColor(.secondary)
                }
                
                Slider(value: $userPreferences.priceDropThreshold, in: 5...50, step: 5)
                    .onChange(of: userPreferences.priceDropThreshold) { _ in
                        userPreferences.savePreferences()
                    }
            }
            .disabled(!userPreferences.notificationsEnabled)
        }
        .navigationTitle("Notifications")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Retailer Preferences View
struct RetailerPreferencesView: View {
    @EnvironmentObject var userPreferences: UserPreferences
    @State private var searchText = ""
    
    var body: some View {
        VStack {
            // Search Bar
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.gray)
                TextField("Search retailers...", text: $searchText)
            }
            .padding(8)
            .background(Color(.systemGray6))
            .cornerRadius(8)
            .padding()
            
            // Retailer List
            List {
                ForEach(filteredRetailers, id: \.id) { retailer in
                    HStack {
                        // Logo placeholder
                        Circle()
                            .fill(Color(.systemGray5))
                            .frame(width: 40, height: 40)
                            .overlay(
                                Text(retailer.name.prefix(1))
                                    .fontWeight(.semibold)
                            )
                        
                        Text(retailer.name)
                            .font(.subheadline)
                        
                        Spacer()
                        
                        if userPreferences.preferredRetailers.contains(retailer.id) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.blue)
                        }
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        toggleRetailer(retailer)
                    }
                }
            }
        }
        .navigationTitle("Preferred Retailers")
        .navigationBarTitleDisplayMode(.inline)
    }
    
    private var filteredRetailers: [Retailer] {
        if searchText.isEmpty {
            return Retailer.allRetailers
        } else {
            return Retailer.allRetailers.filter {
                $0.name.localizedCaseInsensitiveContains(searchText)
            }
        }
    }
    
    private func toggleRetailer(_ retailer: Retailer) {
        if userPreferences.preferredRetailers.contains(retailer.id) {
            userPreferences.preferredRetailers.remove(retailer.id)
        } else {
            userPreferences.preferredRetailers.insert(retailer.id)
        }
        userPreferences.savePreferences()
    }
}

// MARK: - Budget Settings View
struct BudgetSettingsView: View {
    @State private var monthlyBudget = ""
    @State private var categoryBudgets: [Product.ProductCategory: String] = [:]
    @State private var savingsGoal = ""
    @State private var enableBudgetAlerts = true
    
    var body: some View {
        Form {
            Section("Monthly Budget") {
                HStack {
                    Text("Total Budget")
                    TextField("0.00", text: $monthlyBudget)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                }
            }
            
            Section("Category Budgets") {
                ForEach(Product.ProductCategory.allCases, id: \.self) { category in
                    HStack {
                        Label(category.rawValue, systemImage: categoryIcon(for: category))
                        TextField("0.00", text: binding(for: category))
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                    }
                }
            }
            
            Section("Savings Goals") {
                HStack {
                    Text("Monthly Savings Target")
                    TextField("0.00", text: $savingsGoal)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                }
                
                Toggle("Budget Alert Notifications", isOn: $enableBudgetAlerts)
            }
        }
        .navigationTitle("Budget & Goals")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Save") {
                    saveBudgetSettings()
                }
            }
        }
    }
    
    private func binding(for category: Product.ProductCategory) -> Binding<String> {
        Binding(
            get: { categoryBudgets[category] ?? "" },
            set: { categoryBudgets[category] = $0 }
        )
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
    
    private func saveBudgetSettings() {
        // Save budget settings
    }
}

// MARK: - Privacy Settings View
struct PrivacySettingsView: View {
    @State private var shareAnalytics = true
    @State private var personalizedRecommendations = true
    @State private var locationBasedDeals = false
    
    var body: some View {
        Form {
            Section {
                Toggle("Share Analytics", isOn: $shareAnalytics)
                Text("Help improve ShopSense AI by sharing anonymous usage data")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Section {
                Toggle("Personalized Recommendations", isOn: $personalizedRecommendations)
                Text("Use AI to provide personalized shopping recommendations")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Section {
                Toggle("Location-Based Deals", isOn: $locationBasedDeals)
                Text("Show deals from retailers near your location")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Section {
                Button("Clear Shopping History") {
                    // Clear history
                }
                .foregroundColor(.red)
                
                Button("Delete Account") {
                    // Delete account
                }
                .foregroundColor(.red)
            }
        }
        .navigationTitle("Privacy")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Subscription Details View
struct SubscriptionDetailsView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var authManager: AuthenticationManager
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Current Plan
                    CurrentPlanCard(tier: authManager.subscriptionTier)
                    
                    // Premium Features
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Premium Features")
                            .font(.headline)
                            .padding(.horizontal)
                        
                        VStack(spacing: 12) {
                            FeatureRow(
                                icon: "sparkles",
                                title: "AI Shopping Intelligence",
                                description: "Advanced AI predictions and personalized recommendations",
                                isPremium: true
                            )
                            
                            FeatureRow(
                                icon: "chart.line.uptrend.xyaxis",
                                title: "Price Predictions",
                                description: "Know the best time to buy with AI-powered forecasts",
                                isPremium: true
                            )
                            
                            FeatureRow(
                                icon: "bell.badge",
                                title: "Smart Alerts",
                                description: "Get notified for deals that matter to you",
                                isPremium: false
                            )
                            
                            FeatureRow(
                                icon: "arrow.triangle.2.circlepath",
                                title: "Auto-Reorder",
                                description: "Never run out of essentials",
                                isPremium: false
                            )
                            
                            FeatureRow(
                                icon: "dollarsign.circle",
                                title: "Budget Optimization",
                                description: "AI-powered budget recommendations",
                                isPremium: true
                            )
                        }
                        .padding(.horizontal)
                    }
                    
                    // Pricing
                    if authManager.subscriptionTier == .free {
                        VStack(spacing: 16) {
                            Text("Unlock Premium")
                                .font(.headline)
                            
                            VStack(spacing: 4) {
                                Text("$4.99")
                                    .font(.system(size: 36, weight: .bold))
                                Text("per month")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                            
                            Button(action: subscribeToPremium) {
                                Text("Start Free Trial")
                                    .font(.headline)
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(Color.blue)
                                    .cornerRadius(12)
                            }
                            .padding(.horizontal)
                            
                            Text("7-day free trial, then $4.99/month")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .padding(.vertical)
            }
            .navigationTitle("Subscription")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
    
    private func subscribeToPremium() {
        // Handle subscription
    }
}

// MARK: - Supporting Views
struct CurrentPlanCard: View {
    let tier: AuthenticationManager.SubscriptionTier
    
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: tier == .premium ? "crown.fill" : "person.circle")
                .font(.system(size: 40))
                .foregroundColor(tier == .premium ? .yellow : .gray)
            
            Text(tier == .premium ? "Premium Member" : "Free Plan")
                .font(.title2)
                .fontWeight(.bold)
            
            if tier == .premium {
                Text("Thank you for supporting ShopSense AI!")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            } else {
                Text("Upgrade to unlock AI-powered features")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
        .padding(.horizontal)
    }
}

struct FeatureRow: View {
    let icon: String
    let title: String
    let description: String
    let isPremium: Bool
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(isPremium ? .purple : .blue)
                .frame(width: 30)
            
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(title)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    
                    if isPremium {
                        Text("PREMIUM")
                            .font(.caption2)
                            .fontWeight(.bold)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.purple.opacity(0.2))
                            .foregroundColor(.purple)
                            .cornerRadius(4)
                    }
                }
                
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
    }
}

// MARK: - About View
struct AboutView: View {
    var body: some View {
        List {
            Section {
                HStack {
                    Text("Version")
                    Spacer()
                    Text("1.0.0")
                        .foregroundColor(.secondary)
                }
                
                HStack {
                    Text("Build")
                    Spacer()
                    Text("100")
                        .foregroundColor(.secondary)
                }
            }
            
            Section("Legal") {
                Link("Terms of Service", destination: URL(string: "https://shopsenseai.com/terms")!)
                Link("Privacy Policy", destination: URL(string: "https://shopsenseai.com/privacy")!)
                Link("Licenses", destination: URL(string: "https://shopsenseai.com/licenses")!)
            }
            
            Section {
                VStack(alignment: .center, spacing: 8) {
                    Text("Made with ❤️ by ShopSense AI Team")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text("© 2024 ShopSense AI")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
            }
        }
        .navigationTitle("About")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - View Model
class ProfileViewModel: ObservableObject {
    @Published var userName = "John Doe"
    @Published var userEmail = "john.doe@example.com"
    @Published var memberSince = Date().addingTimeInterval(-365 * 86400) // 1 year ago
    @Published var totalSaved: Double = 1893.45
    @Published var monthSaved: Double = 245.80
    @Published var averageMonthlySavings: Double = 157.79
    
    func contactSupport() {
        // Open support email
    }
    
    func exportData() {
        // Export user data
    }
}
