//
//  ServiceRequestViewModel.swift
//  TwinAct Field Companion
//
//  View models for service request list and detail operations.
//  Implements offline-first pattern with outbox sync.
//

import Foundation
import SwiftUI
import os.log
import Combine

// MARK: - Service Request List View Model

/// View model for the service request list.
@MainActor
public final class ServiceRequestListViewModel: ObservableObject {

    // MARK: - Published Properties

    /// All loaded service requests
    @Published public private(set) var requests: [ServiceRequest] = []

    /// Whether data is currently loading
    @Published public var isLoading: Bool = false

    /// Current filter selection
    @Published public var filter: RequestFilter = .all

    /// Search text for filtering
    @Published public var searchText: String = ""

    /// Number of pending sync operations
    @Published public private(set) var pendingSyncCount: Int = 0

    /// Error message if loading failed
    @Published public private(set) var errorMessage: String?

    // MARK: - Properties

    /// The current asset ID filter
    public let currentAssetId: String?

    private let submodelService: SubmodelServiceProtocol
    private let persistenceService: PersistenceRepositoryProtocol
    private let logger: Logger

    // Demo data for development
    private var demoRequests: [ServiceRequest] = []

    // MARK: - Computed Properties

    /// Filtered requests based on current filter and search text.
    public var filteredRequests: [ServiceRequest] {
        var result = requests

        // Apply filter
        switch filter {
        case .all:
            break
        case .open:
            result = result.filter { $0.isOpen }
        case .mine:
            // Filter by current user - for now show all
            break
        case .syncing:
            // Would filter by pending sync status
            break
        }

        // Apply search
        if !searchText.isEmpty {
            let lowercasedSearch = searchText.lowercased()
            result = result.filter { request in
                request.title.lowercased().contains(lowercasedSearch) ||
                request.description.lowercased().contains(lowercasedSearch) ||
                request.category.displayName.lowercased().contains(lowercasedSearch)
            }
        }

        // Sort by priority then date
        return result.sorted { lhs, rhs in
            if lhs.priority.sortOrder != rhs.priority.sortOrder {
                return lhs.priority.sortOrder > rhs.priority.sortOrder
            }
            return lhs.requestDate > rhs.requestDate
        }
    }

    // MARK: - Initialization

    /// Initialize with optional asset ID filter.
    /// - Parameter assetId: Optional asset ID to filter requests
    public init(
        assetId: String? = nil,
        submodelService: SubmodelServiceProtocol = SubmodelService(),
        persistenceService: PersistenceRepositoryProtocol? = nil
    ) {
        self.currentAssetId = assetId
        self.submodelService = submodelService
        self.persistenceService = persistenceService ?? PersistenceService()
        self.logger = Logger(
            subsystem: AppConfiguration.AppInfo.bundleIdentifier,
            category: "ServiceRequestListViewModel"
        )

        // Create demo data for development
        setupDemoData()
    }

    // MARK: - Public Methods

    /// Load service requests.
    public func loadRequests() async {
        guard !isLoading else { return }

        isLoading = true
        defer { isLoading = false }

        logger.debug("Loading service requests for asset: \(self.currentAssetId ?? "all")")

        // Load from cache first
        await loadFromCache()

        // Try to load from server
        do {
            try await loadFromServer()
        } catch {
            logger.warning("Failed to load from server: \(error.localizedDescription)")
            // Continue with cached/demo data
        }

        // Update pending sync count
        await updatePendingSyncCount()
    }

    /// Refresh the request list.
    public func refresh() async {
        await loadRequests()
    }

    /// Create a new service request.
    /// - Parameter request: The request to create
    public func createRequest(_ request: ServiceRequest) async {
        logger.debug("Creating service request: \(request.title)")

        // Add to local list immediately
        requests.insert(request, at: 0)

        // Queue for sync
        do {
            let element = request.toSubmodelElement()

            try await persistenceService.queueForSync(
                operationType: .create,
                entityType: "ServiceRequest",
                entityId: request.id,
                submodelId: "urn:twinact:serviceRequests:\(currentAssetId ?? "global")",
                payload: element,
                priority: request.priority.sortOrder
            )

            await updatePendingSyncCount()

        } catch {
            logger.error("Failed to queue request for sync: \(error.localizedDescription)")
            errorMessage = error.localizedDescription
        }
    }

