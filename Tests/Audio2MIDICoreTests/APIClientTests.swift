import Foundation
import Testing
@testable import Audio2MIDICore

@Test func outputModesKeepBackendWireValues() {
    #expect(OutputMode.allCases.map(\.rawValue) == [
        "piano_cover", "piano_transcription", "notes_chords", "music2midi", "stems",
    ])
}

@Test func fixtureServiceProvidesDeterministicReadyState() async throws {
    let service = FixtureService(scenario: .ready)
    let library = try await service.library()
    #expect(library.count == 2)
    #expect(library.first?.state == .ready)
    #expect(library.first?.artifacts.first?.role == "midi")
}

@Test func libraryMapsActualProductionJobStates() throws {
    let data = #"{"items":[{"id":"ready","project_id":"018f7777-9c82-72a5-b4b7-b15ce341dc13","engine":"picogen","status":"succeeded","delivery_state":"delivered","preparation_state":"ready","title":"Ready","artifacts":[]},{"id":"post","engine":"sheetsage","status":"succeeded","preparation_state":"preparing","title":"Post-processing","artifacts":[]},{"id":"run","engine":"music2midi","status":"running","title":"Running","artifacts":[]},{"id":"lease","engine":"picogen","status":"leased","title":"Leased","artifacts":[]},{"id":"cancel","engine":"picogen","status":"cancelled","title":"Cancelled","artifacts":[]}]}"#.data(using: .utf8)!
    let items = try JSONDecoder().decode(LibraryEnvelope.self, from: data).items
    #expect(items.map(\.state) == [.ready, .processing, .processing, .queued, .failed])
}

@Test func productionAPIPathDoesNotResolveToTheMiniappHTML() {
    let url = URL(string: "/v1/auth/capabilities", relativeTo: APIClient.productionBaseURL)
    #expect(url?.absoluteString == "https://api.audio2midi.ru/v1/auth/capabilities")
}

@Test func submissionBodiesMatchTheBackendContract() throws {
    let encoder = JSONEncoder()
    #expect(String(decoding: try encoder.encode(ProcessRequest(mode: .pianoCover)), as: UTF8.self) == #"{"mode":"piano_cover"}"#)
    #expect(String(decoding: try encoder.encode(EngineSubmitRequest(engine: "music2midi")), as: UTF8.self) == #"{"engine":"music2midi"}"#)
    #expect(String(decoding: try encoder.encode(BrowserHandoffRequest(projectID: UUID(uuidString: "77777777-7777-4777-8777-777777777777")!)), as: UTF8.self) == #"{"project_id":"77777777-7777-4777-8777-777777777777"}"#)
}

@Test func directSubmitResponseMayOmitOutputMode() throws {
    let data = #"{"created":true,"project_id":"11111111-1111-4111-8111-111111111111","job_id":"22222222-2222-4222-8222-222222222222"}"#.data(using: .utf8)!
    let response = try JSONDecoder().decode(ProcessResponse.self, from: data)
    #expect(response.outputMode == nil)
}

@Test(arguments: [
    "https://music.yandex.ru/album/123/track/456",
    " https://music.yandex.kz/album/123/track/456 ",
    "https://open.spotify.com/track/abc",
    "https://youtu.be/abc",
    "https://music.youtube.com/watch?v=abc",
])
func supportedMusicLinksAreAccepted(value: String) {
    #expect(SourceValidator.supportedRemoteURL(value) != nil)
}

@Test(arguments: [
    "http://music.yandex.ru/track/1",
    "javascript:alert(1)",
    "https://example.com/song",
    "not a link",
])
func unsupportedLinksAreRejected(value: String) {
    #expect(SourceValidator.supportedRemoteURL(value) == nil)
}

@Test func audioFileValidationMirrorsTheWebLimit() throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: directory) }

    let valid = directory.appendingPathComponent("recording.m4a")
    try Data([1, 2, 3]).write(to: valid)
    try SourceValidator.validateAudioFile(valid)

    let wrongType = directory.appendingPathComponent("notes.txt")
    try Data([1]).write(to: wrongType)
    #expect(throws: APIError.self) { try SourceValidator.validateAudioFile(wrongType) }

    let tooLarge = directory.appendingPathComponent("large.wav")
    FileManager.default.createFile(atPath: tooLarge.path, contents: nil)
    let handle = try FileHandle(forWritingTo: tooLarge)
    try handle.truncate(atOffset: UInt64(SourceValidator.maximumFileBytes + 1))
    try handle.close()
    #expect(throws: APIError.self) { try SourceValidator.validateAudioFile(tooLarge) }
}

