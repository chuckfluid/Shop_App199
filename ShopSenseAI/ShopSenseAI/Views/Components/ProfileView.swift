import SwiftUI
import MessageUI
import StoreKit

// MARK: - Enhanced Authentication Manager
class AuthenticationManager: ObservableObject {
    @Published var isSignedIn = false
    @Published var subscriptionTier: SubscriptionTier = .free
    @Published var userProfile: UserProfile?
    @Published var subscriptionExpiry: Date?
    @Published var trialDaysRemaining: Int?
    
    enum SubscriptionTier: String, CaseIterable {
        case free = "Free"
        case premium = "Premium"
        
        var displayName: String {
            return self.rawValue
        }
        
        var icon: String {
            switch self {
            case .free: return "person.circle"
            case .premium: return "crown.fill"
            }
        }
        
        var color: Color {
            switch self {
            case .free: return .gray
            case .premium: return .yellow
            }
        }
    }
    
    struct UserProfile {
        let id: String
        let name: String
        let email: String
        let memberSince: Date
        var avatarURL: String?
        var phoneNumber: String?
        var preferences: UserSettings
        
        struct UserSettings {
            var currency: String = "USD"
            var measurementUnit: MeasurementUnit = .imperial
            var language: String = "en"
            
            enum MeasurementUnit: String, CaseIterable {
                case imperial = "Imperial"
                case metric = "Metric"
            }
        }
    }
    
    static let shared = AuthenticationManager()
    
    private init() {
        // Initialize with mock data for development
        loadUserData()
    }
    
    func signIn(email: String, password: String) async throws {
        // Mock sign in - replace with actual authentication
        try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second delay
        
        await MainActor.run {
            self.isSignedIn = true
            self.userProfile = UserProfile(
                id: UUID().uuidString,
                name: "John Doe",
                email: email,
                memberSince: Date().addingTimeInterval(-365 * 86400),
                preferences: UserProfile.UserSettings()
            )
        }
    }
    
    func signOut() {
        isSignedIn = false
        userProfile = nil
        subscriptionTier = .free
        subscriptionExpiry = nil
        trialDaysRemaining = nil
        
        // Clear cached data
        APICacheManager.shared.clearCache()
    }
    
    func upgradeToPremium() async throws {
        // In production, this would handle the actual subscription
        subscriptionTier = .premium
        subscriptionExpiry = Date().addingTimeInterval(30 * 86400) // 30 days
        
        // Enable premium features
        await enablePremiumFeatures()
    }
    
    func restorePurchases() async throws {
        // Restore purchases from App Store
        // In production, use StoreKit
    }
    
    private func enablePremiumFeatures() async {
        // Enable batch processing
        APICacheManager.shared.performBatchProcessing()
    }
    
    private func loadUserData() {
        // Mock user data for development
        userProfile = UserProfile(
            id: "mock_user_id",
            name: "John Doe",
            email: "john.doe@example.com",
            memberSince: Date().addingTimeInterval(-365 * 86400),
            preferences: UserProfile.UserSettings()
        )
        isSignedIn = true
        
        // Check subscription status
        if UserDefaults.standard.bool(forKey: "isPremium") {
            subscriptionTier = .premium
            subscriptionExpiry = UserDefaults.standard.object(forKey: "subscriptionExpiry") as? Date
        }
    }
}

// MARK: - Enhanced User Preferences Manager
class UserPreferencesManager: ObservableObject {
    @Published var priceDropThreshold: Double = 10.0 // Percentage
    @Published var preferredRetailers: Set<String> = ["amazon", "target", "walmart"]
    @Published var budgetAlertThreshold: Double = 0.8 // 80% of budget
    @Published var notificationsEnabled: Bool = true
    @Published var autoReorderEnabled: Bool = false
    @Published var priceCheckFrequency: TimeInterval = 3600 // 1 hour in seconds
    @Published var dealCategories: [Product.ProductCategory] = Product.ProductCategory.allCases
    
    // Enhanced UI preferences
    @Published var dailyDigestEnabled: Bool = true
    @Published var priceDropAlertsEnabled: Bool = true
    @Published var inventoryAlertsEnabled: Bool = true
    @Published var dealExpiringAlertsEnabled: Bool = true
    @Published var digestTime: Date = Calendar.current.date(bySettingHour: 9, minute: 0, second: 0, of: Date()) ?? Date()
    
    // Privacy preferences
    @Published var shareAnalytics: Bool = true
    @Published var personalizedRecommendations: Bool = true
    @Published var locationBasedDeals: Bool = false
    
    // Display preferences
    @Published var compactMode: Bool = false
    @Published var showPriceHistory: Bool = true
    @Published var defaultTab: Int = 0
    
    static let shared = UserPreferencesManager()
    
    private init() {
        loadPreferences()
    }
    
    func savePreferences() {
        // In production, save to UserDefaults or backend
        let encoder = JSONEncoder()
        if let encoded = try? encoder.encode(ClaudeUserPreferences(
            priceDropThreshold: priceDropThreshold,
            preferredRetailers: preferredRetailers,
            budgetAlertThreshold: budgetAlertThreshold,
            notificationsEnabled: notificationsEnabled,
            autoReorderEnabled: autoReorderEnabled,
            priceCheckFrequency: priceCheckFrequency,
            dealCategories: dealCategories
        )) {
            UserDefaults.standard.set(encoded, forKey: "UserPreferences")
        }
        
        // Save UI preferences
        UserDefaults.standard.set(compactMode, forKey: "CompactMode")
        UserDefaults.standard.set(showPriceHistory, forKey: "ShowPriceHistory")
        UserDefaults.standard.set(defaultTab, forKey: "DefaultTab")
        
        // Update notification service
        NotificationService.shared.updateNotificationSettings(with: self)
    }
    
    func resetToDefaults() {
        priceDropThreshold = 10.0
        preferredRetailers = ["amazon", "target", "walmart"]
        budgetAlertThreshold = 0.8
        notificationsEnabled = true
        autoReorderEnabled = false
        priceCheckFrequency = 3600
        dealCategories = Product.ProductCategory.allCases
        
        dailyDigestEnabled = true
        priceDropAlertsEnabled = true
        inventoryAlertsEnabled = true
        dealExpiringAlertsEnabled = true
        
        shareAnalytics = true
        personalizedRecommendations = true
        locationBasedDeals = false
        
        compactMode = false
        showPriceHistory = true
        defaultTab = 0
        
        savePreferences()
    }
    
    private func loadPreferences() {
        // Load from UserDefaults or backend
        if let data = UserDefaults.standard.data(forKey: "UserPreferences"),
           let preferences = try? JSONDecoder().decode(ClaudeUserPreferences.self, from: data) {
            self.priceDropThreshold = preferences.priceDropThreshold
            self.preferredRetailers = preferences.preferredRetailers
            self.budgetAlertThreshold = preferences.budgetAlertThreshold
            self.notificationsEnabled = preferences.notificationsEnabled
            self.autoReorderEnabled = preferences.autoReorderEnabled
            self.priceCheckFrequency = preferences.priceCheckFrequency
            self.dealCategories = preferences.dealCategories
        }
        
        // Load UI preferences
        compactMode = UserDefaults.standard.bool(forKey: "CompactMode")
        showPriceHistory = UserDefaults.standard.bool(forKey: "ShowPriceHistory")
        defaultTab = UserDefaults.standard.integer(forKey: "DefaultTab")
    }
}

