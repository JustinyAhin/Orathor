enum AppDistribution {
    #if SETAPP
    static let storageIdentifier = "segbedji.Orathor-setapp"
    static let keychainService = "com.orathor.keys.setapp"
    static let channelName = "Setapp"
    #else
    static let storageIdentifier = "segbedji.Orathor"
    static let keychainService = "com.orathor.keys"
    static let channelName = "Direct"
    #endif
}
