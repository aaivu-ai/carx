import SwiftUI
import SwiftData

struct RootView: View {
    @Query(sort: \VehicleProfile.createdAt) private var profiles: [VehicleProfile]
    @AppStorage("activeProfileIDString") private var activeProfileIDString: String = ""

    var body: some View {
        Group {
            if profiles.isEmpty {
                OnboardingView()
            } else {
                MainTabView(activeProfile: activeProfile)
            }
        }
        .animation(.easeInOut, value: profiles.isEmpty)
    }

    private var activeProfile: VehicleProfile {
        if let match = profiles.first(where: { $0.id.uuidString == activeProfileIDString }) {
            return match
        }
        return profiles[0]
    }
}
