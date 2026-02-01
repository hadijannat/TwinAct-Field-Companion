//
//  SyncEngineTests.swift
//  TwinAct Field CompanionTests
//
//  Unit tests for SyncEngine - testing conflict resolution and sync utilities.
//

import XCTest
@testable import TwinAct_Field_Companion

final class SyncEngineTests: XCTestCase {

    // MARK: - OutboxOperationType Tests

    func testOutboxOperationTypeRawValues() {
        XCTAssertEqual(OutboxOperationType.create.rawValue, "create")
        XCTAssertEqual(OutboxOperationType.update.rawValue, "update")
        XCTAssertEqual(OutboxOperationType.delete.rawValue, "delete")
    }

    // MARK: - OutboxStatus Tests

    func testOutboxStatusRawValues() {
        XCTAssertEqual(OutboxStatus.pending.rawValue, "pending")
        XCTAssertEqual(OutboxStatus.inProgress.rawValue, "inProgress")
        XCTAssertEqual(OutboxStatus.completed.rawValue, "completed")
        XCTAssertEqual(OutboxStatus.failed.rawValue, "failed")
    }

    // MARK: - SyncResult Tests

    func testEmptySyncResultIsSuccess() {
        let result = SyncResult()
        XCTAssertTrue(result.isSuccess, "Empty result should be success")
        XCTAssertEqual(result.successCount, 0)
        XCTAssertEqual(result.failureCount, 0)
    }

    func testMixedSyncResultIsNotSuccess() {
        let result = SyncResult(
            successCount: 3,
            failureCount: 1,
            skippedCount: 0,
            errors: [.operationFailed(operationId: UUID(), underlying: NSError(domain: "test", code: 1))]
        )
        XCTAssertFalse(result.isSuccess, "Result with failures should not be success")
        XCTAssertEqual(result.successCount, 3)
        XCTAssertEqual(result.failureCount, 1)
    }

    // MARK: - ConflictResolver Tests

    func testServerWinsStrategy() {
        let resolver = ConflictResolver(strategy: .serverWins)

        let localData = """
        {"title": "Local Version", "status": "InProgress"}
        """.data(using: .utf8)!

        let serverData = """
        {"title": "Server Version", "status": "Completed"}
        """.data(using: .utf8)!

        let resolution = resolver.resolve(
            localData: localData,
            serverData: serverData,
            localTimestamp: Date(),
            serverTimestamp: nil
        )

        if case .useServer = resolution {
            // Success
        } else {
            XCTFail("ServerWins strategy should resolve to useServer")
        }
    }

    func testClientWinsStrategy() {
        let resolver = ConflictResolver(strategy: .clientWins)

        let localData = """
        {"title": "Local Version", "status": "InProgress"}
        """.data(using: .utf8)!

        let serverData = """
        {"title": "Server Version", "status": "Completed"}
        """.data(using: .utf8)!

        let resolution = resolver.resolve(
            localData: localData,
            serverData: serverData,
            localTimestamp: Date(),
            serverTimestamp: nil
        )

        if case .useClient(let data) = resolution {
            XCTAssertEqual(data, localData, "ClientWins should return local data")
        } else {
            XCTFail("ClientWins strategy should resolve to useClient")
        }
    }

    func testLastWriteWinsWithNewerLocal() {
        let resolver = ConflictResolver(strategy: .lastWriteWins)

        let localData = "local".data(using: .utf8)!
        let serverData = "server".data(using: .utf8)!

        let newerLocal = Date()
        let olderServer = Date().addingTimeInterval(-3600) // 1 hour ago

        let resolution = resolver.resolve(
            localData: localData,
            serverData: serverData,
            localTimestamp: newerLocal,
            serverTimestamp: olderServer
        )

        if case .useClient = resolution {
            // Success - local is newer
        } else {
            XCTFail("LastWriteWins should use client when local is newer")
        }
    }

