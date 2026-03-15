//
//  ShieldConfigurationExtension.swift
//  ShieldConfiguration
//
//  Created by Chris Wong on 14/3/2026.
//

import ManagedSettings
import ManagedSettingsUI
import UIKit

// Override the functions below to customize the shields used in various situations.
// The system provides a default appearance for any methods that your subclass doesn't override.
// Make sure that your class name matches the NSExtensionPrincipalClass in your Info.plist.
class ShieldConfigurationExtension: ShieldConfigurationDataSource {
    private static let appGroupID = "group.studio.cgc.StudySphere.sharedData"
    private static let roastsKey = "shield.roasts"
    private static let fallbackSubtitle = "Get back to work bum"

    let backgroundBlurStyle: UIBlurEffect.Style = .systemChromeMaterialDark
    let icon: UIImage = UIImage(named: "StudySphereIcon")!
    let textColor: UIColor = .label.resolvedColor(with: .init(userInterfaceStyle: .dark))
    let primaryButtonLabelColor: UIColor = .label.resolvedColor(with: .init(userInterfaceStyle: .dark))
    let primaryButtonBackgroundColor: UIColor = UIColor(named: "AccentColor")!

    private var subtitle: String {
        let defaults = UserDefaults(suiteName: Self.appGroupID)
        let roasts = defaults?.stringArray(forKey: Self.roastsKey) ?? []
        return roasts.randomElement() ?? Self.fallbackSubtitle
    }
    
    override func configuration(shielding application: Application) -> ShieldConfiguration {
        ShieldConfiguration(
            backgroundBlurStyle: backgroundBlurStyle,
            icon: icon,
            title: .init(text: "\(application.localizedDisplayName!) blocked by StudySphere", color: textColor),
            subtitle: .init(text: subtitle, color: textColor),
            primaryButtonLabel: .init(text: "OK", color: primaryButtonLabelColor),
            primaryButtonBackgroundColor: primaryButtonBackgroundColor
        )
    }

    override func configuration(shielding application: Application, in category: ActivityCategory) -> ShieldConfiguration {
        ShieldConfiguration(
            backgroundBlurStyle: backgroundBlurStyle,
            icon: icon,
            title: .init(text: "\(application.localizedDisplayName!) blocked by StudySphere", color: textColor),
            subtitle: .init(text: subtitle, color: textColor),
            primaryButtonLabel: .init(text: "OK", color: primaryButtonLabelColor),
            primaryButtonBackgroundColor: primaryButtonBackgroundColor
        )
    }

    override func configuration(shielding webDomain: WebDomain) -> ShieldConfiguration {
        ShieldConfiguration(
            backgroundBlurStyle: backgroundBlurStyle,
            icon: icon,
            title: .init(text: "\(webDomain.domain!) blocked by StudySphere", color: textColor),
            subtitle: .init(text: subtitle, color: textColor),
            primaryButtonLabel: .init(text: "OK", color: primaryButtonLabelColor),
            primaryButtonBackgroundColor: primaryButtonBackgroundColor
        )
    }

    override func configuration(shielding webDomain: WebDomain, in category: ActivityCategory) -> ShieldConfiguration {
        ShieldConfiguration(
            backgroundBlurStyle: backgroundBlurStyle,
            icon: icon,
            title: .init(text: "\(webDomain.domain!) blocked by StudySphere", color: textColor),
            subtitle: .init(text: subtitle, color: textColor),
            primaryButtonLabel: .init(text: "OK", color: primaryButtonLabelColor),
            primaryButtonBackgroundColor: primaryButtonBackgroundColor
        )
    }
}


