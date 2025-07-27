import SwiftUI
import UserNotifications

struct OnboardingView: View {
    @State private var currentPage = 0
    @State private var showingSignUp = false
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @EnvironmentObject var authManager: AuthenticationManager
    @EnvironmentObject var userPreferences: UserPreferencesManager
    
    var body: some View {
        VStack {
            if !showingSignUp {
                // Onboarding Pages
                TabView(selection: $currentPage) {
                    WelcomePage()
                        .tag(0)
                    
                    FeaturesPage()
                        .tag(1)
                    
                    HowItWorksPage()
                        .tag(2)
                    
                    RetailerSelectionPage()
                        .tag(3)
                        .environmentObject(userPreferences)
                    
                    NotificationSetupPage()
                        .tag(4)
                        .environmentObject(userPreferences)
                }
                .tabViewStyle(PageTabViewStyle())
                .indexViewStyle(PageIndexViewStyle(backgroundDisplayMode: .always))
                
                // Bottom Navigation
                VStack(spacing: 20) {
                    if currentPage < 4 {
                        Button(action: nextPage) {
                            Text("Continue")
                                .font(.headline)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.blue)
                                .cornerRadius(12)
                        }
                    } else {
                        Button(action: { showingSignUp = true }) {
                            Text("Get Started")
                                .font(.headline)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.blue)
                                .cornerRadius(12)
                        }
                    }
                    
                    if currentPage == 0 {
                        Button(action: skipOnboarding) {
                            Text("Skip")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .padding()
            } else {
                SignUpView(onComplete: completeOnboarding)
                    .environmentObject(authManager)
            }
        }
        .background(Color(.systemBackground))
    }
    
    private func nextPage() {
        withAnimation {
            currentPage += 1
        }
    }
    
    private func skipOnboarding() {
        hasCompletedOnboarding = true
    }
    
    private func completeOnboarding() {
        hasCompletedOnboarding = true
    }
}

// MARK: - Welcome Page
struct WelcomePage: View {
    var body: some View {
        VStack(spacing: 30) {
            Spacer()
            
            // App Icon
            Image(systemName: "cart.fill.badge.plus")
                .font(.system(size: 80))
                .foregroundColor(.blue)
                .padding()
                .background(
                    Circle()
                        .fill(Color.blue.opacity(0.1))
                )
            
            VStack(spacing: 16) {
                Text("Welcome to\nShopSense AI")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .multilineTextAlignment(.center)
                
                Text("Your Personal Shopping Intelligence Assistant")
                    .font(.title3)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }
            
            Spacer()
            
            // Value Proposition
            VStack(spacing: 20) {
                FeatureHighlight(
                    icon: "dollarsign.circle",
                    text: "Save 15-30% on household spending",
                    color: .green
                )
                
                FeatureHighlight(
                    icon: "chart.line.uptrend.xyaxis",
                    text: "AI-powered price predictions",
                    color: .purple
                )
                
                FeatureHighlight(
                    icon: "bell.badge",
                    text: "Smart deal alerts just for you",
                    color: .orange
                )
            }
            .padding(.horizontal, 40)
            
            Spacer()
        }
    }
}

// MARK: - Features Page
struct FeaturesPage: View {
    var body: some View {
        VStack(spacing: 30) {
            Text("Intelligent Features")
                .font(.title)
                .fontWeight(.bold)
                .padding(.top, 60)
            
            VStack(spacing: 24) {
                FeatureCard(
                    icon: "magnifyingglass.circle.fill",
                    title: "Multi-Platform Tracking",
                    description: "Monitor prices across 20+ major retailers including Amazon, Target, Walmart, and more",
                    color: .blue
                )
                
                FeatureCard(
                    icon: "clock.fill",
                    title: "Perfect Timing",
                    description: "AI predicts the best time to buy based on historical data and seasonal trends",
                    color: .purple
                )
                
                FeatureCard(
                    icon: "house.fill",
                    title: "Household Assistant",
                    description: "Automatically tracks your regular purchases and alerts you to deals before you run out",
                    color: .green
                )
                
                FeatureCard(
                    icon: "brain",
                    title: "Claude AI Integration",
                    description: "Advanced AI analyzes your shopping patterns to maximize savings",
                    color: .orange
                )
            }
            .padding(.horizontal)
            
            Spacer()
        }
    }
}

// MARK: - How It Works Page
struct HowItWorksPage: View {
    var body: some View {
        VStack(spacing: 30) {
            Text("How It Works")
                .font(.title)
                .fontWeight(.bold)
                .padding(.top, 60)
            
            VStack(spacing: 40) {
                StepView(
                    number: "1",
                    title: "Add Items",
                    description: "Add products to your shopping list or inventory",
                    color: .blue
                )
                
                StepView(
                    number: "2",
                    title: "We Track",
                    description: "ShopSense monitors prices across all retailers",
                    color: .purple
                )
                
                StepView(
                    number: "3",
                    title: "Get Alerts",
                    description: "Receive notifications when prices drop or deals appear",
                    color: .green
                )
                
                StepView(
                    number: "4",
                    title: "Save Money",
                    description: "Buy at the perfect time and maximize your savings",
                    color: .orange
                )
            }
            .padding(.horizontal, 40)
            
            Spacer()
        }
    }
}

// MARK: - Retailer Selection Page
struct RetailerSelectionPage: View {
    @EnvironmentObject var userPreferences: UserPreferencesManager
    @State private var selectedRetailers: Set<String> = []
    
