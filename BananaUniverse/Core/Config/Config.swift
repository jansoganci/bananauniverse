import Foundation

struct Config {
    // MARK: - Info.plist Helper
    /// Safely reads a value from Info.plist
    private static func infoPlistValue(for key: String) -> String? {
        return Bundle.main.object(forInfoDictionaryKey: key) as? String
    }
    
    // MARK: - Supabase Configuration
    static let supabaseURL: String = {
        guard let url = infoPlistValue(for: "SUPABASE_URL") else {
            fatalError("SUPABASE_URL not found in Info.plist. Please ensure INFOPLIST_KEY_SUPABASE_URL is set in build settings.")
        }
        return url
    }()
    
    static let supabaseAnonKey: String = {
        guard let key = infoPlistValue(for: "SUPABASE_ANON_KEY") else {
            fatalError("SUPABASE_ANON_KEY not found in Info.plist. Please ensure INFOPLIST_KEY_SUPABASE_ANON_KEY is set in build settings.")
        }
        return key
    }()
    
    // MARK: - RevenueCat Configuration
    static let revenueCatAPIKey: String = {
        guard let key = infoPlistValue(for: "REVENUECAT_API_KEY") else {
            fatalError("REVENUECAT_API_KEY not found in Info.plist.")
        }
        return key
    }()
    
    // MARK: - Edge Function Configuration
    static var edgeFunctionURL: String {
        return "\(supabaseURL)/functions/v1"
    }
    
    // MARK: - AI Configuration
    static let falAIModel = "fal-ai/nano-banana/edit"

    // MARK: - Storage Configuration
    static let supabaseBucket = "noname-banana-images-prod"
    
    // MARK: - Architecture Decision
    // Using Apple-friendly stack: SwiftUI + Supabase Edge Functions + fal.ai
    
    // MARK: - Security
    #if DEBUG
    static let isDebug = true
    #else
    static let isDebug = false
    #endif

    // MARK: - StableID Migration
    /// Legacy device UUID key for migration from UserDefaults to StableID
    static let legacyDeviceIDKey = "device_uuid_v1"
    
    // MARK: - Paywall Configuration
    // All paywall triggers now use PreviewPaywallView directly
    
    // MARK: - Privacy & Legal
    static let privacyPolicyURL = "https://jansoganci.github.io/banana.universe/privacy.html"
    static let termsOfServiceURL = "https://jansoganci.github.io/banana.universe/terms.html"
    static let supportURL = "https://jansoganci.github.io/banana.universe/support.html"
    
    // MARK: - Debug Logging
    static func debugLog(_ message: String, file: String = #file, function: String = #function) {
        #if DEBUG
        let fileName = URL(fileURLWithPath: file).lastPathComponent
        #endif
    }
}