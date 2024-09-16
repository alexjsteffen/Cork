//
//  Get Contents of Folder.swift
//  Cork
//
//  Created by David Bureš on 03.07.2022.
//

import Foundation
import SwiftUI

enum PackageLoadingError: LocalizedError
{
    case failedWhileLoadingPackages(failureReason: String?), failedWhileLoadingCertainPackage(String, URL, failureReason: String), packageDoesNotHaveAnyVersionsInstalled(String), packageIsNotAFolder(String, URL)

    var errorDescription: String?
    {
        switch self
        {
        case .failedWhileLoadingPackages(let failureReason):
            if let failureReason
            {
                return String(localized: "error.package-loading.could-not-load-packages.\(failureReason)")
            }
            else
            {
                return String(localized: "error.package-loading.could-not-load-packages")
            }
        case .failedWhileLoadingCertainPackage(let string, let uRL, let failureReason):
            return String(localized: "error.package-loading.could-not-load-\(string)-at-\(uRL.absoluteString)-because-\(failureReason)", comment: "Couldn't load package (package name) at (package URL) because (failure reason)")
        case .packageDoesNotHaveAnyVersionsInstalled(let string):
            return String(localized: "error.package-loading.\(string)-does-not-have-any-versions-installed")
        case .packageIsNotAFolder(let string, _):
            return String(localized: "error.package-loading.\(string)-not-a-folder", comment: "Package folder in this context means a folder that encloses package versions. Every package has its own folder, and this error occurs when the provided URL does not point to a folder that encloses package versions")
        }
    }
}

func getContentsOfFolder(targetFolder: URL) async throws -> Set<BrewPackage>
{
    do
    {
        guard let items = targetFolder.validPackageURLs
        else
        {
            throw PackageLoadingError.failedWhileLoadingPackages(failureReason: String(localized: "alert.fatal.could-not-filter-invalid-packages"))
        }

        let loadedPackages: Set<BrewPackage> = try await withThrowingTaskGroup(of: BrewPackage.self, returning: Set<BrewPackage>.self)
        { taskGroup in
            for item in items
            {
                let fullURLToPackageFolderCurrentlyBeingProcessed: URL = targetFolder.appendingPathComponent(item, conformingTo: .folder)

                taskGroup.addTask(priority: .high)
                {
                    guard let versionURLs: [URL] = fullURLToPackageFolderCurrentlyBeingProcessed.packageVersionURLs
                    else
                    {
                        if targetFolder.appendingPathComponent(item, conformingTo: .fileURL).isDirectory
                        {
                            AppConstants.logger.error("Failed while getting package version for package \(fullURLToPackageFolderCurrentlyBeingProcessed.lastPathComponent). Package does not have any version installed.")
                            throw PackageLoadingError.packageDoesNotHaveAnyVersionsInstalled(item)
                        }
                        else
                        {
                            AppConstants.logger.error("Failed while getting package version for package \(fullURLToPackageFolderCurrentlyBeingProcessed.lastPathComponent). Package is not a folder")
                            throw PackageLoadingError.packageIsNotAFolder(item, targetFolder.appendingPathComponent(item, conformingTo: .fileURL))
                        }
                    }

                    do
                    {
                        if versionURLs.isEmpty
                        {
                            throw PackageLoadingError.packageDoesNotHaveAnyVersionsInstalled(item)
                        }

                        let wasPackageInstalledIntentionally: Bool = try await targetFolder.checkIfPackageWasInstalledIntentionally(versionURLs)

                        let foundPackage: BrewPackage = .init(
                            name: item,
                            type: targetFolder.packageType,
                            installedOn: fullURLToPackageFolderCurrentlyBeingProcessed.creationDate,
                            versions: versionURLs.versions,
                            installedIntentionally: wasPackageInstalledIntentionally,
                            sizeInBytes: fullURLToPackageFolderCurrentlyBeingProcessed.directorySize
                        )

                        return foundPackage
                    }
                    catch
                    {
                        throw error
                    }
                }
            }

            var loadedPackages: Set<BrewPackage> = .init()
            for try await package in taskGroup
            {
                loadedPackages.insert(package)
            }
            return loadedPackages
        }

        return loadedPackages
    }
    catch
    {
        AppConstants.logger.error("Failed while accessing folder: \(error)")
        throw error
    }
}

// MARK: - Sub-functions

private extension URL
{
    /// ``[URL]`` to packages without hidden files or symlinks.
    /// e.g. only actual package URLs
    var validPackageURLs: [String]?
    {
        let items: [String]? = try? FileManager.default.contentsOfDirectory(atPath: path).filter { !$0.hasPrefix(".") }.filter
        { item in
            /// Filter out all symlinks from the folder
            let completeURLtoItem: URL = self.appendingPathComponent(item, conformingTo: .folder)

            guard let isSymlink = completeURLtoItem.isSymlink()
            else
            {
                return false
            }

            return !isSymlink
        }

        return items
    }