// MARK: - Enhanced Profile View
struct ProfileView: View {
    @EnvironmentObject var authManager: AuthenticationManager
    @EnvironmentObject var userPreferences: UserPreferencesManager
    @StateObject private var viewModel = ProfileViewModel()
    @State private var showingSubscriptionDetails = false
    @State private var showingEditProfile = false
    @State private var selectedSection: ProfileSection? = nil
    
    enum ProfileSection: String, CaseIterable {
        case account = "Account"
        case preferences = "Preferences"
        case savings = "Savings"
        case support = "Support"
        
        var icon: String {
            switch self {
            case .account: return "person.circle"
            case .preferences: return "gear"
            case .savings: return "chart.bar"
            case .support: return "questionmark.circle"
            }
        }
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Enhanced Profile Header
                    EnhancedProfileHeaderView(
                        userProfile: authManager.userProfile,
                        subscriptionTier: authManager.subscriptionTier,
                        onEditProfile: { showingEditProfile = true }
                    )
                    .padding(.horizontal)
                    
                    // Subscription Status Card
                    EnhancedSubscriptionStatusCard(
                        tier: authManager.subscriptionTier,
                        expiryDate: authManager.subscriptionExpiry,
                        trialDaysRemaining: authManager.trialDaysRemaining,
                        showingDetails: $showingSubscriptionDetails
                    )
                    .padding(.horizontal)
                    
                    // Savings Overview Card
                    SavingsOverviewCard(viewModel: viewModel)
                        .padding(.horizontal)
                    
                    // Main Sections
                    VStack(spacing: 16) {
                        // Account Section
                        ProfileSectionCard(
                            title: ProfileSection.account.rawValue,
                            icon: ProfileSection.account.icon
                        ) {
                            NavigationLink(destination: AccountSettingsView()) {
                                SettingsRow(
                                    title: "Account Information",
                                    icon: "person.text.rectangle",
                                    value: authManager.userProfile?.email
                                )
                            }
                            
                            NavigationLink(destination: SecuritySettingsView()) {
                                SettingsRow(
                                    title: "Security",
                                    icon: "lock.shield",
                                    value: "Password & 2FA"
                                )
                            }
                            
                            NavigationLink(destination: ConnectedAccountsView()) {
                                SettingsRow(
                                    title: "Connected Accounts",
                                    icon: "link",
                                    value: "\(viewModel.connectedAccountsCount) linked"
                                )
                            }
                        }
                        
                        // Preferences Section
                        ProfileSectionCard(
                            title: ProfileSection.preferences.rawValue,
                            icon: ProfileSection.preferences.icon
                        ) {
                            NavigationLink(destination: NotificationSettingsView().environmentObject(userPreferences)) {
                                SettingsRow(
                                    title: "Notifications",
                                    icon: "bell",
                                    value: userPreferences.notificationsEnabled ? "On" : "Off"
                                )
                            }
                            
                            NavigationLink(destination: RetailerPreferencesView().environmentObject(userPreferences)) {
                                SettingsRow(
                                    title: "Preferred Retailers",
                                    icon: "building.2",
                                    value: "\(userPreferences.preferredRetailers.count) selected"
                                )
                            }
                            
                            NavigationLink(destination: BudgetSettingsView()) {
                                SettingsRow(
                                    title: "Budget & Goals",
                                    icon: "dollarsign.square",
                                    value: viewModel.budgetStatus
                                )
                            }
                            
                            NavigationLink(destination: DisplayPreferencesView().environmentObject(userPreferences)) {
                                SettingsRow(
                                    title: "Display & Interface",
                                    icon: "rectangle.3.group",
                                    value: userPreferences.compactMode ? "Compact" : "Standard"
                                )
                            }
                            
                            NavigationLink(destination: PrivacySettingsView().environmentObject(userPreferences)) {
                                SettingsRow(
                                    title: "Privacy",
                                    icon: "lock",
                                    value: nil
                                )
                            }
                        }
                        
                        // Savings & Analytics Section
                        ProfileSectionCard(
                            title: ProfileSection.savings.rawValue,
                            icon: ProfileSection.savings.icon
                        ) {
                            NavigationLink(destination: DetailedSavingsView()) {
                                SettingsRow(
                                    title: "Detailed Analytics",
                                    icon: "chart.xyaxis.line",
                                    value: "View all"
                                )
                            }
                            
                            NavigationLink(destination: SavingsGoalsView()) {
                                SettingsRow(
                                    title: "Savings Goals",
                                    icon: "target",
                                    value: "\(viewModel.goalsProgress)% complete"
                                )
                            }
                            
                            NavigationLink(destination: ExportDataView()) {
                                SettingsRow(
                                    title: "Export Data",
                                    icon: "square.and.arrow.up",
                                    value: "CSV, PDF"
                                )
                            }
                        }
                        
                        // Support Section
                        ProfileSectionCard(
                            title: ProfileSection.support.rawValue,
                            icon: ProfileSection.support.icon
                        ) {
                            NavigationLink(destination: HelpCenterView()) {
                                SettingsRow(
                                    title: "Help Center",
                                    icon: "questionmark.circle",
                                    value: nil
                                )
                            }
                            
                            Button(action: { viewModel.contactSupport() }) {
                                SettingsRow(
                                    title: "Contact Support",
                                    icon: "envelope",
                                    value: nil
                                )
                            }
                            
                            NavigationLink(destination: AboutView()) {
                                SettingsRow(
                                    title: "About ShopSense AI",
                                    icon: "info.circle",
                                    value: "v\(viewModel.appVersion)"
                                )
                            }
                            
                            Button(action: { viewModel.rateApp() }) {
                                SettingsRow(
                                    title: "Rate App",
                                    icon: "star",
                                    value: nil
                                )
                            }
                        }
                        
                        // Account Actions
                        VStack(spacing: 12) {
                            if authManager.subscriptionTier == .free {
                                Button(action: { showingSubscriptionDetails = true }) {
                                    Label("Upgrade to Premium", systemImage: "crown.fill")
                                        .frame(maxWidth: .infinity)
                                }
                                .buttonStyle(.borderedProminent)
                                .controlSize(.large)
                            }
                            
                            Button(action: { viewModel.showingSignOutAlert = true }) {
                                Label("Sign Out", systemImage: "arrow.right.square")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.bordered)
                            .foregroundColor(.red)
                        }
                        .padding(.horizontal)
                    }
                }
                .padding(.vertical)
            }
            .navigationTitle("Profile")
            .navigationBarTitleDisplayMode(.large)
            .sheet(isPresented: $showingSubscriptionDetails) {
                EnhancedSubscriptionDetailsView()
                    .environmentObject(authManager)
            }
            .sheet(isPresented: $showingEditProfile) {
                EditProfileView()
                    .environmentObject(authManager)
            }
            .alert("Sign Out", isPresented: $viewModel.showingSignOutAlert) {
                Button("Sign Out", role: .destructive) {
                    authManager.signOut()
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("Are you sure you want to sign out?")
            }
        }
    }
}

