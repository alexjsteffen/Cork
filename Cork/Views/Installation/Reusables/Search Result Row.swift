//
//  Search Result Row.swift
//  Cork
//
//  Created by David Bureš on 12.02.2023.
//

import SwiftUI
import CorkShared

struct SearchResultRow: View, Sendable
{
    @AppStorage("showDescriptionsInSearchResults") var showDescriptionsInSearchResults: Bool = false
    @AppStorage("showCompatibilityWarning") var showCompatibilityWarning: Bool = true

    @EnvironmentObject var brewData: BrewDataStorage

    let searchResult: SearchResult

    @State private var description: String?
    @State private var isCompatible: Bool?

    @State private var isLoadingDescription: Bool = true
    @State private var descriptionParsingFailed: Bool = false

    var body: some View
    {
        VStack(alignment: .leading)
        {
            HStack(alignment: .center)
            {
                SanitizedPackageName(packageName: searchResult.packageName, shouldShowVersion: true)
                
                if let additionalVersions = searchResult.additionalVersions
                {
                    Text(additionalVersions.joined(separator: ", "))
                }

                if searchResult.packageType == .formula
                {
                    if brewData.installedFormulae.contains(where: { $0.name == searchResult.packageName })
                    {
                        PillTextWithLocalizableText(localizedText: "add-package.result.already-installed")
                    }
                }
                else
                {
                    if brewData.installedCasks.contains(where: { $0.name == searchResult.packageName })
                    {
                        PillTextWithLocalizableText(localizedText: "add-package.result.already-installed")
                    }
                }

                if let isCompatible
                {
                    if !isCompatible
                    {
                        if showCompatibilityWarning
                        {
                            HStack(alignment: .center, spacing: 4)
                            {
                                Image(systemName: "exclamationmark.circle")
                                Text("add-package.result.not-optimized-for-\(AppConstants.osVersionString.fullName)")
                            }
                            .font(.subheadline)
                            .foregroundColor(.red)
                        }
                    }
                }
            }

            if showDescriptionsInSearchResults
            {
                if !descriptionParsingFailed
                { // Show this if the description got properly parsed
                    if isLoadingDescription
                    {
                        Text("add-package.result.loading-description")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    else
                    {
                        if let description
                        {
                            Text(description)
                                .font(.caption)
                        }
                        else
                        {
                            NoDescriptionProvidedView()
                        }
                    }
                }
                else
                { // Otherwise, tell the user the parsing failed
                    Text("add-package.result.loading-failed")
                        .font(.caption)
                        .foregroundColor(.orange)
                }
            }
        }
        .task
        {
            if showDescriptionsInSearchResults
            {
                AppConstants.logger.info("\(searchResult.packageName, privacy: .auto) came into view")

                if description == nil
                {
                    defer
                    {
                        isLoadingDescription = false
                    }

                    AppConstants.logger.info("\(searchResult.packageName, privacy: .auto) does not have its description loaded")

                    do
                    {
                        let searchedForPackage: BrewPackage = .init(name: searchResult.packageName, type: searchResult.packageType, installedOn: Date(), versions: [], sizeInBytes: nil)

                        do
                        {
                            let parsedPackageInfo: BrewPackageDetails = try await searchedForPackage.loadDetails()

                            description = parsedPackageInfo.description

                            isCompatible = parsedPackageInfo.isCompatible
                        }
                        catch let descriptionParsingError
                        { // This happens when a package doesn' have any description at all, hence why we don't display an error
                            AppConstants.logger.error("Failed while parsing searched-for package info: \(descriptionParsingError.localizedDescription, privacy: .public)")

                            descriptionParsingFailed = true
                        }
                    }
                }
                else
                {
                    AppConstants.logger.info("\(searchResult.packageName, privacy: .auto) already has its description loaded")
                }
            }
        }
    }
}
