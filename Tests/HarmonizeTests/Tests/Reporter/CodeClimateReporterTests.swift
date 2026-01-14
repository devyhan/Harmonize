//
//  CodeClimateReporterTests.swift
//  Harmonize
//
//  Copyright (c) Perry Street Software 2024. All Rights Reserved.
//

import Foundation
import XCTest
@testable import Harmonize

final class CodeClimateReporterTests: XCTestCase {
    let reporter = CodeClimateReporter()
    let projectRoot = URL(fileURLWithPath: "/Users/test/MyProject")

    // MARK: - Static Properties Tests

    func testIdentifier() {
        XCTAssertEqual(CodeClimateReporter.identifier, "codeclimate")
    }

    func testFileExtension() {
        XCTAssertEqual(CodeClimateReporter.fileExtension, "json")
    }

    func testDisplayName() {
        XCTAssertEqual(CodeClimateReporter.displayName, "CodeClimate")
    }

    // MARK: - Report Generation Tests

    func testGenerateEmptyReport() throws {
        let data = try reporter.generateReport(from: [], projectRoot: projectRoot)
        let json = try JSONSerialization.jsonObject(with: data) as? [[String: Any]]

        XCTAssertNotNil(json)
        XCTAssertEqual(json?.count, 0)
    }

    func testGenerateSingleIssueReport() throws {
        let issue = ReportableIssue(
            name: "TestRule",
            message: "Test message",
            line: 10,
            column: 5,
            filePath: URL(fileURLWithPath: "/Users/test/MyProject/Sources/File.swift"),
            severity: .warning
        )

        let data = try reporter.generateReport(from: [issue], projectRoot: projectRoot)
        let json = try JSONSerialization.jsonObject(with: data) as? [[String: Any]]

        XCTAssertNotNil(json)
        XCTAssertEqual(json?.count, 1)

        let firstIssue = json?.first
        XCTAssertEqual(firstIssue?["description"] as? String, "Test message")
        XCTAssertEqual(firstIssue?["check_name"] as? String, "TestRule")
        XCTAssertEqual(firstIssue?["severity"] as? String, "minor")
        XCTAssertNotNil(firstIssue?["fingerprint"])

        let location = firstIssue?["location"] as? [String: Any]
        XCTAssertEqual(location?["path"] as? String, "Sources/File.swift")

        let lines = location?["lines"] as? [String: Any]
        XCTAssertEqual(lines?["begin"] as? Int, 10)
    }

    func testGenerateMultipleIssuesReport() throws {
        let issues = [
            ReportableIssue(
                name: "Rule1",
                message: "Message 1",
                line: 10,
                column: 1,
                filePath: URL(fileURLWithPath: "/Users/test/MyProject/Sources/File1.swift"),
                severity: .warning
            ),
            ReportableIssue(
                name: "Rule2",
                message: "Message 2",
                line: 20,
                column: 1,
                filePath: URL(fileURLWithPath: "/Users/test/MyProject/Sources/File2.swift"),
                severity: .major
            )
        ]

        let data = try reporter.generateReport(from: issues, projectRoot: projectRoot)
        let json = try JSONSerialization.jsonObject(with: data) as? [[String: Any]]

        XCTAssertNotNil(json)
        XCTAssertEqual(json?.count, 2)
    }

    func testSeverityMapping() throws {
        let severities: [ReportableIssue.Severity] = [.info, .minor, .warning, .major, .critical, .blocker]
        let expectedValues = ["info", "minor", "minor", "major", "critical", "blocker"]

        for (severity, expected) in zip(severities, expectedValues) {
            let issue = ReportableIssue(
                name: "TestRule",
                message: "Test",
                line: 1,
                column: 1,
                filePath: URL(fileURLWithPath: "/Users/test/MyProject/File.swift"),
                severity: severity
            )

            let data = try reporter.generateReport(from: [issue], projectRoot: projectRoot)
            let json = try JSONSerialization.jsonObject(with: data) as? [[String: Any]]
            let reportedSeverity = json?.first?["severity"] as? String

            XCTAssertEqual(reportedSeverity, expected, "Severity \(severity) should map to \(expected)")
        }
    }

