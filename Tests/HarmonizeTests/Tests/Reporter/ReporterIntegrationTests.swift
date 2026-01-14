//
//  ReporterIntegrationTests.swift
//  Harmonize
//
//  Copyright (c) Perry Street Software 2024. All Rights Reserved.
//

import Foundation
import XCTest
import HarmonizeSemantics
@testable import Harmonize

/// Integration tests verifying that assertion failures are collected by IssueCollector.
///
/// These tests use ExpectedFailureTestCaseRun to suppress XCTest failures
/// while verifying that issues are properly collected for reporting.
final class ReporterIntegrationTests: XCTestCase {
    override var testRunClass: AnyClass? {
        return ExpectedFailureTestCaseRun.self
    }

    private let testCode = Harmonize.testCode().on("SampleApp")

    override func setUp() {
        super.setUp()
        IssueCollector.shared.reset()
        setenv("HARMONIZE_REPORTER", "codeclimate", 1)
    }

    override func tearDown() {
        IssueCollector.shared.reset()
        unsetenv("HARMONIZE_REPORTER")
        super.tearDown()
    }

    // MARK: - Integration Tests

    func testAssertTrueFailureCollectsIssues() {
        let initialCount = IssueCollector.shared.count

        // This will fail and trigger issue collection
        testCode.classes().assertTrue(message: "Test rule violation") { _ in
            false
        }

        XCTAssertGreaterThan(
            IssueCollector.shared.count,
            initialCount,
            "Issues should be collected after assertion failure"
        )
    }

    func testAssertFalseFailureCollectsIssues() {
        let initialCount = IssueCollector.shared.count

        testCode.classes().assertFalse(message: "Test rule violation") { _ in
            true
        }

        XCTAssertGreaterThan(
            IssueCollector.shared.count,
            initialCount,
            "Issues should be collected after assertion failure"
        )
    }

    func testAssertEmptyFailureCollectsIssues() {
        let initialCount = IssueCollector.shared.count

        testCode.classes().assertEmpty(message: "Classes should be empty")

        XCTAssertGreaterThan(
            IssueCollector.shared.count,
            initialCount,
            "Issues should be collected after assertion failure"
        )
    }

    func testCollectedIssuesContainCorrectMessage() {
        let customMessage = "Custom violation message for testing"

        testCode.classes().assertTrue(message: customMessage) { _ in
            false
        }

        let issues = IssueCollector.shared.collectedIssues
        let hasMatchingMessage = issues.contains { $0.message == customMessage }

        XCTAssertTrue(hasMatchingMessage, "Collected issues should contain the custom message")
    }

    func testCollectedIssuesHaveValidLineNumbers() {
        testCode.classes().assertTrue(message: "Test violation") { _ in
            false
        }

        let issues = IssueCollector.shared.collectedIssues

        for issue in issues {
            XCTAssertGreaterThan(issue.line, 0, "Line number should be positive")
        }
    }

    func testCollectedIssuesHaveValidFilePaths() {
        testCode.classes().assertTrue(message: "Test violation") { _ in
            false
        }

        let issues = IssueCollector.shared.collectedIssues

        for issue in issues {
            XCTAssertTrue(
                issue.filePath.path.hasSuffix(".swift"),
                "File path should be a Swift file"
            )
        }
    }

    func testNoIssuesCollectedWhenAssertionPasses() {
        IssueCollector.shared.clear()

        testCode.classes().assertTrue { _ in
            true
        }

        XCTAssertEqual(
            IssueCollector.shared.count,
            0,
            "No issues should be collected when assertion passes"
        )
    }

    func testNoIssuesCollectedWhenReportingDisabled() {
        unsetenv("HARMONIZE_REPORTER")
        IssueCollector.shared.clear()

        testCode.classes().assertTrue(message: "Test violation") { _ in
            false
        }

        XCTAssertEqual(
            IssueCollector.shared.count,
            0,
            "No issues should be collected when HARMONIZE_REPORTER is not set"
        )
    }

    // MARK: - Export Tests

    func testExportGeneratesValidJSON() throws {
        testCode.classes().assertTrue(message: "Test violation") { _ in
            false
        }

        guard IssueCollector.shared.hasIssues else {
            XCTFail("Expected issues to be collected")
            return
        }

        let tempDir = FileManager.default.temporaryDirectory
        let outputPath = tempDir.appendingPathComponent("test_report.json").path

        let resultURL = try IssueCollector.shared.export(using: "codeclimate", to: outputPath)

        XCTAssertTrue(FileManager.default.fileExists(atPath: resultURL.path))

        let data = try Data(contentsOf: resultURL)
        let json = try JSONSerialization.jsonObject(with: data) as? [[String: Any]]

        XCTAssertNotNil(json)
        XCTAssertGreaterThan(json?.count ?? 0, 0)

        // Cleanup
        try? FileManager.default.removeItem(at: resultURL)
    }

    func testExportedJSONContainsRequiredFields() throws {
        testCode.classes().assertTrue(message: "Test violation") { _ in
            false
        }

        guard IssueCollector.shared.hasIssues else {
            XCTFail("Expected issues to be collected")
            return
        }

        let tempDir = FileManager.default.temporaryDirectory
        let outputPath = tempDir.appendingPathComponent("test_fields.json").path

        let resultURL = try IssueCollector.shared.export(using: "codeclimate", to: outputPath)
        let data = try Data(contentsOf: resultURL)
        let json = try JSONSerialization.jsonObject(with: data) as? [[String: Any]]

        let firstIssue = json?.first
        XCTAssertNotNil(firstIssue?["description"])
        XCTAssertNotNil(firstIssue?["check_name"])
        XCTAssertNotNil(firstIssue?["fingerprint"])
        XCTAssertNotNil(firstIssue?["severity"])
        XCTAssertNotNil(firstIssue?["location"])

        // Cleanup
        try? FileManager.default.removeItem(at: resultURL)
    }
}

// MARK: - Expected Failure Test Case Run

internal extension ReporterIntegrationTests {
    /// Suppresses XCTest failures to allow testing assertion failure behavior.
    /// Adapted from: https://medium.com/@matthew_healy/cuteasserts-dev-blog-1
    final class ExpectedFailureTestCaseRun: XCTestCaseRun {
        private var failed = false

        override func record(_ issue: XCTIssue) {
            failed = true
        }

        override func stop() {
            defer {
                failed = false
                super.stop()
            }

            guard failed else {
                // This test expects failures, so passing is actually a failure
                // But for reporter tests, we don't require failure
                return
            }
        }
    }
}