    /// Update an existing service request.
    /// - Parameter request: The updated request
    public func updateRequest(_ request: ServiceRequest) async {
        logger.debug("Updating service request: \(request.id)")

        // Update local list
        if let index = requests.firstIndex(where: { $0.id == request.id }) {
            requests[index] = request
        }

        // Queue for sync
        do {
            let element = request.toSubmodelElement()

            try await persistenceService.queueForSync(
                operationType: .update,
                entityType: "ServiceRequest",
                entityId: request.id,
                submodelId: "urn:twinact:serviceRequests:\(currentAssetId ?? "global")",
                payload: element,
                priority: request.priority.sortOrder
            )

            await updatePendingSyncCount()

        } catch {
            logger.error("Failed to queue update for sync: \(error.localizedDescription)")
            errorMessage = error.localizedDescription
        }
    }

    /// Get count for a specific filter.
    /// - Parameter filter: The filter to count
    /// - Returns: Number of matching requests
    public func count(for filter: RequestFilter) -> Int {
        switch filter {
        case .all:
            return requests.count
        case .open:
            return requests.filter { $0.isOpen }.count
        case .mine:
            return requests.count // Would filter by current user
        case .syncing:
            return pendingSyncCount
        }
    }

    // MARK: - Private Methods

    private func loadFromCache() async {
        // Load cached requests
        let cachedSubmodels = await persistenceService.getCachedSubmodels(forAAS: currentAssetId ?? "global")

        for cached in cachedSubmodels {
            if cached.semanticId?.contains("ServiceRequest") == true {
                do {
                    let parsedRequests = try cached.decode(as: [ServiceRequest].self)
                    requests = parsedRequests
                    logger.debug("Loaded \(parsedRequests.count) requests from cache")
                    return
                } catch {
                    logger.warning("Failed to decode cached requests: \(error.localizedDescription)")
                    // Continue to try other caches or fall back to demo data
                }
            }
        }

        // Fall back to demo data if no cache
        if requests.isEmpty {
            logger.debug("No cached requests found, using demo data")
            requests = demoRequests
        }
    }

    private func loadFromServer() async throws {
        guard let assetId = currentAssetId else { return }

        // Try to get service request submodel
        if let submodel = try await submodelService.getSubmodelBySemanticId(
            aasId: assetId,
            semanticId: ServiceRequest.semanticId
        ) {
            // Parse requests from submodel
            let parsedRequests = parseRequests(from: submodel)
            if !parsedRequests.isEmpty {
                requests = parsedRequests
            }
        }
    }

    private func parseRequests(from submodel: Submodel) -> [ServiceRequest] {
        // Parse service requests from submodel elements
        guard let elements = submodel.submodelElements else { return [] }

        var parsedRequests: [ServiceRequest] = []

        for element in elements {
            if case .submodelElementCollection(let collection) = element {
                if let request = parseRequest(from: collection) {
                    parsedRequests.append(request)
                }
            }
        }

        return parsedRequests
    }

    private func parseRequest(from collection: SubmodelElementCollection) -> ServiceRequest? {
        guard let elements = collection.value else { return nil }

        var id: String?
        var status: ServiceRequestStatus = .new
        var priority: ServiceRequestPriority = .normal
        var category: ServiceRequestCategory = .other
        var title: String?
        var description: String?
        var requestDate: Date = Date()

        for element in elements {
            if case .property(let property) = element {
                switch property.idShort {
                case "RequestId":
                    id = property.value
                case "Status":
                    status = ServiceRequestStatus(rawValue: property.value ?? "") ?? .new
                case "Priority":
                    priority = ServiceRequestPriority(rawValue: property.value ?? "") ?? .normal
                case "Category":
                    category = ServiceRequestCategory(rawValue: property.value ?? "") ?? .other
                case "Title":
                    title = property.value
                case "Description":
                    description = property.value
                case "RequestDate":
                    if let dateString = property.value {
                        requestDate = ISO8601DateFormatter().date(from: dateString) ?? Date()
                    }
                default:
                    break
                }
            }
        }

        guard let requestId = id, let requestTitle = title, let requestDescription = description else {
            return nil
        }

        return ServiceRequest(
            id: requestId,
            status: status,
            priority: priority,
            category: category,
            title: requestTitle,
            description: requestDescription,
            requestDate: requestDate
        )
    }

    private func updatePendingSyncCount() async {
        let operations = await persistenceService.getPendingOperations(entityType: "ServiceRequest")
        pendingSyncCount = operations.count
    }

