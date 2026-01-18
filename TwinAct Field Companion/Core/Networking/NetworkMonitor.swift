//
//  NetworkMonitor.swift
//  TwinAct Field Companion
//
//  Network connectivity monitor using NWPathMonitor for real-time connectivity status.
//

import Foundation
import Network
import Combine
import os.log

// MARK: - Connection Type

/// Types of network connections
public enum ConnectionType: String, Sendable {
    case wifi = "WiFi"
    case cellular = "Cellular"
    case wiredEthernet = "Wired Ethernet"
    case unknown = "Unknown"

    /// Whether this connection type is considered "expensive" (e.g., metered)
    public var isExpensive: Bool {
        switch self {
        case .cellular:
            return true
        case .wifi, .wiredEthernet, .unknown:
            return false
        }
    }
}

// MARK: - Network Status

/// Represents the current network status
public struct NetworkStatus: Sendable, Equatable {
    /// Whether the device is connected to the network
    public let isConnected: Bool

    /// The type of network connection
    public let connectionType: ConnectionType

    /// Whether the connection is considered expensive (metered)
    public let isExpensive: Bool

    /// Whether the connection is constrained (e.g., low data mode)
    public let isConstrained: Bool

    /// Whether the path supports DNS
    public let supportsDNS: Bool

    /// Whether the path supports IPv4
    public let supportsIPv4: Bool

    /// Whether the path supports IPv6
    public let supportsIPv6: Bool

    public init(
        isConnected: Bool = false,
        connectionType: ConnectionType = .unknown,
        isExpensive: Bool = false,
        isConstrained: Bool = false,
        supportsDNS: Bool = false,
        supportsIPv4: Bool = false,
        supportsIPv6: Bool = false
    ) {
        self.isConnected = isConnected
        self.connectionType = connectionType
        self.isExpensive = isExpensive
        self.isConstrained = isConstrained
        self.supportsDNS = supportsDNS
        self.supportsIPv4 = supportsIPv4
        self.supportsIPv6 = supportsIPv6
    }

    /// Default disconnected status
    public static let disconnected = NetworkStatus()

    /// Check if syncing should be allowed based on app configuration
    public var shouldAllowSync: Bool {
        guard isConnected else { return false }

        // Check Wi-Fi only sync setting
        if AppConfiguration.OfflineSync.syncOnlyOnWiFi {
            return connectionType == .wifi || connectionType == .wiredEthernet
        }

        return true
    }
}

// MARK: - Network Monitor

/// Monitors network connectivity using NWPathMonitor
@MainActor
public final class NetworkMonitor: ObservableObject {

    // MARK: - Published Properties

    /// Whether the device is currently connected to the network
    @Published public private(set) var isConnected: Bool = true

    /// The current type of network connection
    @Published public private(set) var connectionType: ConnectionType = .unknown

    /// The complete network status
    @Published public private(set) var status: NetworkStatus = NetworkStatus(isConnected: true)

    // MARK: - Private Properties

    private let monitor: NWPathMonitor
    private let monitorQueue: DispatchQueue
    private let logger: Logger
    private var isMonitoring: Bool = false

    // MARK: - Singleton

    /// Shared instance for app-wide network monitoring
    public static let shared = NetworkMonitor()

    // MARK: - Initialization

    public init() {
        self.monitor = NWPathMonitor()
        self.monitorQueue = DispatchQueue(label: "com.twinact.networkmonitor", qos: .utility)
        self.logger = Logger(subsystem: AppConfiguration.AppInfo.bundleIdentifier, category: "NetworkMonitor")

        setupMonitor()
    }

    deinit {
        stopMonitoring()
    }

    // MARK: - Public Methods

    /// Start monitoring network changes
    public func startMonitoring() {
        guard !isMonitoring else {
            logger.debug("Network monitor already running")
            return
        }

        monitor.start(queue: monitorQueue)
        isMonitoring = true
        logger.info("Network monitoring started")
    }

    /// Stop monitoring network changes
    public func stopMonitoring() {
        guard isMonitoring else { return }

        monitor.cancel()
        isMonitoring = false
        logger.info("Network monitoring stopped")
    }

    /// Get current network status synchronously
    public nonisolated func currentStatus() -> NetworkStatus {
        let path = monitor.currentPath
        return Self.createStatus(from: path)
    }

    // MARK: - Private Methods

