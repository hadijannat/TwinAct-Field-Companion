//
//  SyncEngineTests.swift
//  TwinAct Field Companion
//
//  Unit tests for SyncEngine - testing conflict resolution and sync utilities.
//  Tests can be run from debug builds via the diagnostics view.
//

import Foundation

// MARK: - Sync Engine Tests

/// Test runner for SyncEngine tests.
public enum SyncEngineTests {

    /// Runs all tests and returns a summary of results.
    /// - Returns: Tuple of (passed count, failed count, failure messages)
    @discardableResult
    public static func runAllTests() -> (passed: Int, failed: Int, failures: [String]) {
        var passed = 0
        var failed = 0
        var failures: [String] = []

        func assert(_ condition: Bool, _ message: String, file: String = #file, line: Int = #line) {
            if condition {
                passed += 1
            } else {
                failed += 1
                failures.append("FAILED: \(message) (line \(line))")
            }
        }

        func assertEqual<T: Equatable>(_ actual: T, _ expected: T, _ message: String, file: String = #file, line: Int = #line) {
            if actual == expected {
                passed += 1
            } else {
                failed += 1
                failures.append("FAILED: \(message) - Expected '\(expected)', got '\(actual)' (line \(line))")
            }
        }

        // ============================================================
        // MARK: - Test: OutboxOperationType Values
        // ============================================================

        assertEqual(OutboxOperationType.create.rawValue, "create", "Create raw value")
        assertEqual(OutboxOperationType.update.rawValue, "update", "Update raw value")
        assertEqual(OutboxOperationType.delete.rawValue, "delete", "Delete raw value")

        // ============================================================
        // MARK: - Test: OutboxStatus Values
        // ============================================================

        assertEqual(OutboxStatus.pending.rawValue, "pending", "Pending raw value")
        assertEqual(OutboxStatus.inProgress.rawValue, "inProgress", "InProgress raw value")
        assertEqual(OutboxStatus.completed.rawValue, "completed", "Completed raw value")
        assertEqual(OutboxStatus.failed.rawValue, "failed", "Failed raw value")

        // ============================================================
        // MARK: - Test: Sync Result Summary
        // ============================================================

        let successResult = SyncResult()
        assert(successResult.isSuccess, "Empty result should be success")
        assertEqual(successResult.successCount, 0, "Success count should be 0")
        assertEqual(successResult.failureCount, 0, "Failure count should be 0")

        let mixedResult = SyncResult(
            successCount: 3,
            failureCount: 1,
            skippedCount: 0,
            errors: [.operationFailed(operationId: UUID(), underlying: NSError(domain: "test", code: 1))]
        )
        assert(!mixedResult.isSuccess, "Result with failures should not be success")
        assertEqual(mixedResult.successCount, 3, "Success count should be 3")
        assertEqual(mixedResult.failureCount, 1, "Failure count should be 1")

        // ============================================================
        // MARK: - Test: Conflict Resolver - Server Wins Strategy
        // ============================================================

        let serverWinsResolver = ConflictResolver(strategy: .serverWins)

        let localData = """
        {"title": "Local Version", "status": "InProgress"}
        """.data(using: .utf8)!

        let serverData = """
        {"title": "Server Version", "status": "Completed"}
        """.data(using: .utf8)!

        let serverResolution = serverWinsResolver.resolve(
            localData: localData,
            serverData: serverData,
            localTimestamp: Date(),
            serverTimestamp: nil
        )

        if case .useServer = serverResolution {
            passed += 1
        } else {
            failed += 1
            failures.append("FAILED: ServerWins strategy should resolve to useServer")
        }

        // ============================================================
        // MARK: - Test: Conflict Resolver - Client Wins Strategy
        // ============================================================

        let clientWinsResolver = ConflictResolver(strategy: .clientWins)

        let clientResolution = clientWinsResolver.resolve(
            localData: localData,
            serverData: serverData,
            localTimestamp: Date(),
            serverTimestamp: nil
        )

        if case .useClient(let data) = clientResolution {
            assertEqual(data, localData, "ClientWins should return local data")
        } else {
            failed += 1
            failures.append("FAILED: ClientWins strategy should resolve to useClient")
        }

        // ============================================================
        // MARK: - Test: Conflict Resolver - Last Write Wins Strategy
        // ============================================================

        let lastWriteResolver = ConflictResolver(strategy: .lastWriteWins)

        let newerLocal = Date()
        let olderServer = Date().addingTimeInterval(-3600) // 1 hour ago

        let lastWriteResolution1 = lastWriteResolver.resolve(
            localData: localData,
            serverData: serverData,
            localTimestamp: newerLocal,
            serverTimestamp: olderServer
        )

        if case .useClient = lastWriteResolution1 {
            passed += 1
        } else {
            failed += 1
            failures.append("FAILED: LastWriteWins should use client when local is newer")
        }

        let lastWriteResolution2 = lastWriteResolver.resolve(
            localData: localData,
            serverData: serverData,
            localTimestamp: olderServer,
            serverTimestamp: newerLocal
        )

        if case .useServer = lastWriteResolution2 {
            passed += 1
        } else {
            failed += 1
            failures.append("FAILED: LastWriteWins should use server when server is newer")
        }

        // ============================================================
        // MARK: - Test: Sync Error Types
        // ============================================================

        let syncInProgressError = SyncError.syncInProgress
        assert(!syncInProgressError.requiresUserAction, "SyncInProgress should not require user action")

        let notConnectedError = SyncError.notConnected
        assert(!notConnectedError.requiresUserAction, "NotConnected should not require user action")

        let manualResolutionError = SyncError.manualResolutionRequired(
            operationId: UUID(),
            localVersion: "local",
            serverVersion: "server"
        )
        assert(manualResolutionError.requiresUserAction, "ManualResolutionRequired should require user action")

        // ============================================================
        // MARK: - Test: Network Status Sync Allowance
        // ============================================================

        let connectedWiFi = NetworkStatus(
            isConnected: true,
            connectionType: .wifi,
            isExpensive: false,
            isConstrained: false
        )
        assert(connectedWiFi.shouldAllowSync, "Connected WiFi should allow sync")

        let connectedCellular = NetworkStatus(
            isConnected: true,
            connectionType: .cellular,
            isExpensive: true,
            isConstrained: false
        )

        // This depends on syncOnlyOnWiFi setting
        if AppConfiguration.OfflineSync.syncOnlyOnWiFi {
            assert(!connectedCellular.shouldAllowSync, "Cellular should not allow sync when syncOnlyOnWiFi is true")
        } else {
            assert(connectedCellular.shouldAllowSync, "Cellular should allow sync when syncOnlyOnWiFi is false")
        }

        let disconnected = NetworkStatus(
            isConnected: false,
            connectionType: .unknown,
            isExpensive: false,
            isConstrained: false
        )
        assert(!disconnected.shouldAllowSync, "Disconnected should not allow sync")

        // ============================================================
        // MARK: - Test: OutboxStats Calculation
        // ============================================================

        let stats = OutboxStats(
            pendingCount: 10,
            inProgressCount: 2,
            failedCount: 3,
            completedCount: 15
        )

        assertEqual(stats.pendingCount, 10, "Pending count should be 10")
        assertEqual(stats.inProgressCount, 2, "In progress should be 2")
        assertEqual(stats.failedCount, 3, "Failed should be 3")
        assertEqual(stats.completedCount, 15, "Completed should be 15")
        assertEqual(stats.totalPending, 13, "Total pending (pending + failed) should be 13")

        // ============================================================
        // MARK: - Test: Conflict Resolution Description
        // ============================================================

        let useServerRes = ConflictResolver.Resolution.useServer(Data())
        assertEqual(useServerRes.description, "Using server version", "useServer description")

        let useClientRes = ConflictResolver.Resolution.useClient(Data())
        assertEqual(useClientRes.description, "Using local version", "useClient description")

        let mergedRes = ConflictResolver.Resolution.merged(Data())
        assertEqual(mergedRes.description, "Using merged version", "merged description")

        let manualRes = ConflictResolver.Resolution.requiresManualResolution(local: Data(), server: Data())
        assertEqual(manualRes.description, "Requires manual resolution", "manual resolution description")

        // ============================================================
        // MARK: - Test: Connection Type Properties
        // ============================================================

        assert(ConnectionType.wifi.isExpensive == false, "WiFi should not be expensive")
        assert(ConnectionType.cellular.isExpensive == true, "Cellular should be expensive")
        assert(ConnectionType.wiredEthernet.isExpensive == false, "Ethernet should not be expensive")

        // Print summary
        print("=== SyncEngine Tests ===")
        print("Passed: \(passed)")
        print("Failed: \(failed)")
        if !failures.isEmpty {
            print("\nFailures:")
            for failure in failures {
                print("  - \(failure)")
            }
        }
        print("========================")

        return (passed, failed, failures)
    }
}

// MARK: - Debug Verification

#if DEBUG
/// Convenience function to verify SyncEngine works correctly.
/// Call this during app startup in debug builds.
public func verifySyncEngineInDebug() {
    let results = SyncEngineTests.runAllTests()
    if results.failed > 0 {
        assertionFailure("SyncEngine tests failed! \(results.failed) failures. Check console for details.")
    }
}
#endif