    var body: some View {
        VStack(spacing: 20) {
            VStack(spacing: 16) {
                Text("Select Your Retailers")
                    .font(.title)
                    .fontWeight(.bold)
                
                Text("Choose where you shop most often")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            .padding(.top, 40)
            
            ScrollView {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                    ForEach(Retailer.allRetailers, id: \.id) { retailer in
                        RetailerSelectionCard(
                            retailer: retailer,
                            isSelected: selectedRetailers.contains(retailer.id),
                            action: {
                                toggleRetailer(retailer.id)
                            }
                        )
                    }
                }
                .padding()
            }
            
            Text("\(selectedRetailers.count) selected")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .onAppear {
            selectedRetailers = userPreferences.preferredRetailers
        }
    }
    
    private func toggleRetailer(_ id: String) {
        if selectedRetailers.contains(id) {
            selectedRetailers.remove(id)
        } else {
            selectedRetailers.insert(id)
        }
        userPreferences.preferredRetailers = selectedRetailers
        userPreferences.savePreferences()
    }
}

// MARK: - Notification Setup Page
struct NotificationSetupPage: View {
    @EnvironmentObject var userPreferences: UserPreferencesManager
    @State private var enableNotifications = true
    @State private var hasRequestedPermission = false
    
    var body: some View {
        VStack(spacing: 30) {
            VStack(spacing: 16) {
                Text("Stay Updated")
                    .font(.title)
                    .fontWeight(.bold)
                
                Text("Get personalized deal alerts and savings opportunities")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }
            .padding(.top, 40)
            
            VStack(spacing: 20) {
                // Notification Permission
                VStack(spacing: 16) {
                    Image(systemName: "bell.badge.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.blue)
                    
                    Toggle("Enable Notifications", isOn: $enableNotifications)
                        .toggleStyle(SwitchToggleStyle(tint: .blue))
                        .onChange(of: enableNotifications) { value in
                            userPreferences.notificationsEnabled = value
                            if value && !hasRequestedPermission {
                                requestNotificationPermission()
                                hasRequestedPermission = true
                            }
                            userPreferences.savePreferences()
                        }
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
                
                // Daily Digest Time
                if enableNotifications {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Daily Digest Time")
                            .font(.headline)
                        
                        DatePicker("", selection: $userPreferences.digestTime, displayedComponents: .hourAndMinute)
                            .datePickerStyle(WheelDatePickerStyle())
                            .labelsHidden()
                            .onChange(of: userPreferences.digestTime) { _ in
                                userPreferences.savePreferences()
                            }
                        
                        Text("Get your personalized deals summary at this time each day")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                }
                
                // Alert Preferences
                if enableNotifications {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Alert Preferences")
                            .font(.headline)
                        
                        VStack(spacing: 8) {
                            Toggle("Price Drop Alerts", isOn: $userPreferences.priceDropAlertsEnabled)
                            Toggle("Deal Expiring Soon", isOn: $userPreferences.dealExpiringAlertsEnabled)
                            Toggle("Inventory Reminders", isOn: $userPreferences.inventoryAlertsEnabled)
                        }
                        .onChange(of: userPreferences.priceDropAlertsEnabled) { _ in
                            userPreferences.savePreferences()
                        }
                        .onChange(of: userPreferences.dealExpiringAlertsEnabled) { _ in
                            userPreferences.savePreferences()
                        }
                        .onChange(of: userPreferences.inventoryAlertsEnabled) { _ in
                            userPreferences.savePreferences()
                        }
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                }
            }
            .padding(.horizontal)
            
            Spacer()
        }
        .onAppear {
            enableNotifications = userPreferences.notificationsEnabled
        }
    }
    
    private func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, error in
            DispatchQueue.main.async {
                if granted {
                    print("Notification permission granted")
                    userPreferences.notificationsEnabled = true
                } else {
                    print("Notification permission denied")
                    userPreferences.notificationsEnabled = false
                    enableNotifications = false
                }
                userPreferences.savePreferences()
            }
        }
    }
}

// MARK: - Sign Up View
struct SignUpView: View {
    let onComplete: () -> Void
    
    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var acceptTerms = false
    @State private var showingLogin = false
    @State private var isLoading = false
    @State private var showError = false
    @State private var errorMessage = ""
    