    func testCategoryIncluded() throws {
        let issue = ReportableIssue(
            name: "TestRule",
            message: "Test message",
            line: 10,
            column: 5,
            filePath: URL(fileURLWithPath: "/Users/test/MyProject/Sources/File.swift"),
            severity: .warning,
            category: "Performance"
        )

        let data = try reporter.generateReport(from: [issue], projectRoot: projectRoot)
        let json = try JSONSerialization.jsonObject(with: data) as? [[String: Any]]
        let categories = json?.first?["categories"] as? [String]

        XCTAssertEqual(categories, ["Performance"])
    }

    func testCategoryNotIncludedWhenNil() throws {
        let issue = ReportableIssue(
            name: "TestRule",
            message: "Test message",
            line: 10,
            column: 5,
            filePath: URL(fileURLWithPath: "/Users/test/MyProject/Sources/File.swift"),
            severity: .warning,
            category: nil
        )

        let data = try reporter.generateReport(from: [issue], projectRoot: projectRoot)
        let json = try JSONSerialization.jsonObject(with: data) as? [[String: Any]]

        XCTAssertNil(json?.first?["categories"])
    }

    // MARK: - JSON Format Tests

    func testJSONIsPrettyPrinted() throws {
        let issue = ReportableIssue(
            name: "TestRule",
            message: "Test message",
            line: 10,
            column: 5,
            filePath: URL(fileURLWithPath: "/Users/test/MyProject/Sources/File.swift")
        )

        let data = try reporter.generateReport(from: [issue], projectRoot: projectRoot)
        let jsonString = String(data: data, encoding: .utf8)

        // Pretty printed JSON contains newlines
        XCTAssertTrue(jsonString?.contains("\n") ?? false)
    }

    func testJSONKeysSorted() throws {
        let issue = ReportableIssue(
            name: "TestRule",
            message: "Test message",
            line: 10,
            column: 5,
            filePath: URL(fileURLWithPath: "/Users/test/MyProject/Sources/File.swift")
        )

        let data = try reporter.generateReport(from: [issue], projectRoot: projectRoot)
        let jsonString = String(data: data, encoding: .utf8) ?? ""

        // Keys should appear in alphabetical order
        let checkNameIndex = jsonString.range(of: "check_name")?.lowerBound
        let descriptionIndex = jsonString.range(of: "description")?.lowerBound
        let fingerprintIndex = jsonString.range(of: "fingerprint")?.lowerBound

        if let c = checkNameIndex, let d = descriptionIndex, let f = fingerprintIndex {
            XCTAssertTrue(c < d, "check_name should come before description")
            XCTAssertTrue(d < f, "description should come before fingerprint")
        }
    }

    // MARK: - Fingerprint Uniqueness Tests

    func testFingerprintUniqueness() throws {
        let issue1 = ReportableIssue(
            name: "Rule1",
            message: "Message 1",
            line: 10,
            column: 1,
            filePath: URL(fileURLWithPath: "/Users/test/MyProject/Sources/File.swift")
        )

        let issue2 = ReportableIssue(
            name: "Rule2",
            message: "Message 2",
            line: 20,
            column: 1,
            filePath: URL(fileURLWithPath: "/Users/test/MyProject/Sources/File.swift")
        )

        let data = try reporter.generateReport(from: [issue1, issue2], projectRoot: projectRoot)
        let json = try JSONSerialization.jsonObject(with: data) as? [[String: Any]]

        let fingerprint1 = json?[0]["fingerprint"] as? String
        let fingerprint2 = json?[1]["fingerprint"] as? String

        XCTAssertNotNil(fingerprint1)
        XCTAssertNotNil(fingerprint2)
        XCTAssertNotEqual(fingerprint1, fingerprint2)
    }
}