// MARK: - Enhanced Profile Header
struct EnhancedProfileHeaderView: View {
    let userProfile: AuthenticationManager.UserProfile?
    let subscriptionTier: AuthenticationManager.SubscriptionTier
    let onEditProfile: () -> Void
    
    var body: some View {
        HStack(spacing: 16) {
            // Avatar
            ZStack {
                Circle()
                    .fill(LinearGradient(
                        colors: [subscriptionTier.color, subscriptionTier.color.opacity(0.6)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ))
                    .frame(width: 80, height: 80)
                
                if let avatarURL = userProfile?.avatarURL {
                    // AsyncImage would load the avatar
                    Image(systemName: "person.fill")
                        .font(.largeTitle)
                        .foregroundColor(.white)
                } else {
                    Text(userProfile?.name.prefix(2).uppercased() ?? "??")
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                }
                
                // Subscription Badge
                Image(systemName: subscriptionTier.icon)
                    .font(.caption)
                    .foregroundColor(.white)
                    .padding(4)
                    .background(subscriptionTier.color)
                    .clipShape(Circle())
                    .offset(x: 25, y: 25)
            }
            
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(userProfile?.name ?? "User")
                        .font(.title3)
                        .fontWeight(.semibold)
                    
                    Button(action: onEditProfile) {
                        Image(systemName: "pencil.circle")
                            .foregroundColor(.blue)
                    }
                }
                
                if let email = userProfile?.email {
                    Text(email)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                if let memberSince = userProfile?.memberSince {
                    HStack(spacing: 4) {
                        Image(systemName: "calendar")
                            .font(.caption)
                        Text("Member since \(memberSince.formatted(.dateTime.month(.abbreviated).year()))")
                            .font(.caption)
                    }
                    .foregroundColor(.secondary)
                }
            }
            
            Spacer()
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(radius: 1)
    }
}

// MARK: - Enhanced Subscription Status Card
struct EnhancedSubscriptionStatusCard: View {
    let tier: AuthenticationManager.SubscriptionTier
    let expiryDate: Date?
    let trialDaysRemaining: Int?
    @Binding var showingDetails: Bool
    
    var body: some View {
        VStack(spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Image(systemName: tier.icon)
                            .foregroundColor(tier.color)
                        
                        Text(tier == .premium ? "Premium Member" : "Free Plan")
                            .font(.headline)
                    }
                    
                    if let expiry = expiryDate {
                        if expiry > Date() {
                            Text("Renews \(expiry.formatted(.relative(presentation: .named)))")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        } else {
                            Text("Expired \(expiry.formatted(.relative(presentation: .named)))")
                                .font(.caption)
                                .foregroundColor(.red)
                        }
                    } else if tier == .free {
                        Text("Upgrade for advanced features")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    if let trialDays = trialDaysRemaining {
                        HStack(spacing: 4) {
                            Image(systemName: "gift")
                                .font(.caption)
                            Text("\(trialDays) days left in trial")
                                .font(.caption)
                        }
                        .foregroundColor(.orange)
                    }
                }
                
                Spacer()
                
                Button(tier == .premium ? "Manage" : "Upgrade") {
                    showingDetails = true
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
            }
            
            if tier == .premium {
                // Premium Benefits Summary
                HStack(spacing: 16) {
                    BenefitBadge(icon: "sparkles", text: "AI Insights")
                    BenefitBadge(icon: "clock", text: "Real-time")
                    BenefitBadge(icon: "infinity", text: "Unlimited")
                }
            }
        }
        .padding()
        .background(tier == .premium ?
            LinearGradient(
                colors: [tier.color.opacity(0.1), tier.color.opacity(0.05)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ) : Color(.systemGray6)
        )
        .cornerRadius(12)
    }
}

struct BenefitBadge: View {
    let icon: String
    let text: String
    
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption2)
            Text(text)
                .font(.caption2)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color(.systemGray5))
        .cornerRadius(6)
    }
}

// MARK: - Savings Overview Card
struct SavingsOverviewCard: View {
    @ObservedObject var viewModel: ProfileViewModel
    @State private var selectedPeriod: SavingsPeriod = .month
    
    enum SavingsPeriod: String, CaseIterable {
        case week = "Week"
        case month = "Month"
        case year = "Year"
        case all = "All Time"
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Savings Overview")
                    .font(.headline)
                
                Spacer()
                
                Picker("Period", selection: $selectedPeriod) {
                    ForEach(SavingsPeriod.allCases, id: \.self) { period in
                        Text(period.rawValue).tag(period)
                    }
                }
                .pickerStyle(SegmentedPickerStyle())
                .frame(width: 200)
            }
            
            HStack(spacing: 20) {
                SavingsStat(
                    title: "Total Saved",
                    amount: viewModel.savingsForPeriod(selectedPeriod),
                    icon: "dollarsign.circle.fill",
                    color: .green
                )
                
                Divider()
                    .frame(height: 40)
                
                SavingsStat(
                    title: "Avg per Deal",
                    amount: viewModel.averageSavingsForPeriod(selectedPeriod),
                    icon: "chart.bar.fill",
                    color: .blue
                )
                
                Divider()
                    .frame(height: 40)
                
                SavingsStat(
                    title: "Best Deal",
                    amount: viewModel.bestDealForPeriod(selectedPeriod),
                    icon: "star.fill",
                    color: .orange
                )
            }
            
            // Mini Chart
            SavingsChartView(period: selectedPeriod)
                .frame(height: 80)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

struct SavingsStat: View {
    let title: String
    let amount: Double
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(color)
            
            Text("$\(amount, specifier: "%.2f")")
                .font(.headline)
                .foregroundColor(color)
            
            Text(title)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

struct SavingsChartView: View {
    let period: SavingsOverviewCard.SavingsPeriod
    
    var body: some View {
        // Placeholder for actual chart
        RoundedRectangle(cornerRadius: 8)
            .fill(Color.blue.opacity(0.1))
            .overlay(
                Text("Savings trend chart")
                    .font(.caption)
                    .foregroundColor(.blue)
            )
    }
}

// MARK: - Profile Section Card
struct ProfileSectionCard<Content: View>: View {
    let title: String
    let icon: String
    @ViewBuilder let content: () -> Content
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(.blue)
                Text(title)
                    .font(.headline)
            }
            .padding()
            
            Divider()
            
            VStack(spacing: 0) {
                content()
            }
        }
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(radius: 1)
        .padding(.horizontal)
    }
}

// MARK: - Settings Row
struct SettingsRow: View {
    let title: String
    let icon: String
    let value: String?
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .font(.body)
                .foregroundColor(.blue)
                .frame(width: 30)
            
            Text(title)
                .font(.subheadline)
            
            Spacer()
            
            if let value = value {
                Text(value)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(.gray)
        }
        .padding()
        .contentShape(Rectangle())
    }
}

// MARK: - Enhanced Notification Settings
struct NotificationSettingsView: View {
    @EnvironmentObject var userPreferences: UserPreferencesManager
    @State private var showingTestNotification = false
    
