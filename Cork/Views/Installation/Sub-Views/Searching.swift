//
//  Searching View.swift
//  Cork
//
//  Created by David Bureš on 20.08.2023.
//

import SwiftUI

struct InstallationSearchingView: View, Sendable
{
    @Binding var packageRequested: String

    @ObservedObject var searchResultTracker: SearchResultTracker

    @Binding var packageInstallationProcessStep: PackageInstallationProcessSteps

    var body: some View
    {
        ProgressView("add-package.searching-\(packageRequested)")
            .task
            {                
                async let foundFormulae: [String] = searchForPackage(packageName: packageRequested, packageType: .formula)
                async let foundCasks: [String] = searchForPackage(packageName: packageRequested, packageType: .cask)
                
                for formula in await foundFormulae
                {
                    searchResultTracker.foundFormulae.append(.init(packageName: formula, packageType: .formula, versions: .init()))
                }
                for cask in await foundCasks
                {
                    searchResultTracker.foundFormulae.append(.init(packageName: cask, packageType: .cask, versions: .init()))
                }
                
                packageInstallationProcessStep = .presentingSearchResults
            }
    }
}
