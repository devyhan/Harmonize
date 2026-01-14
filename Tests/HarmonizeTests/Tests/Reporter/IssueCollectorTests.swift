//
//  IssueCollectorTests.swift
//  Harmonize
//
//  Copyright (c) Perry Street Software 2024. All Rights Reserved.
//

import Foundation
import XCTest
@testable import Harmonize

final class IssueCollectorTests: XCTestCase {
    let projectRoot = URL(fileURLWithPath: "/Users/test/MyProject")

    override func setUp() {
        super.setUp()
        IssueCollector.shared.reset()
        // Enable reporting for tests
        setenv("HARMONIZE_REPORTER", "codeclimate", 1)
    }

    override func tearDown() {
        IssueCollector.shared.reset()
        unsetenv("HARMONIZE_REPORTER")
        super.tearDown()
    }

    // MARK: - Collection Tests

    func testCollectSingleIssue() {
        let issue = makeIssue(name: "TestRule", line: 10)

        IssueCollector.shared.collect(issue)

        XCTAssertEqual(IssueCollector.shared.count, 1)
        XCTAssertTrue(IssueCollector.shared.hasIssues)
    }

    func testCollectMultipleIssues() {
        let issues = [
            makeIssue(name: "Rule1", line: 10),
            makeIssue(name: "Rule2", line: 20),
            makeIssue(name: "Rule3", line: 30)
        ]

        IssueCollector.shared.collect(issues)

        XCTAssertEqual(IssueCollector.shared.count, 3)
    }

    func testCollectedIssuesRetrieval() {
        let issue1 = makeIssue(name: "Rule1", line: 10)
        let issue2 = makeIssue(name: "Rule2", line: 20)

        IssueCollector.shared.collect(issue1)
        IssueCollector.shared.collect(issue2)

        let collected = IssueCollector.shared.collectedIssues
        XCTAssertEqual(collected.count, 2)
        XCTAssertEqual(collected[0].name, "Rule1")
        XCTAssertEqual(collected[1].name, "Rule2")
    }

    // MARK: - Clear/Reset Tests

    func testClearIssues() {
        IssueCollector.shared.collect(makeIssue(name: "Rule1", line: 10))
        IssueCollector.shared.collect(makeIssue(name: "Rule2", line: 20))

        XCTAssertEqual(IssueCollector.shared.count, 2)

        IssueCollector.shared.clear()

        XCTAssertEqual(IssueCollector.shared.count, 0)
        XCTAssertFalse(IssueCollector.shared.hasIssues)
    }

    func testResetClearsIssuesAndConfig() {
        IssueCollector.shared.collect(makeIssue(name: "Rule1", line: 10))
        IssueCollector.shared.setProjectRoot(projectRoot)

        IssueCollector.shared.reset()

        XCTAssertEqual(IssueCollector.shared.count, 0)
    }

    // MARK: - Project Root Tests

    func testSetProjectRoot() {
        let customRoot = URL(fileURLWithPath: "/custom/path")
        IssueCollector.shared.setProjectRoot(customRoot)

        XCTAssertEqual(IssueCollector.shared.projectRoot, customRoot)
    }

    // MARK: - Collection Disabled Tests

    func testCollectionDisabledWithoutEnvVar() {
        unsetenv("HARMONIZE_REPORTER")

        let issue = makeIssue(name: "TestRule", line: 10)
        IssueCollector.shared.collect(issue)

        // Should not collect when env var is not set
        XCTAssertEqual(IssueCollector.shared.count, 0)
    }

    // MARK: - Thread Safety Tests

    func testConcurrentCollection() {
        let expectation = XCTestExpectation(description: "Concurrent collection")
        let iterations = 100
        let queue = DispatchQueue(label: "test.concurrent", attributes: .concurrent)

        for i in 0..<iterations {
            queue.async {
                let issue = self.makeIssue(name: "Rule\(i)", line: i)
                IssueCollector.shared.collect(issue)
            }
        }

        queue.async(flags: .barrier) {
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 5.0)
        XCTAssertEqual(IssueCollector.shared.count, iterations)
    }

    // MARK: - Helpers

    private func makeIssue(name: String, line: Int) -> ReportableIssue {
        ReportableIssue(
            name: name,
            message: "Test message for \(name)",
            line: line,
            column: 1,
            filePath: URL(fileURLWithPath: "/Users/test/MyProject/Sources/File.swift"),
            severity: .warning
        )
    }
}
