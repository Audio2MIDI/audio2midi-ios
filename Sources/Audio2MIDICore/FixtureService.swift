import Foundation

public actor FixtureService: Audio2MIDIService {
    public enum Scenario: String, Sendable { case ready, empty, processing, failed }
    private let scenario: Scenario

    public init(scenario: Scenario = .ready) { self.scenario = scenario }

    public func currentAccount() async throws -> Account {
        Account(accountID: UUID(uuidString: "C911A4C7-BAF0-47CC-8487-EB5A42F2148E")!, username: "Dmitry", remainingRequests: 7, unreadNotificationCount: 1)
    }

    public func startEmailLogin(email: String) async throws {}
    public func verifyEmail(email: String, code: String) async throws -> Account { try await currentAccount() }

    public func library() async throws -> [LibraryItem] {
        guard scenario != .empty else { return [] }
        let status: String = switch scenario {
        case .ready: "ready"
        case .processing: "processing"
        case .failed: "failed"
        case .empty: "ready"
        }
        return [
            LibraryItem(
                id: "fixture-1",
                projectID: UUID(uuidString: "018F7777-9C82-72A5-B4B7-B15CE341DC13"),
                engine: "picogen",
                status: status,
                title: "Midnight Sketch",
                artifacts: status == "ready" ? [Artifact(id: "midi-1", role: "midi", mimeType: "audio/midi", downloadURL: "/fixture.mid")] : []
            ),
            LibraryItem(
                id: "fixture-2",
                projectID: UUID(uuidString: "018F7777-9C82-72A5-B4B7-B15CE341DC14"),
                engine: "sheetsage",
                status: "ready",
                title: "Voice memo 24",
                artifacts: [Artifact(id: "pdf-1", role: "sheet_music", mimeType: "application/pdf", downloadURL: "/fixture.pdf")]
            ),
        ]
    }

    public func process(projectID: UUID, mode: OutputMode, idempotencyKey: String) async throws -> ProcessResponse {
        ProcessResponse(created: true, projectID: projectID, jobID: UUID(), outputMode: mode)
    }

    public func create(fileURL: URL, mode: OutputMode) async throws -> ProcessResponse { try await process(projectID: UUID(), mode: mode, idempotencyKey: "fixture") }
    public func create(remoteValue: String, kind: String, title: String?, mode: OutputMode) async throws -> ProcessResponse { try await process(projectID: UUID(), mode: mode, idempotencyKey: "fixture") }
    public func searchCatalog(_ query: String) async throws -> [CatalogTrack] {
        [CatalogTrack(sourceID: "fixture-track", title: "Midnight Sketch", artist: "Fixture Artist", artworkURL: nil)]
    }
    public func registerPush(installationID: UUID, token: String, environment: String, locale: String) async throws {}
    public func unregisterPush(installationID: UUID) async throws {}
    public func editorAvailable() async throws -> Bool { true }
    public func editorHandoffToken(projectID: UUID) async throws -> String { "fixture-token" }
    public func download(_ artifact: Artifact) async throws -> URL {
        FileManager.default.temporaryDirectory.appendingPathComponent("fixture.mid")
    }
}
