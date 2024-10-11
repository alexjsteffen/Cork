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
    
    var additionalVersions: [PackageVersion]?
    
}

enum SearchResultConstructionError: LocalizedError
{
    case couldNotCreateHomebrewVersionString
    
    var errorDescription: String?
    {
        switch self {
            case .couldNotCreateHomebrewVersionString:
                "error.package-install.could-not-create-homebrew-version-string"
        }
    }
}

extension SearchResult
{
    func createHomebrewVersionString(fromVersion additionalVersion: PackageVersion?) throws(SearchResultConstructionError) -> String
    {
        if let additionalVersion
        {
            return "\(self.packageName)@\(additionalVersion.versionIdentifier)"
        }
        else
        {
            if self.additionalVersions == nil
            {
                return "\(self.packageName)"
            }
            else
            {
                throw .couldNotCreateHomebrewVersionString
            }
        }
    }
    
    /// Convert the search result to a primitive ``BrewPackage``
    func convertToPackage() -> BrewPackage
    {
        return .init(
            name: self.packageName,
            type: self.packageType,
            installedOn: nil,
            versions: .init(),
            sizeInBytes: nil
        )
    }
}