    @EnvironmentObject var authManager: AuthenticationManager
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Logo
                    Image(systemName: "cart.fill.badge.plus")
                        .font(.system(size: 60))
                        .foregroundColor(.blue)
                        .padding(.top, 40)
                    
                    Text("Create Account")
                        .font(.title)
                        .fontWeight(.bold)
                    
                    // Form
                    VStack(spacing: 16) {
                        TextField("Email", text: $email)
                            .textFieldStyle(RoundedTextFieldStyle())
                            .textContentType(.emailAddress)
                            .autocapitalization(.none)
                            .keyboardType(.emailAddress)
                        
                        SecureField("Password", text: $password)
                            .textFieldStyle(RoundedTextFieldStyle())
                            .textContentType(.newPassword)
                        
                        SecureField("Confirm Password", text: $confirmPassword)
                            .textFieldStyle(RoundedTextFieldStyle())
                            .textContentType(.newPassword)
                        
                        // Password Requirements
                        if !password.isEmpty {
                            VStack(alignment: .leading, spacing: 4) {
                                PasswordRequirement(
                                    text: "At least 8 characters",
                                    isMet: password.count >= 8
                                )
                                PasswordRequirement(
                                    text: "Passwords match",
                                    isMet: password == confirmPassword && !confirmPassword.isEmpty
                                )
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        
                        // Terms
                        HStack {
                            Button(action: { acceptTerms.toggle() }) {
                                Image(systemName: acceptTerms ? "checkmark.square.fill" : "square")
                                    .foregroundColor(acceptTerms ? .blue : .gray)
                            }
                            
                            VStack(alignment: .leading, spacing: 2) {
                                HStack(spacing: 2) {
                                    Text("I agree to the")
                                        .font(.caption)
                                    Link("Terms of Service", destination: URL(string: "https://shopsenseai.com/terms")!)
                                        .font(.caption)
                                }
                                HStack(spacing: 2) {
                                    Text("and")
                                        .font(.caption)
                                    Link("Privacy Policy", destination: URL(string: "https://shopsenseai.com/privacy")!)
                                        .font(.caption)
                                }
                            }
                            
                            Spacer()
                        }
                    }
                    .padding(.horizontal)
                    
                    // Sign Up Button
                    Button(action: signUp) {
                        if isLoading {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        } else {
                            Text("Create Account")
                                .fontWeight(.semibold)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(isFormValid ? Color.blue : Color.gray)
                    .foregroundColor(.white)
                    .cornerRadius(12)
                    .disabled(!isFormValid || isLoading)
                    .padding(.horizontal)
                    
                    // Login Link
                    HStack {
                        Text("Already have an account?")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        Button("Sign In") {
                            showingLogin = true
                        }
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    }
                    
                    Spacer(minLength: 50)
                }
            }
            .alert("Error", isPresented: $showError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(errorMessage)
            }
            .sheet(isPresented: $showingLogin) {
                LoginView(onComplete: onComplete)
                    .environmentObject(authManager)
            }
        }
    }
    