@Suite(.serialized)
struct APIClientNetworkTests {
    @Test func productModesUseTheCorrectProductionRoutes() async throws {
        let projectID = UUID(uuidString: "11111111-1111-4111-8111-111111111111")!
        let jobID = UUID(uuidString: "22222222-2222-4222-8222-222222222222")!
        let profileID = UUID(uuidString: "33333333-3333-4333-8333-333333333333")!
        let recorder = RequestRecorder()
        let client = makeClient(recorder: recorder) { request in
            switch request.url!.path {
            case "/v1/me/projects/\(projectID)/process":
                return .json(200, #"{"created":true,"project_id":"\#(projectID)","job_id":"\#(jobID)","output_mode":"piano_cover"}"#)
            case "/v1/me/projects/\(projectID)/submit":
                return .json(200, #"{"created":true,"project_id":"\#(projectID)","job_id":"\#(jobID)"}"#)
            case "/v1/me/projects/\(projectID)/processing-requests":
                return .json(200, #"{"created":true,"profile_job_id":"\#(profileID)","job_id":null}"#)
            default: throw MockFailure.unexpected(request.url!.absoluteString)
            }
        }

        _ = try await client.process(projectID: projectID, mode: .pianoCover, idempotencyKey: "cover")
        _ = try await client.process(projectID: projectID, mode: .quickMIDI, idempotencyKey: "quick")
        let piano = try await client.process(projectID: projectID, mode: .pianoTranscription, idempotencyKey: "piano")

        let requests = recorder.requests
        #expect(requests.map { $0.url!.path } == [
            "/v1/me/projects/\(projectID)/process",
            "/v1/me/projects/\(projectID)/submit",
            "/v1/me/projects/\(projectID)/processing-requests",
        ])
        #expect(piano.jobID == profileID)
        #expect(piano.outputMode == .pianoTranscription)
    }

    @Test func yandexImportPollsUntilReadyThenProcesses() async throws {
        let importID = UUID(uuidString: "44444444-4444-4444-8444-444444444444")!
        let projectID = UUID(uuidString: "55555555-5555-4555-8555-555555555555")!
        let jobID = UUID(uuidString: "66666666-6666-4666-8666-666666666666")!
        let recorder = RequestRecorder()
        let client = makeClient(recorder: recorder, pollInterval: .zero) { request in
            switch (request.httpMethod, request.url!.path) {
            case ("POST", "/v1/me/projects/import"):
                return .json(202, #"{"created":true,"import":{"id":"\#(importID)","status":"queued"}}"#)
            case ("GET", "/v1/me/project-imports/\(importID)"):
                return .json(200, #"{"import":{"id":"\#(importID)","status":"ready","project_id":"\#(projectID)"}}"#)
            case ("POST", "/v1/me/projects/\(projectID)/process"):
                return .json(200, #"{"created":true,"project_id":"\#(projectID)","job_id":"\#(jobID)","output_mode":"notes_chords"}"#)
            default: throw MockFailure.unexpected(request.url!.absoluteString)
            }
        }

        let result = try await client.create(
            remoteValue: "  https://music.yandex.ru/album/123/track/456  ",
            kind: "url",
            title: nil,
            mode: .notesChords
        )

        #expect(result.projectID == projectID)
        #expect(recorder.requests.map { $0.url!.path } == [
            "/v1/me/projects/import",
            "/v1/me/project-imports/\(importID)",
            "/v1/me/projects/\(projectID)/process",
        ])
    }

    @Test func editorHandoffAndArtifactURLsStayOnAuthenticatedBoundaries() async throws {
        let projectID = UUID(uuidString: "77777777-7777-4777-8777-777777777777")!
        let recorder = RequestRecorder()
        let client = makeClient(recorder: recorder) { request in
            .json(201, #"{"handoff_url":"/handoff#token=secure-token-value","expires_seconds":300}"#)
        }

        let token = try await client.editorHandoffToken(projectID: projectID)
        let direct = try await client.resolvedAPIURL(for: "/api/v1/me/artifacts/abc/download")

        #expect(token == "secure-token-value")
        #expect(recorder.requests.first?.url?.path == "/v1/me/browser-handoffs")
        #expect(direct.absoluteString == "https://api.audio2midi.ru/v1/me/artifacts/abc/download")
    }
}

private func makeClient(
    recorder: RequestRecorder,
    pollInterval: Duration = .seconds(2),
    handler: @escaping @Sendable (URLRequest) throws -> MockResponse
) -> APIClient {
    let configuration = URLSessionConfiguration.ephemeral
    configuration.protocolClasses = [MockURLProtocol.self]
    MockURLProtocol.router.configure(recorder: recorder, handler: handler)
    return APIClient(
        session: URLSession(configuration: configuration),
        importPollInterval: pollInterval,
        importPollAttempts: 3
    )
}

private struct MockResponse: Sendable {
    let status: Int
    let data: Data
    static func json(_ status: Int, _ body: String) -> MockResponse {
        MockResponse(status: status, data: Data(body.utf8))
    }
}

private enum MockFailure: Error { case unexpected(String) }

private final class RequestRecorder: @unchecked Sendable {
    private let lock = NSLock()
    private var storage: [URLRequest] = []
    var requests: [URLRequest] { lock.withLock { storage } }
    func append(_ request: URLRequest) { lock.withLock { storage.append(request) } }
}

private final class MockRouter: @unchecked Sendable {
    private let lock = NSLock()
    private var recorder: RequestRecorder?
    private var handler: (@Sendable (URLRequest) throws -> MockResponse)?

    func configure(
        recorder: RequestRecorder,
        handler: @escaping @Sendable (URLRequest) throws -> MockResponse
    ) {
        lock.withLock {
            self.recorder = recorder
            self.handler = handler
        }
    }

    func response(for request: URLRequest) throws -> MockResponse {
        let state = lock.withLock { (recorder, handler) }
        state.0?.append(request)
        guard let handler = state.1 else { throw MockFailure.unexpected("missing handler") }
        return try handler(request)
    }
}

private final class MockURLProtocol: URLProtocol, @unchecked Sendable {
    static let router = MockRouter()
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        do {
            let result = try Self.router.response(for: request)
            let response = HTTPURLResponse(
                url: request.url!, statusCode: result.status, httpVersion: "HTTP/1.1",
                headerFields: ["Content-Type": "application/json"]
            )!
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: result.data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }
    override func stopLoading() {}
}
