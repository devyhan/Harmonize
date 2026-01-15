//
//  ReporterRegistry.swift
//  Harmonize
//
//  Copyright 2024 Perry Street Software Inc.

//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at

//  http://www.apache.org/licenses/LICENSE-2.0

//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//  See the License for the specific language governing permissions and
//  limitations under the License.
//

import Foundation

// MARK: - Reporter Registry

/// Central registry for managing available reporters.
///
/// Use this class to register custom reporters or retrieve built-in ones.
///
/// ## Built-in Reporters
/// - `codeclimate`: GitLab/CodeClimate compatible JSON format
///
/// ## Registering Custom Reporters
/// ```swift
/// // Register at app startup or test setup
/// ReporterRegistry.shared.register(MyCustomReporter())
///
/// // Use environment variable to select reporter
/// // HARMONIZE_REPORTER=custom
/// ```
///
/// ## Environment Variables
/// - `HARMONIZE_REPORTER`: Reporter identifier to use (default: none, XCTest only)
/// - `HARMONIZE_OUTPUT_PATH`: Custom output path for report file
/// - `HARMONIZE_PROJECT_ROOT`: Override project root for relative paths
public final class ReporterRegistry: @unchecked Sendable {
    public static let shared = ReporterRegistry()

    private var reporters: [String: any Reporter] = [:]
    private let lock = NSLock()

    private init() {
        // Register built-in reporters
        register(CodeClimateReporter())
    }

    // MARK: - Registration

    /// Registers a reporter instance.
    /// - Parameter reporter: Reporter instance to register
    public func register<R: Reporter>(_ reporter: R) {
        lock.lock()
        defer { lock.unlock() }
        reporters[R.identifier] = reporter
    }

    /// Unregisters a reporter by identifier.
    /// - Parameter identifier: Reporter identifier to remove
    public func unregister(_ identifier: String) {
        lock.lock()
        defer { lock.unlock() }
        reporters.removeValue(forKey: identifier)
    }

    // MARK: - Retrieval

    /// Returns a reporter by identifier.
    /// - Parameter identifier: Reporter identifier
    /// - Returns: Reporter instance if found
    public func reporter(for identifier: String) -> (any Reporter)? {
        lock.lock()
        defer { lock.unlock() }
        return reporters[identifier]
    }

    /// Returns the reporter specified by environment variable.
    /// - Returns: Reporter instance if `HARMONIZE_REPORTER` is set and valid
    public func environmentReporter() -> (any Reporter)? {
        guard let identifier = ProcessInfo.processInfo.environment["HARMONIZE_REPORTER"] else {
            return nil
        }
        return reporter(for: identifier.lowercased())
    }

    /// List of available reporter identifiers.
    public var availableReporters: [String] {
        lock.lock()
        defer { lock.unlock() }
        return Array(reporters.keys).sorted()
    }

    // MARK: - Export

    /// Exports issues using the specified reporter.
    /// - Parameters:
    ///   - identifier: Reporter identifier
    ///   - issues: Issues to export
    ///   - outputPath: Optional custom output path
    ///   - projectRoot: Optional custom project root
    /// - Returns: Path to the generated report file
    @discardableResult
    public func export(
        using identifier: String,
        issues: [ReportableIssue],
        outputPath: String? = nil,
        projectRoot: URL? = nil
    ) throws -> URL {
        guard let reporter = reporter(for: identifier) else {
            throw ReporterError.reporterNotFound(identifier)
        }

        return try export(
            using: reporter,
            issues: issues,
            outputPath: outputPath,
            projectRoot: projectRoot
        )
    }

    /// Exports issues using the provided reporter instance.
    /// - Parameters:
    ///   - reporter: Reporter instance to use
    ///   - issues: Issues to export
    ///   - outputPath: Optional custom output path
    ///   - projectRoot: Optional custom project root
    /// - Returns: Path to the generated report file
    @discardableResult
    public func export(
        using reporter: any Reporter,
        issues: [ReportableIssue],
        outputPath: String? = nil,
        projectRoot: URL? = nil
    ) throws -> URL {
        let root = resolveProjectRoot(override: projectRoot)
        let output = resolveOutputPath(
            override: outputPath,
            reporterIdentifier: type(of: reporter).identifier,
            fileExtension: type(of: reporter).fileExtension
        )

        let data = try reporter.generateReport(from: issues, projectRoot: root)

        do {
            try data.write(to: output)
            return output
        } catch {
            throw ReporterError.exportFailed(error.localizedDescription)
        }
    }

    // MARK: - Path Resolution

    private func resolveProjectRoot(override: URL?) -> URL {
        if let override = override {
            return override
        }

        if let envPath = ProcessInfo.processInfo.environment["HARMONIZE_PROJECT_ROOT"] {
            return URL(fileURLWithPath: envPath)
        }

        // Attempt to find project root by looking for common markers
        let currentDir = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        return findProjectRoot(from: currentDir) ?? currentDir
    }

    private func resolveOutputPath(
        override: String?,
        reporterIdentifier: String,
        fileExtension: String
    ) -> URL {
        if let override = override {
            return URL(fileURLWithPath: override)
        }

        if let envPath = ProcessInfo.processInfo.environment["HARMONIZE_OUTPUT_PATH"] {
            return URL(fileURLWithPath: envPath)
        }

        let filename = "harmonize_\(reporterIdentifier).\(fileExtension)"
        let currentDir = FileManager.default.currentDirectoryPath
        return URL(fileURLWithPath: currentDir).appendingPathComponent(filename)
    }

    private func findProjectRoot(from directory: URL) -> URL? {
        let markers = ["Package.swift", ".git", ".harmonize.yaml", "*.xcworkspace", "*.xcodeproj"]
        var current = directory

        for _ in 0..<10 { // Limit search depth
            for marker in markers {
                if marker.contains("*") {
                    // Glob pattern
                    let pattern = marker.replacingOccurrences(of: "*", with: "")
                    if let contents = try? FileManager.default.contentsOfDirectory(atPath: current.path),
                       contents.contains(where: { $0.hasSuffix(pattern) }) {
                        return current
                    }
                } else {
                    let markerPath = current.appendingPathComponent(marker)
                    if FileManager.default.fileExists(atPath: markerPath.path) {
                        return current
                    }
                }
            }

            let parent = current.deletingLastPathComponent()
            if parent.path == current.path {
                break
            }
            current = parent
        }

        return nil
    }
}

// MARK: - Convenience Extensions

public extension ReporterRegistry {
    /// Checks if reporting is enabled via environment variable or manual override.
    var isReportingEnabled: Bool {
        _reportingEnabled || environmentReporter() != nil
    }

    /// Default output filename based on environment reporter.
    var defaultOutputFilename: String? {
        guard let reporter = environmentReporter() else { return nil }
        return "harmonize_\(type(of: reporter).identifier).\(type(of: reporter).fileExtension)"
    }

    /// Programmatically enables issue collection.
    /// Call this in test setup when environment variables are not available.
    func enableReporting() {
        _reportingEnabled = true
    }

    /// Disables issue collection.
    func disableReporting() {
        _reportingEnabled = false
    }
}

// MARK: - Internal State

private var _reportingEnabled = false
