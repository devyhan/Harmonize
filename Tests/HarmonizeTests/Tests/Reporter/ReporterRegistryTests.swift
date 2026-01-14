//
//  ReporterRegistryTests.swift
//  Harmonize
//
//  Copyright (c) Perry Street Software 2024. All Rights Reserved.
//

import Foundation
import XCTest
@testable import Harmonize

final class ReporterRegistryTests: XCTestCase {

    override func setUp() {
        super.setUp()
        unsetenv("HARMONIZE_REPORTER")
    }

    override func tearDown() {
        unsetenv("HARMONIZE_REPORTER")
        // Remove any test reporters
        ReporterRegistry.shared.unregister("mock")
        super.tearDown()
    }

    // MARK: - Built-in Reporter Tests

    func testCodeClimateReporterRegistered() {
        let reporter = ReporterRegistry.shared.reporter(for: "codeclimate")
        XCTAssertNotNil(reporter)
    }

    func testAvailableReportersContainsCodeClimate() {
        let reporters = ReporterRegistry.shared.availableReporters
        XCTAssertTrue(reporters.contains("codeclimate"))
    }

    // MARK: - Custom Reporter Registration Tests

    func testRegisterCustomReporter() {
        let mockReporter = MockReporter()
        ReporterRegistry.shared.register(mockReporter)

        let retrieved = ReporterRegistry.shared.reporter(for: "mock")
        XCTAssertNotNil(retrieved)
    }

    func testUnregisterReporter() {
        let mockReporter = MockReporter()
        ReporterRegistry.shared.register(mockReporter)

        XCTAssertNotNil(ReporterRegistry.shared.reporter(for: "mock"))

        ReporterRegistry.shared.unregister("mock")

        XCTAssertNil(ReporterRegistry.shared.reporter(for: "mock"))
    }

    // MARK: - Environment Variable Tests

    func testEnvironmentReporterWithValidEnvVar() {
        setenv("HARMONIZE_REPORTER", "codeclimate", 1)

        let reporter = ReporterRegistry.shared.environmentReporter()
        XCTAssertNotNil(reporter)
    }

    func testEnvironmentReporterWithInvalidEnvVar() {
        setenv("HARMONIZE_REPORTER", "nonexistent", 1)

        let reporter = ReporterRegistry.shared.environmentReporter()
        XCTAssertNil(reporter)
    }

    func testEnvironmentReporterWithoutEnvVar() {
        unsetenv("HARMONIZE_REPORTER")

        let reporter = ReporterRegistry.shared.environmentReporter()
        XCTAssertNil(reporter)
    }

    func testIsReportingEnabledWithEnvVar() {
        setenv("HARMONIZE_REPORTER", "codeclimate", 1)
        XCTAssertTrue(ReporterRegistry.shared.isReportingEnabled)
    }

    func testIsReportingEnabledWithoutEnvVar() {
        unsetenv("HARMONIZE_REPORTER")
        XCTAssertFalse(ReporterRegistry.shared.isReportingEnabled)
    }

    func testEnvironmentReporterCaseInsensitive() {
        setenv("HARMONIZE_REPORTER", "CODECLIMATE", 1)

        let reporter = ReporterRegistry.shared.environmentReporter()
        XCTAssertNotNil(reporter)
    }

    // MARK: - Reporter Not Found Error Tests

    func testExportWithInvalidReporterThrowsError() {
        XCTAssertThrowsError(
            try ReporterRegistry.shared.export(
                using: "nonexistent",
                issues: [],
                outputPath: nil
            )
        ) { error in
            guard case ReporterError.reporterNotFound = error else {
                XCTFail("Expected reporterNotFound error")
                return
            }
        }
    }
}

// MARK: - Mock Reporter

private struct MockReporter: Reporter {
    static let identifier = "mock"
    static let fileExtension = "txt"
    static let displayName = "Mock"

    func generateReport(from issues: [ReportableIssue], projectRoot: URL) throws -> Data {
        let content = issues.map { "\($0.name): \($0.message)" }.joined(separator: "\n")
        return Data(content.utf8)
    }
}
