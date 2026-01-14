//
//  CodeClimateReporter.swift
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

// MARK: - CodeClimate Reporter

/// Reporter that generates CodeClimate-compatible JSON output.
///
/// This format is compatible with:
/// - GitLab Code Quality
/// - CodeClimate
/// - Other CI/CD tools that support the CodeClimate format
///
/// ## Output Format
/// ```json
/// [
///   {
///     "description": "Issue message",
///     "check_name": "RuleName",
///     "fingerprint": "unique_hash",
///     "severity": "warning",
///     "location": {
///       "path": "relative/path/to/file.swift",
///       "lines": {
///         "begin": 10
///       }
///     }
///   }
/// ]
/// ```
///
/// ## Usage
/// Set environment variable: `HARMONIZE_REPORTER=codeclimate`
public struct CodeClimateReporter: Reporter {
    public static let identifier = "codeclimate"
    public static let fileExtension = "json"
    public static let displayName = "CodeClimate"

    public init() {}

    public func generateReport(from issues: [ReportableIssue], projectRoot: URL) throws -> Data {
        let codeClimateIssues = issues.map { issue -> [String: Any] in
            let relativePath = issue.relativePath(from: projectRoot)

            var issueDict: [String: Any] = [
                "description": issue.message,
                "check_name": issue.name,
                "fingerprint": issue.fingerprint(projectRoot: projectRoot),
                "severity": issue.severity.codeClimateValue,
                "location": [
                    "path": relativePath,
                    "lines": [
                        "begin": issue.line
                    ]
                ]
            ]

            // Add optional category if present
            if let category = issue.category {
                issueDict["categories"] = [category]
            }

            return issueDict
        }

        do {
            let data = try JSONSerialization.data(
                withJSONObject: codeClimateIssues,
                options: [.prettyPrinted, .sortedKeys]
            )
            return data
        } catch {
            throw ReporterError.encodingFailed(error.localizedDescription)
        }
    }
}

// MARK: - CodeClimate Specific Extensions

public extension CodeClimateReporter {
    /// Generates report with custom severity mapping.
    /// - Parameters:
    ///   - issues: Issues to report
    ///   - projectRoot: Project root for relative paths
    ///   - severityMapper: Custom function to map issue names to severities
    /// - Returns: JSON data
    func generateReport(
        from issues: [ReportableIssue],
        projectRoot: URL,
        severityMapper: (String) -> ReportableIssue.Severity
    ) throws -> Data {
        let mappedIssues = issues.map { issue in
            ReportableIssue(
                name: issue.name,
                message: issue.message,
                line: issue.line,
                column: issue.column,
                filePath: issue.filePath,
                severity: severityMapper(issue.name),
                category: issue.category,
                timestamp: issue.timestamp
            )
        }

        return try generateReport(from: mappedIssues, projectRoot: projectRoot)
    }
}