    func testLastWriteWinsWithNewerServer() {
        let resolver = ConflictResolver(strategy: .lastWriteWins)

        let localData = "local".data(using: .utf8)!
        let serverData = "server".data(using: .utf8)!

        let olderLocal = Date().addingTimeInterval(-3600) // 1 hour ago
        let newerServer = Date()

        let resolution = resolver.resolve(
            localData: localData,
            serverData: serverData,
            localTimestamp: olderLocal,
            serverTimestamp: newerServer
        )

        if case .useServer = resolution {
            // Success - server is newer
        } else {
            XCTFail("LastWriteWins should use server when server is newer")
        }
    }

    // MARK: - SyncError Tests

    func testSyncInProgressDoesNotRequireUserAction() {
        let error = SyncError.syncInProgress
        XCTAssertFalse(error.requiresUserAction)
    }

    func testNotConnectedDoesNotRequireUserAction() {
        let error = SyncError.notConnected
        XCTAssertFalse(error.requiresUserAction)
    }

    func testManualResolutionRequiredRequiresUserAction() {
        let error = SyncError.manualResolutionRequired(
            operationId: UUID(),
            localVersion: "local",
            serverVersion: "server"
        )
        XCTAssertTrue(error.requiresUserAction)
    }

    // MARK: - NetworkStatus Tests

    func testConnectedWiFiShouldAllowSync() {
        let status = NetworkStatus(
            isConnected: true,
            connectionType: .wifi,
            isExpensive: false,
            isConstrained: false
        )
        XCTAssertTrue(status.shouldAllowSync)
    }

    func testDisconnectedShouldNotAllowSync() {
        let status = NetworkStatus(
            isConnected: false,
            connectionType: .unknown,
            isExpensive: false,
            isConstrained: false
        )
        XCTAssertFalse(status.shouldAllowSync)
    }

    func testCellularSyncAllowanceDependsOnSettings() {
        let status = NetworkStatus(
            isConnected: true,
            connectionType: .cellular,
            isExpensive: true,
            isConstrained: false
        )

        if AppConfiguration.OfflineSync.syncOnlyOnWiFi {
            XCTAssertFalse(status.shouldAllowSync, "Cellular should not allow sync when syncOnlyOnWiFi is true")
        } else {
            XCTAssertTrue(status.shouldAllowSync, "Cellular should allow sync when syncOnlyOnWiFi is false")
        }
    }

    // MARK: - OutboxStats Tests

    func testOutboxStatsCounting() {
        let stats = OutboxStats(
            pendingCount: 10,
            inProgressCount: 2,
            failedCount: 3,
            completedCount: 15
        )

        XCTAssertEqual(stats.pendingCount, 10)
        XCTAssertEqual(stats.inProgressCount, 2)
        XCTAssertEqual(stats.failedCount, 3)
        XCTAssertEqual(stats.completedCount, 15)
        XCTAssertEqual(stats.totalPending, 13, "Total pending (pending + failed) should be 13")
    }

    // MARK: - ConflictResolution Description Tests

    func testResolutionDescriptions() {
        let useServer = ConflictResolver.Resolution.useServer(Data())
        XCTAssertEqual(useServer.description, "Using server version")

        let useClient = ConflictResolver.Resolution.useClient(Data())
        XCTAssertEqual(useClient.description, "Using local version")

        let merged = ConflictResolver.Resolution.merged(Data())
        XCTAssertEqual(merged.description, "Using merged version")

        let manual = ConflictResolver.Resolution.requiresManualResolution(local: Data(), server: Data())
        XCTAssertEqual(manual.description, "Requires manual resolution")
    }

    // MARK: - ConnectionType Tests

    func testConnectionTypeExpensiveProperty() {
        XCTAssertFalse(ConnectionType.wifi.isExpensive, "WiFi should not be expensive")
        XCTAssertTrue(ConnectionType.cellular.isExpensive, "Cellular should be expensive")
        XCTAssertFalse(ConnectionType.wiredEthernet.isExpensive, "Ethernet should not be expensive")
    }
}