    var body: some View {
        Form {
            Section {
                Toggle("Enable All Notifications", isOn: $userPreferences.notificationsEnabled)
                    .onChange(of: userPreferences.notificationsEnabled) { _ in
                        userPreferences.savePreferences()
                    }
            } footer: {
                Text("Master switch for all notifications")
            }
            
            Section("Notification Types") {
                Toggle("Daily Digest", isOn: $userPreferences.dailyDigestEnabled)
                
                if userPreferences.dailyDigestEnabled {
                    DatePicker("Digest Time", selection: $userPreferences.digestTime, displayedComponents: .hourAndMinute)
                }
                
                Toggle("Price Drop Alerts", isOn: $userPreferences.priceDropAlertsEnabled)
                
                Toggle("Inventory Reminders", isOn: $userPreferences.inventoryAlertsEnabled)
                
                Toggle("Expiring Deals", isOn: $userPreferences.dealExpiringAlertsEnabled)
            }
            .disabled(!userPreferences.notificationsEnabled)
            .onChange(of: userPreferences.dailyDigestEnabled) { _ in
                userPreferences.savePreferences()
            }
            .onChange(of: userPreferences.priceDropAlertsEnabled) { _ in
                userPreferences.savePreferences()
            }
            .onChange(of: userPreferences.inventoryAlertsEnabled) { _ in
                userPreferences.savePreferences()
            }
            .onChange(of: userPreferences.dealExpiringAlertsEnabled) { _ in
                userPreferences.savePreferences()
            }
            
            Section("Alert Preferences") {
                VStack(alignment: .leading) {
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
                    
                    Text("Get notified when prices drop by this percentage or more")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .disabled(!userPreferences.notificationsEnabled)
            
            Section("Quiet Hours") {
                QuietHoursSettings()
            }
            
            Section {
                Button("Send Test Notification") {
                    NotificationService.shared.sendTestNotification()
                    showingTestNotification = true
                }
                .disabled(!userPreferences.notificationsEnabled)
            }
        }
        .navigationTitle("Notifications")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Test Notification Sent", isPresented: $showingTestNotification) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("Check your notifications to confirm they're working properly")
        }
    }
}

struct QuietHoursSettings: View {
    @State private var quietHoursEnabled = false
    @State private var startTime = Date()
    @State private var endTime = Date()
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Toggle("Enable Quiet Hours", isOn: $quietHoursEnabled)
            
            if quietHoursEnabled {
                DatePicker("Start Time", selection: $startTime, displayedComponents: .hourAndMinute)
                DatePicker("End Time", selection: $endTime, displayedComponents: .hourAndMinute)
                
                Text("No notifications during quiet hours except critical alerts")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
}

// MARK: - Enhanced Retailer Preferences
struct RetailerPreferencesView: View {
    @EnvironmentObject var userPreferences: UserPreferencesManager
    @State private var searchText = ""
    @State private var showingAddRetailer = false
    
    private let popularRetailers = ["amazon", "target", "walmart", "bestbuy", "costco"]
    
    var body: some View {
        VStack {
            // Search Bar
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.gray)
                TextField("Search retailers...", text: $searchText)
                
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
            .padding()
            
            // Quick Selection
            if searchText.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Popular Retailers")
                        .font(.headline)
                        .padding(.horizontal)
                    
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(popularRetailers, id: \.self) { retailerId in
                                if let retailer = Retailer.allRetailers.first(where: { $0.id == retailerId }) {
                                    PopularRetailerCard(
                                        retailer: retailer,
                                        isSelected: userPreferences.preferredRetailers.contains(retailerId),
                                        action: { toggleRetailer(retailer) }
                                    )
                                }
                            }
                        }
                        .padding(.horizontal)
                    }
                }
                .padding(.bottom)
            }
            
            // Retailer List
            List {
                Section("All Retailers") {
                    ForEach(filteredRetailers, id: \.id) { retailer in
                        RetailerRow(
                            retailer: retailer,
                            isSelected: userPreferences.preferredRetailers.contains(retailer.id),
                            action: { toggleRetailer(retailer) }
                        )
                    }
                }
            }
        }
        .navigationTitle("Preferred Retailers")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Add Custom") {
                    showingAddRetailer = true
                }
            }
        }
        .sheet(isPresented: $showingAddRetailer) {
            AddCustomRetailerView()
        }
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

struct PopularRetailerCard: View {
    let retailer: Retailer
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Circle()
                    .fill(isSelected ? Color.blue.opacity(0.2) : Color(.systemGray5))
                    .frame(width: 60, height: 60)
                    .overlay(
                        Text(retailer.name.prefix(2).uppercased())
                            .fontWeight(.semibold)
                            .foregroundColor(isSelected ? .blue : .primary)
                    )
                
                Text(retailer.name)
                    .font(.caption)
                    .lineLimit(1)
                
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(isSelected ? .blue : .gray)
                    .font(.caption)
            }
            .frame(width: 80)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct RetailerRow: View {
    let retailer: Retailer
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                // Logo placeholder
                Circle()
                    .fill(Color(.systemGray5))
                    .frame(width: 40, height: 40)
                    .overlay(
                        Text(retailer.name.prefix(1))
                            .fontWeight(.semibold)
                    )
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(retailer.name)
                        .font(.subheadline)
                    
                    Text(retailer.websiteURL)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(isSelected ? .blue : .gray)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct AddCustomRetailerView: View {
    @Environment(\.dismiss) var dismiss
    @State private var name = ""
    @State private var website = ""
    
    var body: some View {
        NavigationView {
            Form {
                Section("Retailer Information") {
                    TextField("Name", text: $name)
                    TextField("Website URL", text: $website)
                        .keyboardType(.URL)
                        .autocapitalization(.none)
                }
                
                Section {
                    Text("Custom retailers will be available for price tracking once approved")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .navigationTitle("Add Custom Retailer")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Submit") {
                        // Submit custom retailer
                        dismiss()
                    }
                    .disabled(name.isEmpty || website.isEmpty)
                }
            }
        }
    }
}

// MARK: - Budget Settings View
struct BudgetSettingsView: View {
    @StateObject private var viewModel = BudgetViewModel()
    @State private var showingAddCategory = false
    
    var body: some View {
        Form {
            Section("Monthly Budget") {
                HStack {
                    Text("Total Budget")
                    TextField("0.00", text: $viewModel.monthlyBudget)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                }
                
                if let budget = Double(viewModel.monthlyBudget), budget > 0 {
                    BudgetProgressView(
                        spent: viewModel.currentSpending,
                        total: budget
                    )
                }
            }
            
            Section("Category Budgets") {
                ForEach(Product.ProductCategory.allCases, id: \.self) { category in
                    HStack {
                        Label(category.rawValue, systemImage: category.icon)
                            .foregroundColor(Color(category.color))
                        
                        TextField("0.00", text: viewModel.binding(for: category))
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                    }
                }
            }
            
            Section("Budget Alerts") {
                Toggle("Enable Budget Alerts", isOn: $viewModel.enableBudgetAlerts)
                
                if viewModel.enableBudgetAlerts {
                    Stepper("Alert at \(Int(viewModel.alertThreshold * 100))%",
                           value: $viewModel.alertThreshold,
                           in: 0.5...0.95,
                           step: 0.05)
                }
            }
            
            Section("Savings Goals") {
                HStack {
                    Text("Monthly Savings Target")
                    TextField("0.00", text: $viewModel.savingsGoal)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                }
                
                Toggle("Track Savings Progress", isOn: $viewModel.trackSavingsProgress)
            }
        }
        .navigationTitle("Budget & Goals")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Save") {
                    viewModel.saveBudgetSettings()
                }
            }
        }
    }
}

