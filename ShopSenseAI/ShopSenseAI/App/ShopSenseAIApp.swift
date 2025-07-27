import SwiftUI
import UserNotifications

@main
struct ShopSenseAIApp: App {
    @StateObject private var authManager = AuthenticationManager.shared
    @StateObject private var userPreferences = UserPreferencesManager.shared
    @StateObject private var notificationService = NotificationService.shared
    @StateObject private var priceTrackingService = PriceTrackingService.shared
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(authManager)
                .environmentObject(userPreferences)
                .environmentObject(notificationService)
                .environmentObject(priceTrackingService)
                .onAppear {
                    if hasCompletedOnboarding {
                        setupAppServices()
                    }
                }
        }
    }
    
    private func setupAppServices() {
        // Setup notification categories
        notificationService.setupNotificationCategories()
        
        // Setup notification observers
        setupNotificationObservers()
        
        // Update notification settings based on user preferences
        notificationService.updateNotificationSettings(with: userPreferences)
        
        // Start price tracking if user has tracking items
        print("🚀 ShopSense AI services initialized")
    }
    
    private func setupNotificationObservers() {
        // Handle navigation from notifications
        NotificationCenter.default.addObserver(
            forName: .navigateToProduct,
            object: nil,
            queue: .main
        ) { notification in
            if let productId = notification.userInfo?["productId"] as? String {
                // Handle navigation to specific product
                print("Navigate to product: \(productId)")
            }
        }
        
        NotificationCenter.default.addObserver(
            forName: .navigateToDeals,
            object: nil,
            queue: .main
        ) { _ in
            // Handle navigation to deals tab
            print("Navigate to deals")
        }
        
        NotificationCenter.default.addObserver(
            forName: .navigateToInventory,
            object: nil,
            queue: .main
        ) { notification in
            // Handle navigation to inventory
            print("Navigate to inventory")
        }
    }
}

// MARK: - Content View
struct ContentView: View {
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @EnvironmentObject var authManager: AuthenticationManager
    @EnvironmentObject var userPreferences: UserPreferencesManager
    @EnvironmentObject var notificationService: NotificationService
    @EnvironmentObject var priceTrackingService: PriceTrackingService
    
    var body: some View {
        Group {
            if !hasCompletedOnboarding {
                OnboardingView()
            } else {
                MainTabView()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didFinishLaunchingNotification)) { _ in
            setupApp()
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
            Task {
                await refreshAppData()
            }
        }
    }
    
    private func setupApp() {
        // Setup notification categories
        notificationService.setupNotificationCategories()
        
        // Setup notification observers for navigation
        setupNotificationObservers()
        
        if hasCompletedOnboarding {
            setupAppServices()
        }
    }
    
    private func setupAppServices() {
        // Update notification settings based on user preferences
        notificationService.updateNotificationSettings(with: userPreferences)
        
        // Start price tracking if user has tracking items
        print("🚀 ShopSense AI services initialized")
    }
    
    private func refreshAppData() async {
        // Refresh notification status
        await notificationService.getPendingNotifications()
        await notificationService.getDeliveredNotifications()
        
        // Update badge count
        let delivered = await notificationService.getDeliveredNotifications()
        notificationService.updateBadgeCount(delivered.count)
    }
    
    private func setupNotificationObservers() {
        // Handle navigation from notifications
        NotificationCenter.default.addObserver(
            forName: .navigateToProduct,
            object: nil,
            queue: .main
        ) { notification in
            if let productId = notification.userInfo?["productId"] as? String {
                // Handle navigation to specific product
                print("Navigate to product: \(productId)")
            }
        }
        
        NotificationCenter.default.addObserver(
            forName: .navigateToDeals,
            object: nil,
            queue: .main
        ) { _ in
            // Handle navigation to deals tab
            print("Navigate to deals")
        }
        
        NotificationCenter.default.addObserver(
            forName: .navigateToInventory,
            object: nil,
            queue: .main
        ) { notification in
            // Handle navigation to inventory
            print("Navigate to inventory")
        }
    }
}

// MARK: - Analytics View
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

// MARK: - App Lifecycle Extensions
extension ContentView {
    private func handleAppBecomeActive() {
        Task {
            // Check notification authorization status
            let status = await notificationService.checkAuthorizationStatus()
            
            if status == .authorized {
                // Update notification settings
                notificationService.updateNotificationSettings(with: userPreferences)
            }
            
            // Refresh app data
            await refreshAppData()
        }
    }
}

// MARK: - Preview Provider
struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
            .environmentObject(AuthenticationManager.shared)
            .environmentObject(UserPreferencesManager.shared)
            .environmentObject(NotificationService.shared)
    }
}
