//
//  Package Version.swift
//  Cork
//
//  Created by David Bureš on 11.10.2024.
//

import Foundation

/// A version for a package
struct PackageVersion: Identifiable, Hashable, Codable
{
    let id: UUID = .init()
    
    /// Identifier for the version
    /// For most packages, a number (like "14" or "16") is used. Some packages also use different identifiers, such as "develop".
    let versionIdentifier: String
}
