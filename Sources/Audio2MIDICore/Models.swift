import Foundation

public enum OutputMode: String, Codable, CaseIterable, Sendable, Identifiable {
    case pianoCover = "piano_cover"
    case notesChords = "notes_chords"
    case stems

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .pianoCover: "Piano cover"
        case .notesChords: "Notes & chords"
        case .stems: "Split into stems"
        }
    }

    public var detail: String {
        switch self {
        case .pianoCover: "Playable piano MIDI"
        case .notesChords: "Lead sheet and harmony"
        case .stems: "Vocals, drums, bass and more"
        }
    }
}

public enum ProjectState: String, Codable, Sendable {
    case uploading, queued, processing, ready, failed
}

public struct Account: Codable, Equatable, Sendable {
    public let accountID: UUID
    public let username: String?
    public let remainingRequests: Int?
    public let unreadNotificationCount: Int

    enum CodingKeys: String, CodingKey {
        case accountID = "account_id"
        case username
        case remainingRequests = "remaining_requests"
        case unreadNotificationCount = "unread_notification_count"
    }

    public init(accountID: UUID, username: String?, remainingRequests: Int?, unreadNotificationCount: Int) {
        self.accountID = accountID
        self.username = username
        self.remainingRequests = remainingRequests
        self.unreadNotificationCount = unreadNotificationCount
    }
}

public struct AccountEnvelope: Codable, Sendable {
    public let account: Account
}

public struct Artifact: Codable, Identifiable, Equatable, Hashable, Sendable {
    public let id: String
    public let role: String
    public let mimeType: String
    public let downloadURL: String

    enum CodingKeys: String, CodingKey {
        case id, role
        case mimeType = "mime_type"
        case downloadURL = "download_url"
    }

    public init(id: String, role: String, mimeType: String, downloadURL: String) {
        self.id = id
        self.role = role
        self.mimeType = mimeType
        self.downloadURL = downloadURL
    }
}

public struct LibraryItem: Codable, Identifiable, Equatable, Hashable, Sendable {
    public let id: String
    public let projectID: UUID?
    public let engine: String
    public let status: String
    public let title: String
    public let artifacts: [Artifact]

    enum CodingKeys: String, CodingKey {
        case id, engine, status, title, artifacts
        case projectID = "project_id"
    }

    public var state: ProjectState { ProjectState(rawValue: status) ?? .processing }

    public init(id: String, projectID: UUID?, engine: String, status: String, title: String, artifacts: [Artifact]) {
        self.id = id
        self.projectID = projectID
        self.engine = engine
        self.status = status
        self.title = title
        self.artifacts = artifacts
    }
}

public struct LibraryEnvelope: Codable, Sendable {
    public let items: [LibraryItem]
}

public struct ProcessRequest: Codable, Sendable {
    public let mode: OutputMode
    public init(mode: OutputMode) { self.mode = mode }
}

public struct ProcessResponse: Codable, Sendable {
    public let created: Bool
    public let projectID: UUID
    public let jobID: UUID
    public let outputMode: OutputMode?

    enum CodingKeys: String, CodingKey {
        case created
        case projectID = "project_id"
        case jobID = "job_id"
        case outputMode = "output_mode"
    }
}

public struct CatalogTrack: Codable, Identifiable, Equatable, Sendable {
    public let sourceID: String
    public let title: String
    public let artist: String
    public let artworkURL: String?
    public var id: String { sourceID }
    enum CodingKeys: String, CodingKey {
        case sourceID = "source_id"
        case title, artist
        case artworkURL = "artwork_url"
    }
}

public struct CatalogEnvelope: Codable, Sendable { public let tracks: [CatalogTrack] }

public struct ProjectUploadRequest: Codable, Sendable {
    public let title: String
    public let filename: String
    public let sha256: String
    public let sizeBytes: Int
    public let mimeType: String
    enum CodingKeys: String, CodingKey {
        case title, filename, sha256
        case sizeBytes = "size_bytes"
        case mimeType = "mime_type"
    }
}

public struct ProjectUploadEnvelope: Codable, Sendable {
    public struct Project: Codable, Sendable { public let id: UUID }
    public let project: Project
    public let uploadURL: String
    public let requiredHeaders: [String: String]
    enum CodingKeys: String, CodingKey {
        case project
        case uploadURL = "upload_url"
        case requiredHeaders = "required_headers"
    }
}

public struct SourceImportRequest: Codable, Sendable {
    public let sourceKind: String
    public let sourceValue: String
    public let title: String?
    enum CodingKeys: String, CodingKey {
        case sourceKind = "source_kind"
        case sourceValue = "source_value"
        case title
    }
}

public struct SourceImport: Codable, Sendable {
    public let id: UUID
    public let status: String
    public let projectID: UUID?
    public let sanitizedError: String?
    enum CodingKeys: String, CodingKey {
        case id, status
        case projectID = "project_id"
        case sanitizedError = "sanitized_error"
    }
}

public struct SourceImportEnvelope: Codable, Sendable { public let `import`: SourceImport }

public struct PushRegistration: Codable, Sendable {
    public let token: String
    public let environment: String
    public let locale: String
}

public struct EmailStartRequest: Codable, Sendable {
    public let email: String
    public init(email: String) { self.email = email }
}

public struct EmailVerifyRequest: Codable, Sendable {
    public let email: String
    public let token: String
    public init(email: String, token: String) { self.email = email; self.token = token }
}

public enum APIError: Error, Equatable, LocalizedError, Sendable {
    case invalidResponse
    case unauthenticated
    case server(status: Int, detail: String)
    case decoding(String)

    public var errorDescription: String? {
        switch self {
        case .invalidResponse: "The server returned an invalid response."
        case .unauthenticated: "Sign in to continue."
        case let .server(_, detail): detail
        case let .decoding(detail): "Could not read the response: \(detail)"
        }
    }
}
