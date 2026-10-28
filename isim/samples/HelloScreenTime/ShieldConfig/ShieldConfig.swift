// The sample's Shield Configuration extension: its shield names the app and offers more time.
import UIKit
import ManagedSettings
import ManagedSettingsUI

final class ShieldConfig: ShieldConfigurationDataSource {
    override func configuration(shielding application: Application) -> ShieldConfiguration {
        print("stc configuration for \(application.bundleIdentifier ?? "-") (\(application.localizedDisplayName ?? "-"))"); fflush(stdout)
        return ShieldConfiguration(backgroundBlurStyle: .systemMaterial, backgroundColor: nil, icon: UIImage(systemName: "hourglass"),
                                   title: .init(text: "Time’s up", color: .label),
                                   subtitle: .init(text: "\(application.localizedDisplayName ?? "This app") is shielded by Focus Time.", color: .secondaryLabel),
                                   primaryButtonLabel: .init(text: "Close", color: .white), primaryButtonBackgroundColor: .systemIndigo,
                                   secondaryButtonLabel: .init(text: "One More Minute", color: .systemIndigo))
    }
    override func configuration(shielding application: Application, in category: ActivityCategory) -> ShieldConfiguration {
        configuration(shielding: application)
    }
}
