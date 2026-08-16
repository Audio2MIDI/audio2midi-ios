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
}

public actor APIClient: Audio2MIDIService {
    private let baseURL: URL
    private let session: URLSession
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    public init(baseURL: URL = URL(string: "https://app.audio2midi.ru/api")!, session: URLSession = .shared) {
        self.baseURL = baseURL
        self.session = session
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
        try await send(
            path: "/v1/me/projects/\(projectID)/process",
            method: "POST",
            headers: ["Idempotency-Key": idempotencyKey],
            body: ProcessRequest(mode: mode),
            as: ProcessResponse.self
        )
    }

    public func create(fileURL: URL, mode: OutputMode) async throws -> ProcessResponse {
        let access = fileURL.startAccessingSecurityScopedResource()
        defer { if access { fileURL.stopAccessingSecurityScopedResource() } }
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
        let envelope: SourceImportEnvelope = try await send(
            path: "/v1/me/projects/import", method: "POST",
            headers: ["Idempotency-Key": "ios-import-\(SHA256.hash(data: Data(remoteValue.utf8)).description)"],
            body: SourceImportRequest(sourceKind: kind, sourceValue: remoteValue, title: title),
            as: SourceImportEnvelope.self
        )
        var item = envelope.import
        for _ in 0..<60 {
            if let projectID = item.projectID, item.status == "ready" {
                return try await process(projectID: projectID, mode: mode, idempotencyKey: "ios-import-process-\(item.id)-\(mode.rawValue)")
            }
            if item.status == "failed" { throw APIError.server(status: 422, detail: item.sanitizedError ?? "Could not import this source.") }
            try await Task.sleep(for: .seconds(2))
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
        catch { throw APIError.decoding(error.localizedDescription) }
    }
}

private struct AcceptedEnvelope: Codable { let accepted: Bool }
private struct ErrorEnvelope: Codable { let detail: String }
