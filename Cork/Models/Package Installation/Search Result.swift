//
//  Search Result.swift
//  Cork
//
//  Created by David Bureš on 11.10.2024.
//

import Foundation

/// A search result in the package search, when installing a new package
struct SearchResult: Identifiable, Hashable, Codable
{
    let id: UUID = .init()
    
    let packageName: String
    let packageType: PackageType
    
    var additionalVersions: [String]?
}

extension SearchResult
{
    /// Convert the search result to a primitive ``BrewPackage``
    func convertToPackage() -> BrewPackage
    {
        return .init(
            name: self.packageName,
            type: self.packageType,
            installedOn: nil,
            versions: self.additionalVersions ?? .init(),
            sizeInBytes: nil
        )
    }
}
