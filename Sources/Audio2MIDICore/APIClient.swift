import Foundation
import CryptoKit
import UniformTypeIdentifiers

public protocol Audio2MIDIService: Sendable {
    func currentAccount() async throws -> Account
    func startEmailLogin(email: String) async throws
    func verifyEmail(email: String, code: String) async throws -> Account
    func library() async throws -> [LibraryItem]
    func process(projectID: UUID, mode: OutputMode, idempotencyKey: String) async throws -> ProcessResponse
    func create(fileURL: URL, mode: OutputMode) async throws -> ProcessResponse
    func create(remoteValue: String, kind: String, title: String?, mode: OutputMode) async throws -> ProcessResponse
    func searchCatalog(_ query: String) async throws -> [CatalogTrack]
    func registerPush(installationID: UUID, token: String, environment: String, locale: String) async throws
    func unregisterPush(installationID: UUID) async throws
    func editorAvailable() async throws -> Bool
    func editorHandoffToken(projectID: UUID) async throws -> String
    func download(_ artifact: Artifact) async throws -> URL
}

public actor APIClient: Audio2MIDIService {
    public static let productionBaseURL = URL(string: "https://api.audio2midi.ru")!

    private let baseURL: URL
    private let session: URLSession
    private let importPollInterval: Duration
    private let importPollAttempts: Int
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    public init(
        baseURL: URL = productionBaseURL,
        session: URLSession = .shared,
        importPollInterval: Duration = .seconds(2),
        importPollAttempts: Int = 150
    ) {
        self.baseURL = baseURL
        self.session = session
        self.importPollInterval = importPollInterval
        self.importPollAttempts = importPollAttempts
    }

    public func currentAccount() async throws -> Account {
        try await send(path: "/v1/me", as: AccountEnvelope.self).account
    }

    public func startEmailLogin(email: String) async throws {
        let _: AcceptedEnvelope = try await send(
            path: "/v1/auth/email/start",
            method: "POST",
            body: EmailStartRequest(email: email),
            as: AcceptedEnvelope.self
        )
    }

    public func verifyEmail(email: String, code: String) async throws -> Account {
        try await send(
            path: "/v1/auth/email/verify",
            method: "POST",
            body: EmailVerifyRequest(email: email, token: code),
            as: AccountEnvelope.self
        ).account
    }

    public func library() async throws -> [LibraryItem] {
        try await send(path: "/v1/me/library", as: LibraryEnvelope.self).items
    }

    public func process(projectID: UUID, mode: OutputMode, idempotencyKey: String) async throws -> ProcessResponse {
        switch mode {
        case .pianoTranscription:
            let result: PianoProcessResponse = try await send(
                path: "/v1/me/projects/\(projectID)/processing-requests",
                method: "POST",
                headers: ["Idempotency-Key": idempotencyKey],
                as: PianoProcessResponse.self
            )
            return ProcessResponse(
                created: result.created,
                projectID: projectID,
                jobID: result.jobID ?? result.profileJobID,
                outputMode: mode
            )
        case .quickMIDI:
            let result: ProcessResponse = try await send(
                path: "/v1/me/projects/\(projectID)/submit",
                method: "POST",
                headers: ["Idempotency-Key": idempotencyKey],
                body: EngineSubmitRequest(engine: mode.rawValue),
                as: ProcessResponse.self
            )
            return ProcessResponse(
                created: result.created,
                projectID: result.projectID,
                jobID: result.jobID,
                outputMode: mode
            )
        case .pianoCover, .notesChords, .stems:
            return try await send(
                path: "/v1/me/projects/\(projectID)/process",
                method: "POST",
                headers: ["Idempotency-Key": idempotencyKey],
                body: ProcessRequest(mode: mode),
                as: ProcessResponse.self
            )
        }
    }

    public func create(fileURL: URL, mode: OutputMode) async throws -> ProcessResponse {
        let access = fileURL.startAccessingSecurityScopedResource()
        defer { if access { fileURL.stopAccessingSecurityScopedResource() } }
        try SourceValidator.validateAudioFile(fileURL)
        let data = try Data(contentsOf: fileURL)
        let digest = SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
        let mime = UTType(filenameExtension: fileURL.pathExtension)?.preferredMIMEType ?? "application/octet-stream"
        let upload: ProjectUploadEnvelope = try await send(
            path: "/v1/me/projects/presign",
            method: "POST",
            body: ProjectUploadRequest(title: fileURL.deletingPathExtension().lastPathComponent, filename: fileURL.lastPathComponent, sha256: digest, sizeBytes: data.count, mimeType: mime),
            as: ProjectUploadEnvelope.self
        )
        guard let uploadURL = URL(string: upload.uploadURL, relativeTo: baseURL) else { throw APIError.invalidResponse }
        var request = URLRequest(url: uploadURL)
        request.httpMethod = "PUT"
        request.httpBody = data
        for (key, value) in upload.requiredHeaders { request.setValue(value, forHTTPHeaderField: key) }
        let (_, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse, 200..<300 ~= http.statusCode else { throw APIError.server(status: (response as? HTTPURLResponse)?.statusCode ?? 0, detail: "Audio upload failed.") }
        return try await process(projectID: upload.project.id, mode: mode, idempotencyKey: "ios-file-\(upload.project.id)-\(mode.rawValue)")
    }

    public func create(remoteValue: String, kind: String, title: String?, mode: OutputMode) async throws -> ProcessResponse {
        let trimmedValue = remoteValue.trimmingCharacters(in: .whitespacesAndNewlines)
        if kind == "url", SourceValidator.supportedRemoteURL(trimmedValue) == nil {
            throw APIError.invalidInput("Paste an HTTPS link from Yandex Music, Spotify, or YouTube.")
        }
        let sourceDigest = SHA256.hash(data: Data(trimmedValue.utf8)).map { String(format: "%02x", $0) }.joined()
        let envelope: SourceImportEnvelope = try await send(
            path: "/v1/me/projects/import", method: "POST",
            headers: ["Idempotency-Key": "ios-import-\(sourceDigest)"],
            body: SourceImportRequest(sourceKind: kind, sourceValue: trimmedValue, title: title),
            as: SourceImportEnvelope.self
        )
        var item = envelope.import
        for _ in 0..<importPollAttempts {
            if let projectID = item.projectID, item.status == "ready" {
                return try await process(projectID: projectID, mode: mode, idempotencyKey: "ios-import-process-\(item.id)-\(mode.rawValue)")
            }
            if item.status == "failed" { throw APIError.server(status: 422, detail: item.sanitizedError ?? "Could not import this source.") }
            if item.status == "cancelled" { throw APIError.server(status: 409, detail: "Source import was cancelled.") }
            try await Task.sleep(for: importPollInterval)
            item = try await send(path: "/v1/me/project-imports/\(item.id)", as: SourceImportEnvelope.self).import
        }
        throw APIError.server(status: 408, detail: "Import is taking longer than expected. It will remain in your library.")
    }

    public func searchCatalog(_ query: String) async throws -> [CatalogTrack] {
        struct Search: Codable { let query: String }
        return try await send(path: "/v1/me/catalog/search", method: "POST", body: Search(query: query), as: CatalogEnvelope.self).tracks
    }

    public func registerPush(installationID: UUID, token: String, environment: String, locale: String) async throws {
        struct Response: Codable {}
        let _: Response = try await send(
            path: "/v1/me/push-devices/\(installationID)", method: "PUT",
            body: PushRegistration(token: token, environment: environment, locale: locale), as: Response.self
        )
    }

    public func unregisterPush(installationID: UUID) async throws {
        try await sendVoid(path: "/v1/me/push-devices/\(installationID)", method: "DELETE")
    }

    public func editorAvailable() async throws -> Bool {
        try await send(path: "/v1/me/editor/capabilities", as: EditorCapabilities.self).enabled
    }

    public func editorHandoffToken(projectID: UUID) async throws -> String {
        let result: BrowserHandoffResponse = try await send(
            path: "/v1/me/browser-handoffs",
            method: "POST",
            body: BrowserHandoffRequest(projectID: projectID),
            as: BrowserHandoffResponse.self
        )
        guard
            let components = URLComponents(string: result.handoffURL),
            let token = components.fragment?.split(separator: "&")
                .first(where: { $0.hasPrefix("token=") })?
                .dropFirst("token=".count),
            !token.isEmpty
        else { throw APIError.invalidResponse }
        return String(token)
    }

    public func download(_ artifact: Artifact) async throws -> URL {
        let url = try resolvedAPIURL(for: artifact.downloadURL)
        var request = URLRequest(url: url)
        request.setValue("application/octet-stream", forHTTPHeaderField: "Accept")
        let (temporaryURL, response) = try await session.download(for: request)
        guard let http = response as? HTTPURLResponse else { throw APIError.invalidResponse }
        if http.statusCode == 401 { throw APIError.unauthenticated }
        guard 200..<300 ~= http.statusCode else {
            throw APIError.server(status: http.statusCode, detail: "Could not download this file.")
        }

        let role = artifact.role
            .replacingOccurrences(of: "[^A-Za-z0-9_-]", with: "-", options: .regularExpression)
        let destination = FileManager.default.temporaryDirectory
            .appendingPathComponent("Audio2MIDI-\(role)-\(artifact.id).\(fileExtension(for: artifact.mimeType))")
        try? FileManager.default.removeItem(at: destination)
        try FileManager.default.moveItem(at: temporaryURL, to: destination)
        return destination
    }

    private func send<Response: Decodable>(
        path: String,
        method: String = "GET",
        headers: [String: String] = [:],
        as type: Response.Type
    ) async throws -> Response {
        try await request(path: path, method: method, headers: headers, data: nil, as: type)
    }

    private func send<Body: Encodable, Response: Decodable>(
        path: String,
        method: String,
        headers: [String: String] = [:],
        body: Body,
        as type: Response.Type
    ) async throws -> Response {
        try await request(path: path, method: method, headers: headers, data: encoder.encode(body), as: type)
    }

    private func request<Response: Decodable>(
        path: String,
        method: String,
        headers: [String: String],
        data: Data?,
        as type: Response.Type
    ) async throws -> Response {
        guard let url = URL(string: path, relativeTo: baseURL) else { throw APIError.invalidResponse }
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.httpBody = data
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if data != nil { request.setValue("application/json", forHTTPHeaderField: "Content-Type") }
        for (key, value) in headers { request.setValue(value, forHTTPHeaderField: key) }
        let (payload, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw APIError.invalidResponse }
        if http.statusCode == 401 { throw APIError.unauthenticated }
        guard 200..<300 ~= http.statusCode else {
            let detail = (try? decoder.decode(ErrorEnvelope.self, from: payload).detail) ?? "Request failed."
            throw APIError.server(status: http.statusCode, detail: detail)
        }
        do { return try decoder.decode(Response.self, from: payload) }
        catch { throw APIError.decoding(String(describing: error)) }
    }

    private func sendVoid(path: String, method: String) async throws {
        guard let url = URL(string: path, relativeTo: baseURL) else { throw APIError.invalidResponse }
        var request = URLRequest(url: url)
        request.httpMethod = method
        let (_, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw APIError.invalidResponse }
        if http.statusCode == 401 { throw APIError.unauthenticated }
        guard 200..<300 ~= http.statusCode else {
            throw APIError.server(status: http.statusCode, detail: "Request failed.")
        }
    }

    func resolvedAPIURL(for value: String) throws -> URL {
        if let absolute = URL(string: value), absolute.scheme != nil {
            guard absolute.scheme == "https" else { throw APIError.invalidResponse }
            if absolute.host == "app.audio2midi.ru", absolute.path.hasPrefix("/api/") {
                return try resolvedAPIURL(for: String(absolute.path.dropFirst(4)))
            }
            guard absolute.host == baseURL.host else { throw APIError.invalidResponse }
            return absolute
        }
        let path = value.hasPrefix("/api/") ? String(value.dropFirst(4)) : value
        guard let url = URL(string: path, relativeTo: baseURL)?.absoluteURL else { throw APIError.invalidResponse }
        return url
    }

    private func fileExtension(for mimeType: String) -> String {
        switch mimeType.lowercased().split(separator: ";", maxSplits: 1).first.map(String.init) {
        case "audio/midi", "audio/x-midi": "mid"
        case "application/pdf": "pdf"
        case "audio/mpeg", "audio/mp3": "mp3"
        case "audio/wav", "audio/x-wav": "wav"
        case "audio/mp4", "audio/x-m4a": "m4a"
        case "audio/flac": "flac"
        case "application/zip": "zip"
        default: "bin"
        }
    }
}

private struct AcceptedEnvelope: Codable { let accepted: Bool }
private struct ErrorEnvelope: Codable { let detail: String }
