//
//  Search for Package.swift
//  Cork
//
//  Created by David Bureš on 05.02.2023.
//

import Foundation
import CorkShared


/// Search for a package by specified name
/// - Parameter packageName: Name of the package to look up
/// - Returns: Tuple of two ``[SearchResult]``s, first being the found formulae, second the found casks
func searchForPackage(packageName: String) async -> (formulae: [SearchResult], casks: [SearchResult])
{
    async let formulaSearchResults: TerminalOutput = await shell(AppConstants.brewExecutablePath, ["search", "--formulae", packageName])
    async let caskSearchResults: TerminalOutput = await shell(AppConstants.brewExecutablePath, ["search", "--casks", packageName])
    
    let foundFormulaNames: [String] = await formulaSearchResults.standardOutput.components(separatedBy: "\n")
    let foundCaskNames: [String] = await caskSearchResults.standardOutput.components(separatedBy: "\n")
    
    async let processedFormulae: [SearchResult] = await processSearchResults(packageNameArray: foundFormulaNames, packageType: .formula)
    async let processedCasks: [SearchResult] = await processSearchResults(packageNameArray: foundCaskNames, packageType: .cask)
    
    return (await processedFormulae, await processedCasks)
}

/// Take the raw array of found packages and transform it into a structured array of ``SearchResult``s
private func processSearchResults(packageNameArray: [String], packageType: PackageType) async -> [SearchResult]
{
    var finalArray: [SearchResult] = .init()
    
    for packageName in packageNameArray
    {
        /// Make sure there actually is a search result to place
        guard !packageName.isEmpty else
        {
            continue
        }
        
        guard let splitPackageNameAndVersion = packageName.splitPackageNameAndVersion else
        {
            /// If the split fails, just append it as-is
            finalArray.append(.init(packageName: packageName, packageType: packageType, additionalVersions: .init()))
            continue
        }
        
        /// Let's see if this package was already found before
        if let indexOfPreviouslyFoundPackage = finalArray.firstIndex(where: { $0.packageName == splitPackageNameAndVersion.packageName })
        { /// Yes, it was found before. Let's just append its version
            if let additionalVersion = splitPackageNameAndVersion.additionalVersion
            {
                if finalArray[indexOfPreviouslyFoundPackage].additionalVersions == nil
                {
                    finalArray[indexOfPreviouslyFoundPackage].additionalVersions = [additionalVersion]
                }
                else
                {
                    finalArray[indexOfPreviouslyFoundPackage].additionalVersions?.append(additionalVersion)
                }
            }
        }
        else
        { /// No, it was not found before. Let's create it
            if let additionalVersion = splitPackageNameAndVersion.additionalVersion
            {
                finalArray.append(
                    .init(
                        packageName: splitPackageNameAndVersion.packageName,
                        packageType: packageType,
                        additionalVersions: [additionalVersion]
                    )
                )
            }
            else
            {
                finalArray.append(
                    .init(
                        packageName: splitPackageNameAndVersion.packageName,
                        packageType: packageType,
                        additionalVersions: nil
                    )
                )
            }
        }
    }
    
    return finalArray
}

private extension String
{
    var splitPackageNameAndVersion: (packageName: String, additionalVersion: String?)?
    {
        if self.contains("@")
        {
            let splitName: [String] = self.components(separatedBy: "@")
            
            guard let packageName = splitName.first, let packageVersion = splitName.last else
            {
                return nil
            }
            
            return (packageName, packageVersion)
        }
        else
        {
            return (self, nil)
        }
    }
}
