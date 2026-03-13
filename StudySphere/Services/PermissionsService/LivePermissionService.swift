//
//  LivePermissionService.swift
//  StudySphere
//
//  Created by Chris Wong on 13/3/2026.
//

import FamilyControls
import CoreMotion
import UIKit

final class LivePermissionService: PermissionsService {
    var familyControls: AuthorizationCenter = .shared
    
    func requestScreenTimesPermission() async throws {
        switch familyControls.authorizationStatus {
        case .notDetermined:
            try await familyControls.requestAuthorization(for: .individual)
        case .denied:
            guard let url = URL(string: UIApplication.openSettingsURLString) else {
                fatalError("malformed string for opening settings")
            }
            await UIApplication.shared.open(url)
            print("Denied, opening settings")
        case .approved:
            print("Already approved screen times settings YAY")
        @unknown default:
            print("Screen times permission not accepted :(")
        }
    }
}
