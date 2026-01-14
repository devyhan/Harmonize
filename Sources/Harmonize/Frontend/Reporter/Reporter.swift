//
//  Reporter.swift
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

// MARK: - Reporter Protocol

/// Protocol defining the interface for issue reporters.
///
/// Implement this protocol to create custom reporters that output
/// collected issues in various formats (CodeClimate, Checkstyle, CSV, etc.)
///
/// ## Example Implementation
/// ```swift
/// struct MyCustomReporter: Reporter {
///     static let identifier = "custom"
///     static let fileExtension = "txt"
///
///     func generateReport(from issues: [ReportableIssue], projectRoot: URL) throws -> Data {
///         let content = issues.map { "\($0.filePath):\($0.line) - \($0.message)" }
///             .joined(separator: "\n")
///         return Data(content.utf8)
///     }
/// }
/// ```
public protocol Reporter {
    /// Unique identifier for the reporter (e.g., "codeclimate", "checkstyle", "csv")
    static var identifier: String { get }

    /// File extension for the output file (e.g., "json", "xml", "csv")
    static var fileExtension: String { get }

    /// Display name for logging purposes
    static var displayName: String { get }

    /// Generates report data from collected issues
    /// - Parameters:
    ///   - issues: Array of reportable issues collected during test execution
    ///   - projectRoot: Root directory of the project for relative path calculation
    /// - Returns: Report data in the appropriate format
    func generateReport(from issues: [ReportableIssue], projectRoot: URL) throws -> Data
}

public extension Reporter {
    static var displayName: String { identifier.capitalized }
}

// MARK: - Reportable Issue

/// Represents an issue that can be reported by any reporter.
///
/// This struct contains all information needed to generate reports
/// in various formats.
public struct ReportableIssue {
    /// Name of the declaration or check that triggered the issue
    public let name: String

    /// Human-readable description of the issue
    public let message: String

    /// Line number where the issue was found (1-based)
    public let line: Int

    /// Column number where the issue was found (1-based)
    public let column: Int

    /// Absolute path to the source file
    public let filePath: URL

    /// Severity level of the issue
    public let severity: Severity

    /// Category of the issue for grouping purposes
    public let category: String?

    /// Timestamp when the issue was recorded
    public let timestamp: Date

    public init(
        name: String,
        message: String,
        line: Int,
        column: Int,
        filePath: URL,
        severity: Severity = .warning,
        category: String? = nil,
        timestamp: Date = Date()
    ) {
        self.name = name
        self.message = message
        self.line = line
        self.column = column
        self.filePath = filePath
        self.severity = severity
        self.category = category
        self.timestamp = timestamp
    }

    /// Calculates relative path from project root
    public func relativePath(from projectRoot: URL) -> String {
        let absolutePath = filePath.standardizedFileURL.path
        let rootPath = projectRoot.standardizedFileURL.path

        if absolutePath.hasPrefix(rootPath) {
            var relative = String(absolutePath.dropFirst(rootPath.count))
            if relative.hasPrefix("/") {
                relative = String(relative.dropFirst())
            }
            return relative
        }
        return filePath.lastPathComponent
    }

    /// Generates a unique fingerprint for deduplication
    public func fingerprint(projectRoot: URL) -> String {
        let path = relativePath(from: projectRoot)
        let components = [path, String(line), String(column), name, message]
        let combined = components.joined(separator: ":")

        // Simple hash-based fingerprint
        var hash: UInt64 = 5381
        for char in combined.utf8 {
            hash = ((hash << 5) &+ hash) &+ UInt64(char)
        }
        return String(format: "%016llx", hash)
    }
}

// MARK: - Severity

public extension ReportableIssue {
    /// Severity levels for issues, aligned with common CI/CD tools
    enum Severity: String, CaseIterable, Sendable {
        case info
        case minor
        case warning
        case major
        case critical
        case blocker

        /// CodeClimate compatible severity string
        public var codeClimateValue: String {
            switch self {
            case .info: return "info"
            case .minor: return "minor"
            case .warning: return "minor"
            case .major: return "major"
            case .critical: return "critical"
            case .blocker: return "blocker"
            }
        }

        /// Checkstyle compatible severity string
        public var checkstyleValue: String {
            switch self {
            case .info: return "info"
            case .minor, .warning: return "warning"
            case .major, .critical, .blocker: return "error"
            }
        }
    }
}

// MARK: - Reporter Error

public enum ReporterError: Error, LocalizedError {
    case reporterNotFound(String)
    case exportFailed(String)
    case noIssuesCollected
    case invalidOutputPath(String)
    case encodingFailed(String)

    public var errorDescription: String? {
        switch self {
        case .reporterNotFound(let identifier):
            return "Reporter '\(identifier)' not found. Available reporters: \(ReporterRegistry.shared.availableReporters.joined(separator: ", "))"
        case .exportFailed(let reason):
            return "Failed to export report: \(reason)"
        case .noIssuesCollected:
            return "No issues were collected during test execution"
        case .invalidOutputPath(let path):
            return "Invalid output path: \(path)"
        case .encodingFailed(let reason):
            return "Failed to encode report: \(reason)"
        }
    }
}
