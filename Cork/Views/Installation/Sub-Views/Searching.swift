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
                let searchResults: (formulae: [SearchResult], casks: [SearchResult]) = await searchForPackage(packageName: packageRequested)
                
                searchResultTracker.foundFormulae = searchResults.formulae
                searchResultTracker.foundCasks = searchResults.casks
                
                packageInstallationProcessStep = .presentingSearchResults
            }
    }
}
