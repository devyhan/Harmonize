//
//  Harmonize.swift
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

/// The entry point for creating HarmonizeScope.
public struct Harmonize {
    private init() {}
    
    /// Resolves the production and test code from the working directory.
    ///
    /// - returns: access to ``on``, ``excludes`` builders and ``HarmonizeScope``.
    public static func productionAndTestCode(_ file: StaticString = #file) -> On & Excluding {
        HarmonizeScopeBuilder(file: file)
    }
    
    /// Resolves the production code from the working directory by ignoring `Tests` and `Fixtures`.
    ///
    /// - returns: access to ``on``, ``excludes`` builders and ``HarmonizeScope``.
    public static func productionCode(_ file: StaticString = #file) -> On & Excluding {
        HarmonizeScopeBuilder(file: file, exclusions: ["Tests", "Fixtures"])
    }
    
    /// Resolves the test code from the working directory by including only `Tests` and `Fixtures` targets.
    ///
    /// - returns: access to ``on``, ``excludes`` builders and ``HarmonizeScope``.
    public static func testCode(_ file: StaticString = #file) -> On & Excluding {
        HarmonizeScopeBuilder(file: file, includingOnly: ["Tests", "Fixtures"])
    }
    
    /// A convenience method for ``Harmonize.productionCode().on(folder)``.
    ///
    /// This method simplifies specifying a folder path within the production code scope.
    ///
    /// - returns: ``Excluding`` scope builder.
    public static func on(_ folder: String, _ file: StaticString = #file) -> Excluding {
        productionCode(file).on(folder)
    }
    
    /// A convenience method for ``Harmonize.productionCode().excluding(folder)``.
    ///
    /// This method simplifies excluding a folder path from the production code scope.
    ///
    /// - returns: ``HarmonizeScope``.
    public static func excluding(_ folder: String, _ file: StaticString = #file) -> HarmonizeScope {
        productionCode(file).excluding(folder)
    }
    
    /// Creates a `HarmonizeScope` using the provided Swift source as string.
    ///
    /// - Parameter source: A closure that returns the source code as a `String`.
    /// - Returns: ``HarmonizeScope`` built from the provided source.
    public static func on(source: () -> String) -> HarmonizeScope {
        on(source: source())
    }

    /// Creates a `HarmonizeScope` using the provided Swift source as string.
    ///
    /// - parameter source: The source code as a `String`.
    /// - returns: ``HarmonizeScope`` built from the provided source.
    public static func on(source: String) -> HarmonizeScope {
        PlainSourceScopeBuilder(source: source)
    }

    // MARK: - Reporter API

    /// Exports collected issues using the environment-specified reporter.
    ///
    /// Call this method after all tests have run to generate the report file.
    /// Set `HARMONIZE_REPORTER` environment variable to enable (e.g., "codeclimate").
    ///
    /// ## Example Usage
    /// ```swift
    /// // In test teardown
    /// override class func tearDown() {
    ///     try? Harmonize.exportIssues()
    ///     super.tearDown()
    /// }
    /// ```
    ///
    /// - Parameter outputPath: Optional custom output path for the report
    /// - Returns: Path to the generated report file, or nil if reporting is disabled
    @discardableResult
    public static func exportIssues(to outputPath: String? = nil) throws -> URL? {
        try IssueCollector.shared.export(to: outputPath)
    }

    /// Exports collected issues using a specific reporter.
    ///
    /// - Parameters:
    ///   - reporter: Reporter identifier (e.g., "codeclimate")
    ///   - outputPath: Optional custom output path for the report
    /// - Returns: Path to the generated report file
    @discardableResult
    public static func exportIssues(using reporter: String, to outputPath: String? = nil) throws -> URL {
        try IssueCollector.shared.export(using: reporter, to: outputPath)
    }

    /// Registers a custom reporter for use with Harmonize.
    ///
    /// ## Example
    /// ```swift
    /// // Register at test setup
    /// Harmonize.registerReporter(MyCustomReporter())
    /// ```
    ///
    /// - Parameter reporter: Reporter instance to register
    public static func registerReporter<R: Reporter>(_ reporter: R) {
        ReporterRegistry.shared.register(reporter)
    }

    /// Returns all collected issues.
    ///
    /// Useful for custom processing or debugging.
    public static var collectedIssues: [ReportableIssue] {
        IssueCollector.shared.collectedIssues
    }

    /// Clears all collected issues.
    ///
    /// Call this between test runs if needed.
    public static func clearCollectedIssues() {
        IssueCollector.shared.clear()
    }

    /// Sets the project root for relative path calculation in reports.
    ///
    /// - Parameter root: Project root directory URL
    public static func setProjectRoot(_ root: URL) {
        IssueCollector.shared.setProjectRoot(root)
    }
}