    private func setupDemoData() {
        // Create demo requests for development
        var request1 = ServiceRequest(
            title: "Motor Overheating Alert",
            description: "The main drive motor is showing elevated temperatures during operation. Temperature readings are 15-20 degrees above normal operating range.",
            category: .repair,
            priority: .high,
            assetId: currentAssetId,
            location: "Building A, Floor 2"
        )
        request1.addNote(author: "System", text: "Temperature sensor threshold exceeded at 14:32")

        var request2 = ServiceRequest(
            title: "Scheduled Maintenance Due",
            description: "Quarterly preventive maintenance is due for the hydraulic system. Oil change and filter replacement required.",
            category: .maintenance,
            priority: .normal,
            assetId: currentAssetId,
            location: "Production Line 3"
        )
        request2.scheduledDate = Calendar.current.date(byAdding: .day, value: 3, to: Date())

        var request3 = ServiceRequest(
            title: "Calibration Certificate Expiring",
            description: "Pressure sensor calibration certificate expires in 14 days. Schedule recalibration.",
            category: .calibration,
            priority: .low,
            assetId: currentAssetId
        )
        request3.assignedTo = "John Smith"

        demoRequests = [request1, request2, request3]
    }
}

// MARK: - Service Request Detail View Model

/// View model for service request detail operations.
@MainActor
public final class ServiceRequestDetailViewModel: ObservableObject {

    // MARK: - Published Properties

    /// The service request being displayed
    @Published public private(set) var request: ServiceRequest

    /// Whether data is loading
    @Published public var isLoading: Bool = false

    /// Whether to show add note sheet
    @Published public var showAddNote: Bool = false

    /// Whether to show update status sheet
    @Published public var showUpdateStatus: Bool = false

    /// Error message if operation failed
    @Published public var errorMessage: String?

    // MARK: - Properties

    private let requestId: String
    private let persistenceService: PersistenceRepositoryProtocol
    private let logger: Logger

    // MARK: - Initialization

    /// Initialize with a request ID.
    /// - Parameter requestId: The service request ID
    public init(
        requestId: String,
        persistenceService: PersistenceRepositoryProtocol? = nil
    ) {
        self.requestId = requestId
        self.persistenceService = persistenceService ?? PersistenceService()
        self.logger = Logger(
            subsystem: AppConfiguration.AppInfo.bundleIdentifier,
            category: "ServiceRequestDetailViewModel"
        )

        // Create placeholder request
        self.request = ServiceRequest(
            title: "Loading...",
            description: "",
            category: .other
        )
    }

    /// Initialize with an existing request.
    /// - Parameter request: The service request
    public init(
        request: ServiceRequest,
        persistenceService: PersistenceRepositoryProtocol? = nil
    ) {
        self.requestId = request.id
        self.request = request
        self.persistenceService = persistenceService ?? PersistenceService()
        self.logger = Logger(
            subsystem: AppConfiguration.AppInfo.bundleIdentifier,
            category: "ServiceRequestDetailViewModel"
        )
    }

    // MARK: - Public Methods

    /// Load the request details.
    public func loadRequest() async {
        guard isLoading == false else { return }

        isLoading = true
        errorMessage = nil

        defer { isLoading = false }

        // Request is already populated from init
        // Future enhancement: could fetch latest version from cache/server here
        logger.debug("Using request from initialization: \(self.requestId)")
    }

    /// Refresh the request details.
    public func refresh() async {
        await loadRequest()
    }

    /// Add a note to the request.
    /// - Parameter text: The note text
    public func addNote(_ text: String) async {
        let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedText.isEmpty else { return }

        logger.debug("Adding note to request: \(self.request.id)")

        // Add note locally
        request.addNote(author: "Technician", text: trimmedText)

        // Queue update for sync
        await queueUpdate()
    }

    /// Update the request status.
    /// - Parameter status: The new status
    public func updateStatus(_ status: ServiceRequestStatus) async {
        logger.debug("Updating status to: \(status.rawValue)")

        // Update locally
        request.updateStatus(status)

        // Add a note about the status change
        request.addNote(author: "System", text: "Status changed to \(status.displayName)")

        // Queue update for sync
        await queueUpdate()
    }

    // MARK: - Private Methods

    private func queueUpdate() async {
        do {
            let element = request.toSubmodelElement()

            try await persistenceService.queueForSync(
                operationType: .update,
                entityType: "ServiceRequest",
                entityId: request.id,
                submodelId: "urn:twinact:serviceRequests:\(request.assetId ?? "global")",
                payload: element,
                priority: request.priority.sortOrder
            )

        } catch {
            logger.error("Failed to queue update: \(error.localizedDescription)")
            errorMessage = error.localizedDescription
        }
    }
}