    private func setupMonitor() {
        monitor.pathUpdateHandler = { [weak self] path in
            Task { @MainActor [weak self] in
                self?.handlePathUpdate(path)
            }
        }

        // Start monitoring automatically
        startMonitoring()
    }

    private func handlePathUpdate(_ path: NWPath) {
        let newStatus = Self.createStatus(from: path)

        // Log significant changes
        if newStatus.isConnected != status.isConnected {
            if newStatus.isConnected {
                logger.info("Network connected via \(newStatus.connectionType.rawValue, privacy: .public)")
            } else {
                logger.warning("Network disconnected")
            }
        } else if newStatus.connectionType != status.connectionType {
            logger.info("Connection type changed to \(newStatus.connectionType.rawValue, privacy: .public)")
        }

        // Update published properties
        self.isConnected = newStatus.isConnected
        self.connectionType = newStatus.connectionType
        self.status = newStatus
    }

    private static func createStatus(from path: NWPath) -> NetworkStatus {
        let isConnected = path.status == .satisfied
        let connectionType = determineConnectionType(from: path)

        return NetworkStatus(
            isConnected: isConnected,
            connectionType: connectionType,
            isExpensive: path.isExpensive,
            isConstrained: path.isConstrained,
            supportsDNS: path.supportsDNS,
            supportsIPv4: path.supportsIPv4,
            supportsIPv6: path.supportsIPv6
        )
    }

    private static func determineConnectionType(from path: NWPath) -> ConnectionType {
        if path.usesInterfaceType(.wifi) {
            return .wifi
        } else if path.usesInterfaceType(.cellular) {
            return .cellular
        } else if path.usesInterfaceType(.wiredEthernet) {
            return .wiredEthernet
        } else {
            return .unknown
        }
    }
}

// MARK: - Combine Publisher Extension

extension NetworkMonitor {
    /// Publisher for network status changes
    public var statusPublisher: AnyPublisher<NetworkStatus, Never> {
        $status.eraseToAnyPublisher()
    }

    /// Publisher for connectivity changes
    public var connectivityPublisher: AnyPublisher<Bool, Never> {
        $isConnected.eraseToAnyPublisher()
    }

    /// Publisher for connection type changes
    public var connectionTypePublisher: AnyPublisher<ConnectionType, Never> {
        $connectionType.eraseToAnyPublisher()
    }
}

// MARK: - Async/Await Support

extension NetworkMonitor {
    /// Wait until network becomes available
    /// - Parameter timeout: Maximum time to wait (nil for no timeout)
    /// - Returns: True if connected, false if timed out
    public func waitForConnectivity(timeout: TimeInterval? = nil) async -> Bool {
        // If already connected, return immediately
        if isConnected {
            return true
        }

        // Create a task that waits for connectivity
        return await withCheckedContinuation { continuation in
            var cancellable: AnyCancellable?
            var timeoutTask: Task<Void, Never>?

            cancellable = $isConnected
                .filter { $0 }
                .first()
                .sink { _ in
                    timeoutTask?.cancel()
                    cancellable?.cancel()
                    continuation.resume(returning: true)
                }

            // Set up timeout if specified
            if let timeout = timeout {
                timeoutTask = Task {
                    try? await Task.sleep(nanoseconds: UInt64(timeout * 1_000_000_000))
                    if !Task.isCancelled {
                        cancellable?.cancel()
                        continuation.resume(returning: false)
                    }
                }
            }
        }
    }
}

// MARK: - Debug Helpers

#if DEBUG
extension NetworkMonitor {
    /// Simulate a network status change (for testing/previews)
    public func simulateStatus(_ status: NetworkStatus) {
        self.isConnected = status.isConnected
        self.connectionType = status.connectionType
        self.status = status
    }

    /// Simulate disconnection (for testing/previews)
    public func simulateDisconnection() {
        simulateStatus(.disconnected)
    }

    /// Simulate WiFi connection (for testing/previews)
    public func simulateWiFiConnection() {
        simulateStatus(NetworkStatus(
            isConnected: true,
            connectionType: .wifi,
            isExpensive: false,
            isConstrained: false,
            supportsDNS: true,
            supportsIPv4: true,
            supportsIPv6: true
        ))
    }

    /// Simulate cellular connection (for testing/previews)
    public func simulateCellularConnection() {
        simulateStatus(NetworkStatus(
            isConnected: true,
            connectionType: .cellular,
            isExpensive: true,
            isConstrained: false,
            supportsDNS: true,
            supportsIPv4: true,
            supportsIPv6: true
        ))
    }
}
#endif
