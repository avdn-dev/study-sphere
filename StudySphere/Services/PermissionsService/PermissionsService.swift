//
//  PermissionsService.swift
//  StudySphere
//
//  Created by Chris Wong on 13/3/2026.
//

import FamilyControls

protocol PermissionsService: AnyObject {
    var familyControls: AuthorizationCenter { get set }
    
    func requestScreenTimesPermission() async throws
}