struct BudgetProgressView: View {
    let spent: Double
    let total: Double
    
    private var percentage: Double {
        spent / total
    }
    
    private var progressColor: Color {
        if percentage >= 0.9 {
            return .red
        } else if percentage >= 0.75 {
            return .orange
        } else {
            return .green
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Spent: $\(spent, specifier: "%.2f")")
                    .font(.caption)
                Spacer()
                Text("Remaining: $\(total - spent, specifier: "%.2f")")
                    .font(.caption)
            }
            
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color(.systemGray5))
                    
                    RoundedRectangle(cornerRadius: 4)
                        .fill(progressColor)
                        .frame(width: geometry.size.width * min(percentage, 1.0))
                }
            }
            .frame(height: 8)
            
            Text("\(Int(percentage * 100))% of budget used")
                .font(.caption2)
                .foregroundColor(progressColor)
        }
    }
}

// MARK: - Display Preferences View
struct DisplayPreferencesView: View {
    @EnvironmentObject var userPreferences: UserPreferencesManager
    @State private var selectedTheme: AppTheme = .system
    
    enum AppTheme: String, CaseIterable {
        case light = "Light"
        case dark = "Dark"
        case system = "System"
    }
    
    var body: some View {
        Form {
            Section("Appearance") {
                Picker("Theme", selection: $selectedTheme) {
                    ForEach(AppTheme.allCases, id: \.self) { theme in
                        Text(theme.rawValue).tag(theme)
                    }
                }
                .pickerStyle(SegmentedPickerStyle())
                
                Toggle("Compact Mode", isOn: $userPreferences.compactMode)
                    .onChange(of: userPreferences.compactMode) { _ in
                        userPreferences.savePreferences()
                    }
                
                Text("Compact mode shows more items with less spacing")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Section("Data Display") {
                Toggle("Show Price History", isOn: $userPreferences.showPriceHistory)
                    .onChange(of: userPreferences.showPriceHistory) { _ in
                        userPreferences.savePreferences()
                    }
                
                VStack(alignment: .leading) {
                    Text("Default Home Tab")
                    Picker("Default Tab", selection: $userPreferences.defaultTab) {
                        Text("Home").tag(0)
                        Text("Shopping").tag(1)
                        Text("Deals").tag(2)
                        Text("Inventory").tag(3)
                        Text("Profile").tag(4)
                    }
                    .pickerStyle(MenuPickerStyle())
                    .onChange(of: userPreferences.defaultTab) { _ in
                        userPreferences.savePreferences()
                    }
                }
            }
            
            Section("Accessibility") {
                VStack(alignment: .leading) {
                    Text("Text Size")
                    Slider(value: .constant(1.0), in: 0.8...1.5)
                    Text("Adjust text size throughout the app")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Toggle("Reduce Motion", isOn: .constant(false))
                Toggle("High Contrast", isOn: .constant(false))
            }
        }
        .navigationTitle("Display & Interface")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Privacy Settings View
struct PrivacySettingsView: View {
    @EnvironmentObject var userPreferences: UserPreferencesManager
    @State private var showingDeleteAlert = false
    @State private var showingClearHistoryAlert = false
    @State private var showingDataExport = false
    
    var body: some View {
        Form {
            Section("Data & Analytics") {
                Toggle("Share Anonymous Analytics", isOn: $userPreferences.shareAnalytics)
                    .onChange(of: userPreferences.shareAnalytics) { _ in
                        userPreferences.savePreferences()
                    }
                
                Text("Help improve ShopSense AI by sharing anonymous usage data")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Section("Personalization") {
                Toggle("Personalized Recommendations", isOn: $userPreferences.personalizedRecommendations)
                    .onChange(of: userPreferences.personalizedRecommendations) { _ in
                        userPreferences.savePreferences()
                    }
                
                Toggle("Location-Based Deals", isOn: $userPreferences.locationBasedDeals)
                    .onChange(of: userPreferences.locationBasedDeals) { _ in
                        userPreferences.savePreferences()
                    }
                
                if userPreferences.locationBasedDeals {
                    Text("Your location is only used to show nearby deals and is never stored")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Section("Data Management") {
                Button(action: { showingDataExport = true }) {
                    HStack {
                        Image(systemName: "square.and.arrow.up")
                        Text("Export My Data")
                    }
                }
                
                Button(action: { showingClearHistoryAlert = true }) {
                    HStack {
                        Image(systemName: "clock.arrow.circlepath")
                        Text("Clear Shopping History")
                    }
                }
                .foregroundColor(.orange)
                
                Button(action: { showingDeleteAlert = true }) {
                    HStack {
                        Image(systemName: "trash")
                        Text("Delete Account")
                    }
                }
                .foregroundColor(.red)
            }
            
            Section("Third-Party Services") {
                NavigationLink(destination: ThirdPartyServicesView()) {
                    HStack {
                        Text("Connected Services")
                        Spacer()
                        Text("3 connected")
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .navigationTitle("Privacy")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Clear Shopping History", isPresented: $showingClearHistoryAlert) {
            Button("Clear", role: .destructive) {
                clearShoppingHistory()
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("This will permanently delete all your shopping history, including purchase records and price tracking data. This action cannot be undone.")
        }
        .alert("Delete Account", isPresented: $showingDeleteAlert) {
            Button("Delete", role: .destructive) {
                deleteAccount()
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("This will permanently delete your account and all associated data. You will lose all your saved items, preferences, and history. This action cannot be undone.")
        }
        .sheet(isPresented: $showingDataExport) {
            DataExportView()
        }
    }
    
    private func clearShoppingHistory() {
        // Clear shopping history
        print("Clearing shopping history...")
        APICacheManager.shared.clearCache()
    }
    
    private func deleteAccount() {
        // Delete account
        print("Deleting account...")
        AuthenticationManager.shared.signOut()
    }
}

struct ThirdPartyServicesView: View {
    var body: some View {
        List {
            ServiceRow(
                name: "Google",
                description: "Sign in with Google",
                isConnected: true
            )
            
            ServiceRow(
                name: "Amazon",
                description: "Import purchase history",
                isConnected: true
            )
            
            ServiceRow(
                name: "Walmart",
                description: "Track Walmart+ savings",
                isConnected: false
            )
        }
        .navigationTitle("Connected Services")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct ServiceRow: View {
    let name: String
    let description: String
    let isConnected: Bool
    
    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text(name)
                    .font(.subheadline)
                    .fontWeight(.medium)
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            if isConnected {
                Button("Disconnect") {
                    // Disconnect service
                }
                .font(.caption)
                .foregroundColor(.red)
            } else {
                Button("Connect") {
                    // Connect service
                }
                .font(.caption)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Data Export View
struct DataExportView: View {
    @Environment(\.dismiss) var dismiss
    @State private var selectedFormats = Set<ExportFormat>()
    @State private var dateRange: ExportDateRange = .all
    @State private var isExporting = false
    
    enum ExportFormat: String, CaseIterable {
        case csv = "CSV"
        case json = "JSON"
        case pdf = "PDF"
        
        var icon: String {
            switch self {
            case .csv: return "tablecells"
            case .json: return "curlybraces"
            case .pdf: return "doc.text"
            }
        }
    }
    
    enum ExportDateRange: String, CaseIterable {
        case month = "Last Month"
        case quarter = "Last 3 Months"
        case year = "Last Year"
        case all = "All Time"
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section("Export Format") {
                    ForEach(ExportFormat.allCases, id: \.self) { format in
                        HStack {
                            Image(systemName: format.icon)
                                .foregroundColor(.blue)
                                .frame(width: 30)
                            
                            Text(format.rawValue)
                            
                            Spacer()
                            
                            if selectedFormats.contains(format) {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.blue)
                            }
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            if selectedFormats.contains(format) {
                                selectedFormats.remove(format)
                            } else {
                                selectedFormats.insert(format)
                            }
                        }
                    }
                }
                
                Section("Date Range") {
                    Picker("Export data from", selection: $dateRange) {
                        ForEach(ExportDateRange.allCases, id: \.self) { range in
                            Text(range.rawValue).tag(range)
                        }
                    }
                }
                
                Section("Data to Include") {
                    Toggle("Shopping History", isOn: .constant(true))
                    Toggle("Saved Items", isOn: .constant(true))
                    Toggle("Price Tracking Data", isOn: .constant(true))
                    Toggle("Inventory", isOn: .constant(true))
                    Toggle("Analytics & Insights", isOn: .constant(true))
                }
                
                Section {
                    Button(action: startExport) {
                        if isExporting {
                            HStack {
                                ProgressView()
                                Text("Preparing export...")
                            }
                        } else {
                            Text("Export Data")
                        }
                    }
                    .disabled(selectedFormats.isEmpty || isExporting)
                }
            }
            .navigationTitle("Export Data")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
    
    private func startExport() {
        isExporting = true
        
        // Simulate export
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            isExporting = false
            // Show share sheet with exported files
            dismiss()
        }
    }
}

// MARK: - Enhanced Subscription Details
struct EnhancedSubscriptionDetailsView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var authManager: AuthenticationManager
    @State private var selectedPlan: SubscriptionPlan = .monthly
    @State private var isProcessingPayment = false
    
    enum SubscriptionPlan: String, CaseIterable {
        case monthly = "Monthly"
        case annual = "Annual"
        
        var price: String {
            switch self {
            case .monthly: return "$4.99"
            case .annual: return "$39.99"
            }
        }
        
        var savings: String? {
            switch self {
            case .monthly: return nil
            case .annual: return "Save 33%"
            }
        }
        
        var period: String {
            switch self {
            case .monthly: return "per month"
            case .annual: return "per year"
            }
        }
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    VStack(spacing: 16) {
                        Image(systemName: "crown.fill")
                            .font(.system(size: 60))
                            .foregroundColor(.yellow)
                        
                        Text("ShopSense AI Premium")
                            .font(.title)
                            .fontWeight(.bold)
                        
                        Text("Unlock the full power of AI-driven shopping")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding()
                    
                    // Plan Selection
                    VStack(spacing: 12) {
                        ForEach(SubscriptionPlan.allCases, id: \.self) { plan in
                            SubscriptionPlanCard(
                                plan: plan,
                                isSelected: selectedPlan == plan,
                                action: { selectedPlan = plan }
                            )
                        }
                    }
                    .padding(.horizontal)
                    
                    // Features List
                    VStack(alignment: .leading, spacing: 20) {
                        Text("Premium Features")
                            .font(.headline)
                            .padding(.horizontal)
                        
                        VStack(spacing: 16) {
                            PremiumFeatureRow(
                                icon: "sparkles",
                                title: "AI Shopping Intelligence",
                                description: "Advanced AI predictions and personalized recommendations powered by Claude",
                                isIncluded: true
                            )
                            
                            PremiumFeatureRow(
                                icon: "chart.line.uptrend.xyaxis",
                                title: "Price Predictions",
                                description: "Know the best time to buy with AI-powered price forecasts",
                                isIncluded: true
                            )
                            
                            PremiumFeatureRow(
                                icon: "clock",
                                title: "Real-Time Tracking",
                                description: "Live price updates and instant deal notifications",
                                isIncluded: true
                            )
                            
                            PremiumFeatureRow(
                                icon: "infinity",
                                title: "Unlimited Everything",
                                description: "No limits on items, alerts, or AI analyses",
                                isIncluded: true
                            )
                            
                            PremiumFeatureRow(
                                icon: "arrow.triangle.2.circlepath",
                                title: "Smart Auto-Reorder",
                                description: "AI optimizes your reorder timing for maximum savings",
                                isIncluded: true
                            )
                            
                            PremiumFeatureRow(
                                icon: "dollarsign.circle",
                                title: "Advanced Analytics",
                                description: "Deep insights into your shopping patterns and savings",
                                isIncluded: true
                            )
                        }
                        .padding(.horizontal)
                    }
                    
                    // Comparison Table
                    ComparisonTableView()
                        .padding()
                    
                    // Subscribe Button
                    VStack(spacing: 16) {
                        Button(action: subscribe) {
                            if isProcessingPayment {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            } else {
                                VStack(spacing: 4) {
                                    Text("Start 7-Day Free Trial")
                                        .font(.headline)
                                    Text("Then \(selectedPlan.price) \(selectedPlan.period)")
                                        .font(.caption)
                                }
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                        .disabled(isProcessingPayment)
                        
                        Text("Cancel anytime. No commitment.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Button("Restore Purchases") {
                            Task {
                                try await authManager.restorePurchases()
                            }
                        }
                        .font(.caption)
                    }
                    .padding()
                    
                    // Terms
                    VStack(spacing: 8) {
                        Text("Subscription automatically renews unless cancelled at least 24 hours before the end of the current period.")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                        
                        HStack(spacing: 16) {
                            Link("Terms of Service", destination: URL(string: "https://shopsenseai.com/terms")!)
                            Link("Privacy Policy", destination: URL(string: "https://shopsenseai.com/privacy")!)
                        }
                        .font(.caption)
                    }
                    .padding()
                }
            }
            .navigationTitle("Premium")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
    
    private func subscribe() {
        isProcessingPayment = true
        
        Task {
            do {
                try await authManager.upgradeToPremium()
                await MainActor.run {
                    isProcessingPayment = false
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    isProcessingPayment = false
                    // Show error alert
                }
            }
        }
    }
}

struct SubscriptionPlanCard: View {
    let plan: EnhancedSubscriptionDetailsView.SubscriptionPlan
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(plan.rawValue)
                        .font(.headline)
                    
                    HStack(baseline: .bottom, spacing: 4) {
                        Text(plan.price)
                            .font(.title2)
                            .fontWeight(.bold)
                        Text(plan.period)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                if let savings = plan.savings {
                    Text(savings)
                        .font(.caption)
                        .fontWeight(.semibold)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.green.opacity(0.2))
                        .foregroundColor(.green)
                        .cornerRadius(6)
                }
                
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(isSelected ? .blue : .gray)
            }
            .padding()
            .background(isSelected ? Color.blue.opacity(0.1) : Color(.systemGray6))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? Color.blue : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct PremiumFeatureRow: View {
    let icon: String
    let title: String
    let description: String
    let isIncluded: Bool
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(isIncluded ? .purple : .gray)
                .frame(width: 30)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            
            Spacer()
        }
    }
}

struct ComparisonTableView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Free vs Premium")
                .font(.headline)
            
            VStack(spacing: 12) {
                ComparisonRow(feature: "Price Tracking", free: "5 items", premium: "Unlimited")
                ComparisonRow(feature: "AI Predictions", free: "Basic", premium: "Advanced")
                ComparisonRow(feature: "Deal Alerts", free: "Daily", premium: "Real-time")
                ComparisonRow(feature: "Auto-Reorder", free: "Manual", premium: "AI-Powered")
                ComparisonRow(feature: "Analytics", free: "Last 30 days", premium: "All time")
                ComparisonRow(feature: "Support", free: "Standard", premium: "Priority")
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

struct ComparisonRow: View {
    let feature: String
    let free: String
    let premium: String
    
    var body: some View {
        HStack {
            Text(feature)
                .font(.subheadline)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            Text(free)
                .font(.caption)
                .foregroundColor(.secondary)
                .frame(width: 80)
            
            Text(premium)
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(.purple)
                .frame(width: 80)
        }
    }
}

// MARK: - Additional Views
struct EditProfileView: View {
    @EnvironmentObject var authManager: AuthenticationManager
    @Environment(\.dismiss) var dismiss
    @State private var name = ""
    @State private var email = ""
    @State private var phoneNumber = ""
    
    var body: some View {
        NavigationView {
            Form {
                Section("Personal Information") {
                    TextField("Name", text: $name)
                    TextField("Email", text: $email)
                        .keyboardType(.emailAddress)
                        .autocapitalization(.none)
                    TextField("Phone Number", text: $phoneNumber)
                        .keyboardType(.phonePad)
                }
                
                Section("Preferences") {
                    Picker("Currency", selection: .constant("USD")) {
                        Text("USD").tag("USD")
                        Text("EUR").tag("EUR")
                        Text("GBP").tag("GBP")
                    }
                    
                    Picker("Units", selection: .constant(AuthenticationManager.UserProfile.UserSettings.MeasurementUnit.imperial)) {
                        ForEach(AuthenticationManager.UserProfile.UserSettings.MeasurementUnit.allCases, id: \.self) { unit in
                            Text(unit.rawValue).tag(unit)
                        }
                    }
                }
            }
            .navigationTitle("Edit Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        // Save profile changes
                        dismiss()
                    }
                }
            }
        }
        .onAppear {
            if let profile = authManager.userProfile {
                name = profile.name
                email = profile.email
                phoneNumber = profile.phoneNumber ?? ""
            }
        }
    }
}

struct AccountSettingsView: View {
    @EnvironmentObject var authManager: AuthenticationManager
    
    var body: some View {
        Form {
            Section("Account Information") {
                if let profile = authManager.userProfile {
                    HStack {
                        Text("Name")
                        Spacer()
                        Text(profile.name)
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Text("Email")
                        Spacer()
                        Text(profile.email)
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Text("Member Since")
                        Spacer()
                        Text(profile.memberSince.formatted(date: .abbreviated, time: .omitted))
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            Section("Account ID") {
                if let userId = authManager.userProfile?.id {
                    HStack {
                        Text(userId)
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Button(action: {
                            UIPasteboard.general.string = userId
                        }) {
                            Image(systemName: "doc.on.doc")
                                .font(.caption)
                        }
                    }
                }
            }
        }
        .navigationTitle("Account Information")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct SecuritySettingsView: View {
    @State private var currentPassword = ""
    @State private var newPassword = ""
    @State private var confirmPassword = ""
    @State private var twoFactorEnabled = false
    
    var body: some View {
        Form {
            Section("Change Password") {
                SecureField("Current Password", text: $currentPassword)
                SecureField("New Password", text: $newPassword)
                SecureField("Confirm Password", text: $confirmPassword)
                
                Button("Update Password") {
                    // Update password
                }
                .disabled(currentPassword.isEmpty || newPassword.isEmpty || confirmPassword.isEmpty)
            }
            
            Section("Two-Factor Authentication") {
                Toggle("Enable 2FA", isOn: $twoFactorEnabled)
                
                if twoFactorEnabled {
                    Text("Scan the QR code with your authenticator app")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    // QR Code placeholder
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color(.systemGray6))
                        .frame(height: 200)
                        .overlay(
                            Text("QR Code")
                                .foregroundColor(.gray)
                        )
                }
            }
        }
        .navigationTitle("Security")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct ConnectedAccountsView: View {
    var body: some View {
        List {
            Text("Connected accounts functionality coming soon")
                .foregroundColor(.secondary)
        }
        .navigationTitle("Connected Accounts")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct DetailedSavingsView: View {
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                Text("Detailed savings analytics coming soon")
                    .foregroundColor(.secondary)
                    .padding()
            }
        }
        .navigationTitle("Detailed Analytics")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct SavingsGoalsView: View {
    @State private var monthlyGoal = ""
    @State private var yearlyGoal = ""
    
    var body: some View {
        Form {
            Section("Savings Goals") {
                HStack {
                    Text("Monthly Goal")
                    TextField("0.00", text: $monthlyGoal)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                }
                
                HStack {
                    Text("Yearly Goal")
                    TextField("0.00", text: $yearlyGoal)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                }
            }
            
            Section("Progress") {
                Text("Goal tracking coming soon")
                    .foregroundColor(.secondary)
            }
        }
        .navigationTitle("Savings Goals")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct HelpCenterView: View {
    var body: some View {
        List {
            Section("Getting Started") {
                NavigationLink("How to add items", destination: Text("Tutorial"))
                NavigationLink("Understanding price tracking", destination: Text("Tutorial"))
                NavigationLink("Setting up notifications", destination: Text("Tutorial"))
            }
            
            Section("Features") {
                NavigationLink("Premium features", destination: Text("Feature guide"))
                NavigationLink("AI recommendations", destination: Text("Feature guide"))
                NavigationLink("Auto-reorder", destination: Text("Feature guide"))
            }
            
            Section("Troubleshooting") {
                NavigationLink("Common issues", destination: Text("Troubleshooting"))
                NavigationLink("Contact support", destination: Text("Support"))
            }
        }
        .navigationTitle("Help Center")
        .navigationBarTitleDisplayMode(.inline)
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

// MARK: - View Models
class ProfileViewModel: ObservableObject {
    @Published var userName = "John Doe"
    @Published var userEmail = "john.doe@example.com"
    @Published var memberSince = Date().addingTimeInterval(-365 * 86400) // 1 year ago
    @Published var totalSaved: Double = 1893.45
    @Published var monthSaved: Double = 245.80
    @Published var averageMonthlySavings: Double = 157.79
    @Published var connectedAccountsCount = 2
    @Published var budgetStatus = "80% used"
    @Published var goalsProgress = 75
    @Published var appVersion = "1.0.0"
    @Published var showingSignOutAlert = false
    
    func savingsForPeriod(_ period: SavingsOverviewCard.SavingsPeriod) -> Double {
        switch period {
        case .week: return 45.67
        case .month: return monthSaved
        case .year: return 1543.20
        case .all: return totalSaved
        }
    }
    
    func averageSavingsForPeriod(_ period: SavingsOverviewCard.SavingsPeriod) -> Double {
        switch period {
        case .week: return 6.52
        case .month: return 8.19
        case .year: return 128.60
        case .all: return averageMonthlySavings
        }
    }
    
    func bestDealForPeriod(_ period: SavingsOverviewCard.SavingsPeriod) -> Double {
        switch period {
        case .week: return 25.00
        case .month: return 75.50
        case .year: return 150.00
        case .all: return 250.00
        }
    }
    
    func contactSupport() {
        // Open support email
        if let url = URL(string: "mailto:support@shopsenseai.com?subject=Support%20Request") {
            if UIApplication.shared.canOpenURL(url) {
                UIApplication.shared.open(url)
            }
        }
    }
    
    func rateApp() {
        // Open App Store for rating
        if let url = URL(string: "https://apps.apple.com/app/idXXXXXXXXX") {
            UIApplication.shared.open(url)
        }
    }
    
    func exportData() {
        // Export user data
        print("Exporting user data...")
        // In production, this would generate and share a data export file
    }
}

class BudgetViewModel: ObservableObject {
    @Published var monthlyBudget = ""
    @Published var categoryBudgets: [Product.ProductCategory: String] = [:]
    @Published var savingsGoal = ""
    @Published var enableBudgetAlerts = true
    @Published var alertThreshold: Double = 0.8
    @Published var trackSavingsProgress = true
    @Published var currentSpending: Double = 750
    
    func binding(for category: Product.ProductCategory) -> Binding<String> {
        Binding(
            get: { self.categoryBudgets[category] ?? "" },
            set: { self.categoryBudgets[category] = $0 }
        )
    }
    
    func saveBudgetSettings() {
        // Save budget settings to backend or UserDefaults
        print("Saving budget settings...")
    }
}

// MARK: - AnalyticsView (moved from ShopSenseAIApp.swift)
struct AnalyticsView: View {
    @EnvironmentObject var userPreferences: UserPreferencesManager
    @State private var totalSavings: Double = 1247.89
    @State private var monthlyAverage: Double = 156.78
    @State private var dealsFound: Int = 47
    @State private var showingUpgradeSheet = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Header
                    VStack(spacing: 8) {
                        Text("Your Savings")
                            .font(.title2)
                            .fontWeight(.bold)
                        
                        Text("Track your smart shopping wins")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .padding(.top)
                    
                    // Savings Summary Cards
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                        SavingsCard(
                            title: "Total Saved",
                            value: String(format: "$%.2f", totalSavings),
                            icon: "dollarsign.circle.fill",
                            color: .green
                        )
                        
                        SavingsCard(
                            title: "This Month",
                            value: String(format: "$%.2f", monthlyAverage),
                            icon: "calendar",
                            color: .blue
                        )
                        
                        SavingsCard(
                            title: "Deals Found",
                            value: "\(dealsFound)",
                            icon: "tag.fill",
                            color: .orange
                        )
                        
                        SavingsCard(
                            title: "Avg per Deal",
                            value: String(format: "$%.2f", totalSavings / Double(dealsFound)),
                            icon: "chart.bar.fill",
                            color: .purple
                        )
                    }
                    .padding(.horizontal)
                    
                    // Chart Placeholder
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Savings Over Time")
                            .font(.headline)
                            .padding(.horizontal)
                        
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color(.systemGray6))
                            .frame(height: 200)
                            .overlay(
                                VStack {
                                    Image(systemName: "chart.line.uptrend.xyaxis")
                                        .font(.system(size: 40))
                                        .foregroundColor(.gray)
                                    Text("Savings chart coming soon")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                }
                            )
                            .padding(.horizontal)
                    }
                    
                    // AI Insights Section
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            Image(systemName: "sparkles")
                                .foregroundColor(.purple)
                            Text("AI Insights")
                                .font(.headline)
                        }
                        .padding(.horizontal)
                        
                        VStack(spacing: 12) {
                            InsightCard(
                                icon: "lightbulb.fill",
                                title: "Smart Timing",
                                description: "You save 23% more when you buy electronics on Tuesdays",
                                color: .yellow
                            )
                            
                            InsightCard(
                                icon: "arrow.down.circle.fill",
                                title: "Price Pattern",
                                description: "Household items in your list typically drop 15% in early months",
                                color: .blue
                            )
                            
                            InsightCard(
                                icon: "target",
                                title: "Goal Progress",
                                description: "You're 78% towards your monthly savings goal of $200",
                                color: .green
                            )
                        }
                        .padding(.horizontal)
                    }
                    
                    // Upgrade CTA for Free Users
                    if AuthenticationManager.shared.subscriptionTier == .free {
                        VStack(spacing: 12) {
                            Text("Get More Insights")
                                .font(.headline)
                            
                            Text("Upgrade to Premium for advanced analytics and AI-powered shopping recommendations")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                            
                            Button("Upgrade to Premium") {
                                showingUpgradeSheet = true
                            }
                            .buttonStyle(.borderedProminent)
                        }
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
                        .padding(.horizontal)
                    }
                    
                    Spacer(minLength: 100)
                }
            }
            .navigationTitle("Analytics")
            .refreshable {
                // Refresh analytics data
                await refreshAnalytics()
            }
        }
        .sheet(isPresented: $showingUpgradeSheet) {
            SubscriptionDetailsView()
                .environmentObject(AuthenticationManager.shared)
        }
    }
    
    private func refreshAnalytics() async {
        // Simulate data refresh
        try? await Task.sleep(nanoseconds: 1_000_000_000)
        
        // Update with fresh data
        totalSavings = Double.random(in: 1000...2000)
        monthlyAverage = Double.random(in: 100...300)
        dealsFound = Int.random(in: 30...60)
    }
}

// MARK: - Supporting Analytics Views
struct SavingsCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)
            
            Text(value)
                .font(.title3)
                .fontWeight(.bold)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

struct InsightCard: View {
    let icon: String
    let title: String
    let description: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(color)
                .frame(width: 30)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }
}

// MARK: - SubscriptionDetailsView (for backward compatibility)
struct SubscriptionDetailsView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var authManager: AuthenticationManager
    
    var body: some View {
        EnhancedSubscriptionDetailsView()
            .environmentObject(authManager)
    }
}

#Preview {
    ProfileView()
        .environmentObject(AuthenticationManager.shared)
        .environmentObject(UserPreferencesManager.shared)
}
