//
//  Package Preview.swift
//  Cork
//
//  Created by David Bureš on 25.08.2024.
//

import SwiftUI

struct PackagePreview: View
{

    let searchResult: SearchResult?

    var body: some View
    {
        if let searchResult
        {
            PackageDetailView(package: searchResult.convertToPackage())
                .isPreview()
                .fixedSize()
        }
    }
}