    /// This function checks whether the package was installed intentionally.
    /// - For Formulae, this info gets read from the install receipt
    /// - Casks are always instaled intentionally
    /// - Parameter versionURLs: All available versions for this package. Some packages have multiple versions installed at a time (for example, the package `xz` might have versions 1.2 and 1.3 installed at once)
    /// - Returns: Indication whether this package was installed intentionally or not
    func checkIfPackageWasInstalledIntentionally(_ versionURLs: [URL]) async throws -> Bool
    {
        guard let localPackagePath = versionURLs.first
        else
        {
            throw PackageLoadingError.failedWhileLoadingCertainPackage(lastPathComponent, self, failureReason: String(localized: "error.package-loading.could-not-load-version-to-check-from-available-versions"))
        }

        guard localPackagePath.lastPathComponent != "Cellar"
        else
        {
            AppConstants.logger.error("The last path component of the requested URL is the package container folder itself - perhaps a misconfigured package folder? Tried to load URL \(localPackagePath)")

            throw PackageLoadingError.failedWhileLoadingPackages(failureReason: String(localized: "error.package-loading.last-path-component-of-checked-package-url-is-folder-containing-packages-itself.formulae"))
        }

        guard localPackagePath.lastPathComponent != "Caskroom"
        else
        {
            AppConstants.logger.error("The last path component of the requested URL is the package container folder itself - perhaps a misconfigured package folder? Tried to load URL \(localPackagePath)")

            throw PackageLoadingError.failedWhileLoadingPackages(failureReason: String(localized: "error.package-loading.last-path-component-of-checked-package-url-is-folder-containing-packages-itself.casks"))
        }

        if path.contains("Cellar")
        {
            let localPackageInfoJSONPath: URL = localPackagePath.appendingPathComponent("INSTALL_RECEIPT.json", conformingTo: .json)
            if FileManager.default.fileExists(atPath: localPackageInfoJSONPath.path)
            {
                struct InstallRecepitParser: Codable
                {
                    let installedOnRequest: Bool
                }

                let decoder: JSONDecoder = {
                    let decoder: JSONDecoder = .init()
                    decoder.keyDecodingStrategy = .convertFromSnakeCase

                    return decoder
                }()

                do
                {
                    let installReceiptContents: Data = try .init(contentsOf: localPackageInfoJSONPath)

                    do
                    {
                        return try decoder.decode(InstallRecepitParser.self, from: installReceiptContents).installedOnRequest
                    }
                    catch let installReceiptParsingError
                    {
                        AppConstants.logger.error("Failed to decode install receipt for package \(self.lastPathComponent, privacy: .public) with error \(installReceiptParsingError.localizedDescription, privacy: .public)")

                        throw PackageLoadingError.failedWhileLoadingCertainPackage(self.lastPathComponent, self, failureReason: String(localized: "error.package-loading.could-not-decode-installa-receipt-\(installReceiptParsingError.localizedDescription)"))
                    }
                }
                catch let installReceiptLoadingError
                {
                    AppConstants.logger.error("Failed to load contents of install receipt for package \(self.lastPathComponent, privacy: .public) with error \(installReceiptLoadingError.localizedDescription, privacy: .public)")
                    throw PackageLoadingError.failedWhileLoadingCertainPackage(self.lastPathComponent, self, failureReason: String(localized: "error.package-loading.could-not-convert-contents-of-install-receipt-to-data-\(installReceiptLoadingError.localizedDescription)"))
                }
            }
            else
            { /// There's no install receipt for this package - silently fail and return that the packagw was not installed intentionally
                // TODO: Add a setting like "Strictly check for errors" that would instead throw an error here

                AppConstants.logger.error("There appears to be no install receipt for package \(localPackageInfoJSONPath.lastPathComponent, privacy: .public)")

                let shouldStrictlyCheckForHomebrewErrors: Bool = UserDefaults.standard.bool(forKey: "strictlyCheckForHomebrewErrors")

                if shouldStrictlyCheckForHomebrewErrors
                {
                    throw PackageLoadingError.failedWhileLoadingCertainPackage(lastPathComponent, self, failureReason: String(localized: "error.package-loading.missing-install-receipt"))
                }
                else
                {
                    return false
                }
            }
        }
        else if path.contains("Caskroom")
        {
            return true
        }
        else
        {
            throw PackageLoadingError.failedWhileLoadingCertainPackage(lastPathComponent, self, failureReason: String(localized: "error.package-loading.unexpected-folder-name"))
        }
    }

    /// Determine a package's type type from its URL
    var packageType: PackageType
    {
        if path.contains("Cellar")
        {
            return .formula
        }
        else
        {
            return .cask
        }
    }

    /// Get URLs to a package's versions
    var packageVersionURLs: [URL]?
    {
        AppConstants.logger.debug("Will check URL \(self)")
        do
        {
            let versions: [URL] = try FileManager.default.contentsOfDirectory(at: self, includingPropertiesForKeys: [.isHiddenKey], options: .skipsHiddenFiles)

            if versions.isEmpty
            {
                AppConstants.logger.warning("Package URL \(self, privacy: .public) has no versions installed")

                return nil
            }

            AppConstants.logger.debug("URL \(self) has these versions: \(versions))")

            return versions
        }
        catch
        {
            AppConstants.logger.error("Failed while loading version for package \(lastPathComponent, privacy: .public) at URL \(self, privacy: .public)")

            return nil
        }
    }
}

extension [URL]
{
    /// Returns an array of versions from an array of URLs to available versions
    var versions: [String]
    {
        return map
        { versionURL in
            versionURL.lastPathComponent
        }
    }
}

// MARK: - Getting list of URLs in folder

func getContentsOfFolder(targetFolder: URL, options: FileManager.DirectoryEnumerationOptions? = nil) -> [URL]
{
    var contentsOfFolder: [URL] = .init()

    do
    {
        if let options
        {
            contentsOfFolder = try FileManager.default.contentsOfDirectory(at: targetFolder, includingPropertiesForKeys: nil, options: options)
        }
        else
        {
            contentsOfFolder = try FileManager.default.contentsOfDirectory(at: targetFolder, includingPropertiesForKeys: nil)
        }
    }
    catch let folderReadingError as NSError
    {
        AppConstants.logger.error("\(folderReadingError.localizedDescription)")
    }

    return contentsOfFolder
}
