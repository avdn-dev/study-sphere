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
    let backgroundBlurStyle: UIBlurEffect.Style = .systemChromeMaterialDark
    let icon: UIImage = UIImage(named: "StudySphereIcon")!
    let textColor: UIColor = .label.resolvedColor(with: .init(userInterfaceStyle: .dark))
    let primaryButtonLabelColor: UIColor = .label.resolvedColor(with: .init(userInterfaceStyle: .dark))
    let primaryButtonBackgroundColor: UIColor = UIColor(named: "AccentColor")!
    
    override func configuration(shielding application: Application) -> ShieldConfiguration {
        // Customize the shield as needed for applications.
        ShieldConfiguration(
            backgroundBlurStyle: backgroundBlurStyle,
            icon: icon,
            title: .init(text: "\(application.localizedDisplayName!) blocked by StudySphere", color: textColor),
            subtitle:  .init(text: "Get back to work bum", color: textColor),
            primaryButtonLabel: .init(text: "OK", color: primaryButtonLabelColor),
            primaryButtonBackgroundColor: primaryButtonBackgroundColor
        )
    }
    
    override func configuration(shielding application: Application, in category: ActivityCategory) -> ShieldConfiguration {
        // Customize the shield as needed for applications shielded because of their category.
        ShieldConfiguration(
            backgroundBlurStyle: backgroundBlurStyle,
            icon: icon,
            title: .init(text: "\(application.localizedDisplayName!) blocked by StudySphere", color: textColor),
            subtitle:  .init(text: "Get back to work bum", color: textColor),
            primaryButtonLabel: .init(text: "OK", color: primaryButtonLabelColor),
            primaryButtonBackgroundColor: primaryButtonBackgroundColor
        )
    }
    
    override func configuration(shielding webDomain: WebDomain) -> ShieldConfiguration {
        // Customize the shield as needed for web domains.
        ShieldConfiguration(
            backgroundBlurStyle: backgroundBlurStyle,
            icon: icon,
            title: .init(text: "\(webDomain.domain!) blocked by StudySphere", color: textColor),
            subtitle:  .init(text: "et back to work bum", color: textColor),
            primaryButtonLabel: .init(text: "OK", color: primaryButtonLabelColor),
//            primaryButtonBackgroundColor: primaryButtonBackgroundColor
        )
    }
    
    override func configuration(shielding webDomain: WebDomain, in category: ActivityCategory) -> ShieldConfiguration {
        // Customize the shield as needed for web domains shielded because of their category.
        ShieldConfiguration(
            backgroundBlurStyle: backgroundBlurStyle,
            icon: icon,
            title: .init(text: "\(webDomain.domain!) blocked by StudySphere", color: textColor),
            subtitle:  .init(text: "Get back to work bum", color: textColor),
            primaryButtonLabel: .init(text: "OK", color: primaryButtonLabelColor),
            primaryButtonBackgroundColor: primaryButtonBackgroundColor
        )
    }
}


