//
//  IssueCollector.swift
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

// MARK: - Issue Collector

/// Thread-safe singleton for collecting issues during test execution.
///
/// Issues are automatically collected when Harmonize assertions fail.
/// Use `export()` after test execution to generate reports.
///
/// ## Usage in CI/CD
/// ```swift
/// // In your test teardown or a dedicated export test
/// override class func tearDown() {
///     try? IssueCollector.shared.export()
///     super.tearDown()
/// }
/// ```
///
/// ## Environment Variables
/// - `HARMONIZE_REPORTER`: Enables collection and specifies output format
/// - `HARMONIZE_OUTPUT_PATH`: Custom output file path
/// - `HARMONIZE_PROJECT_ROOT`: Override project root detection
public final class IssueCollector: @unchecked Sendable {
    public static let shared = IssueCollector()

    private var issues: [ReportableIssue] = []
    private let lock = NSLock()
    private var _projectRoot: URL?

    private init() {}

    // MARK: - Collection

    /// Collects an issue for later reporting.
    /// - Parameter issue: Issue to collect
    ///
    /// Issues are only collected when `HARMONIZE_REPORTER` environment variable is set.
    public func collect(_ issue: ReportableIssue) {
        guard ReporterRegistry.shared.isReportingEnabled else { return }

        lock.lock()
        defer { lock.unlock() }
        issues.append(issue)
    }

    /// Collects multiple issues at once.
    /// - Parameter newIssues: Issues to collect
    public func collect(_ newIssues: [ReportableIssue]) {
        guard ReporterRegistry.shared.isReportingEnabled else { return }

        lock.lock()
        defer { lock.unlock() }
        issues.append(contentsOf: newIssues)
    }

    // MARK: - Retrieval

    /// Returns all collected issues.
    public var collectedIssues: [ReportableIssue] {
        lock.lock()
        defer { lock.unlock() }
        return issues
    }

    /// Returns the number of collected issues.
    public var count: Int {
        lock.lock()
        defer { lock.unlock() }
        return issues.count
    }

    /// Returns whether any issues have been collected.
    public var hasIssues: Bool {
        lock.lock()
        defer { lock.unlock() }
        return !issues.isEmpty
    }

    // MARK: - Configuration

    /// Sets the project root directory for relative path calculation.
    /// - Parameter root: Project root URL
    public func setProjectRoot(_ root: URL) {
        lock.lock()
        defer { lock.unlock() }
        _projectRoot = root
    }

    /// Current project root, auto-detected if not explicitly set.
    public var projectRoot: URL {
        lock.lock()
        defer { lock.unlock() }

        if let root = _projectRoot {
            return root
        }

        return URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    }

    // MARK: - Export

    /// Exports collected issues using the environment-specified reporter.
    ///
    /// This method does nothing if:
    /// - `HARMONIZE_REPORTER` environment variable is not set
    /// - No issues were collected
    ///
    /// - Parameter outputPath: Optional custom output path
    /// - Returns: Path to the generated report file, or nil if no export occurred
    @discardableResult
    public func export(to outputPath: String? = nil) throws -> URL? {
        guard let reporter = ReporterRegistry.shared.environmentReporter() else {
            return nil
        }

        let issuesToExport: [ReportableIssue]
        let root: URL

        lock.lock()
        issuesToExport = issues
        root = _projectRoot ?? URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        lock.unlock()

        guard !issuesToExport.isEmpty else {
            return nil
        }

        return try ReporterRegistry.shared.export(
            using: reporter,
            issues: issuesToExport,
            outputPath: outputPath,
            projectRoot: root
        )
    }

    /// Exports collected issues using a specific reporter.
    /// - Parameters:
    ///   - identifier: Reporter identifier
    ///   - outputPath: Optional custom output path
    /// - Returns: Path to the generated report file
    @discardableResult
    public func export(using identifier: String, to outputPath: String? = nil) throws -> URL {
        let issuesToExport: [ReportableIssue]
        let root: URL

        lock.lock()
        issuesToExport = issues
        root = _projectRoot ?? URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        lock.unlock()

        return try ReporterRegistry.shared.export(
            using: identifier,
            issues: issuesToExport,
            outputPath: outputPath,
            projectRoot: root
        )
    }

    // MARK: - Reset

    /// Clears all collected issues.
    public func clear() {
        lock.lock()
        defer { lock.unlock() }
        issues.removeAll()
    }

    /// Clears collected issues and resets configuration.
    public func reset() {
        lock.lock()
        defer { lock.unlock() }
        issues.removeAll()
        _projectRoot = nil
    }
}

// MARK: - CodeIssue Conversion

internal extension IssueCollector {
    /// Converts internal CodeIssue to public ReportableIssue and collects it.
    func collect(from codeIssue: CodeIssue, severity: ReportableIssue.Severity = .warning, category: String? = nil) {
        let reportableIssue = ReportableIssue(
            name: codeIssue.name,
            message: codeIssue.message,
            line: codeIssue.line,
            column: codeIssue.column,
            filePath: codeIssue.filePath,
            severity: severity,
            category: category
        )
        collect(reportableIssue)
    }

    /// Converts multiple internal CodeIssues to ReportableIssues and collects them.
    func collect(from codeIssues: [CodeIssue], severity: ReportableIssue.Severity = .warning, category: String? = nil) {
        let reportableIssues = codeIssues.map { codeIssue in
            ReportableIssue(
                name: codeIssue.name,
                message: codeIssue.message,
                line: codeIssue.line,
                column: codeIssue.column,
                filePath: codeIssue.filePath,
                severity: severity,
                category: category
            )
        }
        collect(reportableIssues)
    }
}
