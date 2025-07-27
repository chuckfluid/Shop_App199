import SwiftUI

@main
struct ShopSenseAIApp: App {
    @StateObject private var authManager = AuthenticationManager()
    @StateObject private var userPreferences = UserPreferences()
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    
    var body: some Scene {
        WindowGroup {
            if !hasCompletedOnboarding {
                OnboardingView()
                    .environmentObject(authManager)
                    .environmentObject(userPreferences)
            } else {
                MainTabView()
                    .environmentObject(authManager)
                    .environmentObject(userPreferences)
            }
        }
    }
}

// MARK: - Authentication Manager
class AuthenticationManager: ObservableObject {
    @Published var isAuthenticated = false
    @Published var userID: String?
    @Published var subscriptionTier: SubscriptionTier = .free
    
    enum SubscriptionTier {
        case free
        case premium
    }
    
    func signIn(email: String, password: String) async throws {
        // Implement authentication logic
        await MainActor.run {
            self.isAuthenticated = true
            self.userID = UUID().uuidString
        }
    }
    
    func signOut() {
        isAuthenticated = false
        userID = nil
        subscriptionTier = .free
    }
}

// MARK: - User Preferences
class UserPreferences: ObservableObject {
    @Published var notificationsEnabled = true
    @Published var dailyDigestTime = Date()
    @Published var priceDropThreshold: Double = 10.0
    @Published var preferredRetailers: Set<String> = []
    
    init() {
        loadPreferences()
    }
    
    func loadPreferences() {
        // Load from UserDefaults
        if let retailers = UserDefaults.standard.array(forKey: "preferredRetailers") as? [String] {
            preferredRetailers = Set(retailers)
        }
        notificationsEnabled = UserDefaults.standard.bool(forKey: "notificationsEnabled")
        priceDropThreshold = UserDefaults.standard.double(forKey: "priceDropThreshold")
    }
    
    func savePreferences() {
        UserDefaults.standard.set(Array(preferredRetailers), forKey: "preferredRetailers")
        UserDefaults.standard.set(notificationsEnabled, forKey: "notificationsEnabled")
        UserDefaults.standard.set(priceDropThreshold, forKey: "priceDropThreshold")
    }
}