    private var isFormValid: Bool {
        !email.isEmpty &&
        !password.isEmpty &&
        password == confirmPassword &&
        password.count >= 8 &&
        acceptTerms &&
        email.contains("@") &&
        email.contains(".")
    }
    
    private func signUp() {
        isLoading = true
        
        Task {
            do {
                try await authManager.signIn(email: email, password: password)
                await MainActor.run {
                    isLoading = false
                    onComplete()
                }
            } catch {
                await MainActor.run {
                    isLoading = false
                    errorMessage = error.localizedDescription
                    showError = true
                }
            }
        }
    }
}

// MARK: - Login View
struct LoginView: View {
    let onComplete: () -> Void
    
    @State private var email = ""
    @State private var password = ""
    @State private var isLoading = false
    @State private var showError = false
    @State private var errorMessage = ""
    
    @EnvironmentObject var authManager: AuthenticationManager
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Logo
                    Image(systemName: "cart.fill.badge.plus")
                        .font(.system(size: 60))
                        .foregroundColor(.blue)
                        .padding(.top, 40)
                    
                    Text("Welcome Back")
                        .font(.title)
                        .fontWeight(.bold)
                    
                    // Form
                    VStack(spacing: 16) {
                        TextField("Email", text: $email)
                            .textFieldStyle(RoundedTextFieldStyle())
                            .textContentType(.emailAddress)
                            .autocapitalization(.none)
                            .keyboardType(.emailAddress)
                        
                        SecureField("Password", text: $password)
                            .textFieldStyle(RoundedTextFieldStyle())
                            .textContentType(.password)
                        
                        HStack {
                            Spacer()
                            Button("Forgot Password?") {
                                // Handle forgot password
                                print("Forgot password tapped")
                            }
                            .font(.caption)
                        }
                    }
                    .padding(.horizontal)
                    
                    // Sign In Button
                    Button(action: signIn) {
                        if isLoading {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        } else {
                            Text("Sign In")
                                .fontWeight(.semibold)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(isFormValid ? Color.blue : Color.gray)
                    .foregroundColor(.white)
                    .cornerRadius(12)
                    .disabled(!isFormValid || isLoading)
                    .padding(.horizontal)
                    
                    Spacer(minLength: 50)
                }
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
            }
            .alert("Error", isPresented: $showError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(errorMessage)
            }
        }
    }
    
    private var isFormValid: Bool {
        !email.isEmpty && !password.isEmpty && email.contains("@") && email.contains(".")
    }
    
    private func signIn() {
        isLoading = true
        
        Task {
            do {
                try await authManager.signIn(email: email, password: password)
                await MainActor.run {
                    isLoading = false
                    dismiss()
                    onComplete()
                }
            } catch {
                await MainActor.run {
                    isLoading = false
                    errorMessage = error.localizedDescription
                    showError = true
                }
            }
        }
    }
}

// MARK: - Supporting Views
struct FeatureHighlight: View {
    let icon: String
    let text: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(color)
                .frame(width: 30)
            
            Text(text)
                .font(.subheadline)
                .multilineTextAlignment(.leading)
            
            Spacer()
        }
    }
}

struct FeatureCard: View {
    let icon: String
    let title: String
    let description: String
    let color: Color
    
    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)
                .frame(width: 40, height: 40)
                .background(color.opacity(0.1))
                .cornerRadius(8)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

struct StepView: View {
    let number: String
    let title: String
    let description: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 16) {
            Text(number)
                .font(.title)
                .fontWeight(.bold)
                .foregroundColor(.white)
                .frame(width: 50, height: 50)
                .background(color)
                .clipShape(Circle())
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
    }
}

struct RetailerSelectionCard: View {
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
                    .foregroundColor(isSelected ? .blue : .primary)
                
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(isSelected ? .blue : .gray)
            }
            .frame(maxWidth: .infinity)
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

struct PasswordRequirement: View {
    let text: String
    let isMet: Bool
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: isMet ? "checkmark.circle.fill" : "circle")
                .foregroundColor(isMet ? .green : .gray)
                .font(.caption)
            
            Text(text)
                .font(.caption)
                .foregroundColor(isMet ? .green : .secondary)
        }
    }
}

// MARK: - Text Field Style
struct RoundedTextFieldStyle: TextFieldStyle {
    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(12)
    }
}
