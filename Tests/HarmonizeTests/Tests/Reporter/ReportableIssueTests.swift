//
//  ReportableIssueTests.swift
//  Harmonize
//
//  Copyright (c) Perry Street Software 2024. All Rights Reserved.
//

import Foundation
import XCTest
@testable import Harmonize

final class ReportableIssueTests: XCTestCase {
    let projectRoot = URL(fileURLWithPath: "/Users/test/MyProject")

    func testReportableIssueInitialization() {
        let issue = ReportableIssue(
            name: "TestRule",
            message: "Test message",
            line: 10,
            column: 5,
            filePath: URL(fileURLWithPath: "/Users/test/MyProject/Sources/File.swift"),
            severity: .warning,
            category: "Style"
        )

        XCTAssertEqual(issue.name, "TestRule")
        XCTAssertEqual(issue.message, "Test message")
        XCTAssertEqual(issue.line, 10)
        XCTAssertEqual(issue.column, 5)
        XCTAssertEqual(issue.severity, .warning)
        XCTAssertEqual(issue.category, "Style")
    }

    func testRelativePathCalculation() {
        let issue = ReportableIssue(
            name: "TestRule",
            message: "Test message",
            line: 10,
            column: 5,
            filePath: URL(fileURLWithPath: "/Users/test/MyProject/Sources/Module/File.swift")
        )

        let relativePath = issue.relativePath(from: projectRoot)
        XCTAssertEqual(relativePath, "Sources/Module/File.swift")
    }

    func testRelativePathWithNonMatchingRoot() {
        let issue = ReportableIssue(
            name: "TestRule",
            message: "Test message",
            line: 10,
            column: 5,
            filePath: URL(fileURLWithPath: "/Other/Path/File.swift")
        )

        let relativePath = issue.relativePath(from: projectRoot)
        XCTAssertEqual(relativePath, "File.swift")
    }

    func testFingerprintGeneration() {
        let issue1 = ReportableIssue(
            name: "TestRule",
            message: "Test message",
            line: 10,
            column: 5,
            filePath: URL(fileURLWithPath: "/Users/test/MyProject/Sources/File.swift")
        )

        let issue2 = ReportableIssue(
            name: "TestRule",
            message: "Test message",
            line: 10,
            column: 5,
            filePath: URL(fileURLWithPath: "/Users/test/MyProject/Sources/File.swift")
        )

        let issue3 = ReportableIssue(
            name: "DifferentRule",
            message: "Test message",
            line: 10,
            column: 5,
            filePath: URL(fileURLWithPath: "/Users/test/MyProject/Sources/File.swift")
        )

        // Same issues should have same fingerprint
        XCTAssertEqual(
            issue1.fingerprint(projectRoot: projectRoot),
            issue2.fingerprint(projectRoot: projectRoot)
        )

        // Different issues should have different fingerprint
        XCTAssertNotEqual(
            issue1.fingerprint(projectRoot: projectRoot),
            issue3.fingerprint(projectRoot: projectRoot)
        )
    }

    func testSeverityCodeClimateValues() {
        XCTAssertEqual(ReportableIssue.Severity.info.codeClimateValue, "info")
        XCTAssertEqual(ReportableIssue.Severity.minor.codeClimateValue, "minor")
        XCTAssertEqual(ReportableIssue.Severity.warning.codeClimateValue, "minor")
        XCTAssertEqual(ReportableIssue.Severity.major.codeClimateValue, "major")
        XCTAssertEqual(ReportableIssue.Severity.critical.codeClimateValue, "critical")
        XCTAssertEqual(ReportableIssue.Severity.blocker.codeClimateValue, "blocker")
    }

    func testSeverityCheckstyleValues() {
        XCTAssertEqual(ReportableIssue.Severity.info.checkstyleValue, "info")
        XCTAssertEqual(ReportableIssue.Severity.minor.checkstyleValue, "warning")
        XCTAssertEqual(ReportableIssue.Severity.warning.checkstyleValue, "warning")
        XCTAssertEqual(ReportableIssue.Severity.major.checkstyleValue, "error")
        XCTAssertEqual(ReportableIssue.Severity.critical.checkstyleValue, "error")
        XCTAssertEqual(ReportableIssue.Severity.blocker.checkstyleValue, "error")
    }
}
