import Foundation

public enum OutputMode: String, Codable, CaseIterable, Sendable, Identifiable {
    case pianoCover = "piano_cover"
    case pianoTranscription = "piano_transcription"
    case notesChords = "notes_chords"
    case quickMIDI = "music2midi"
    case stems

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .pianoCover: "Piano cover"
        case .pianoTranscription: "Piano transcription"
        case .notesChords: "Notes & chords"
        case .quickMIDI: "Quick MIDI"
        case .stems: "Split into stems"
        }
    }

    public var detail: String {
        switch self {
        case .pianoCover: "Playable piano MIDI"
        case .pianoTranscription: "Accurate MIDI from a piano recording"
        case .notesChords: "Lead sheet and harmony"
        case .quickMIDI: "Fast universal audio transcription"
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
    public let sizeBytes: Int?
    public let mimeType: String
    public let downloadURL: String

    enum CodingKeys: String, CodingKey {
        case id, role
        case sizeBytes = "size_bytes"
        case mimeType = "mime_type"
        case downloadURL = "download_url"
    }

    public init(id: String, role: String, sizeBytes: Int? = nil, mimeType: String, downloadURL: String) {
        self.id = id
        self.role = role
        self.sizeBytes = sizeBytes
        self.mimeType = mimeType
        self.downloadURL = downloadURL
    }
}

public struct LibraryItem: Codable, Identifiable, Equatable, Hashable, Sendable {
    public let id: String
    public let projectID: UUID?
    public let engine: String
    public let status: String
    public let deliveryState: String?
    public let preparationState: String?
    public let title: String
    public let artifacts: [Artifact]

    enum CodingKeys: String, CodingKey {
        case id, engine, status, title, artifacts
        case projectID = "project_id"
        case deliveryState = "delivery_state"
        case preparationState = "preparation_state"
    }

    public var state: ProjectState {
        switch status {
        case "uploading": .uploading
        case "queued", "leased": .queued
        case "running", "processing": .processing
        case "ready": .ready
        case "succeeded": preparationState == nil || preparationState == "ready" ? .ready : .processing
        case "failed", "cancelled": .failed
        default: .processing
        }
    }

    public init(
        id: String,
        projectID: UUID?,
        engine: String,
        status: String,
        deliveryState: String? = nil,
        preparationState: String? = nil,
        title: String,
        artifacts: [Artifact]
    ) {
        self.id = id
        self.projectID = projectID
        self.engine = engine
        self.status = status
        self.deliveryState = deliveryState
        self.preparationState = preparationState
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

    public init(created: Bool, projectID: UUID, jobID: UUID, outputMode: OutputMode?) {
        self.created = created
        self.projectID = projectID
        self.jobID = jobID
        self.outputMode = outputMode
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        created = try container.decode(Bool.self, forKey: .created)
        projectID = try container.decode(UUID.self, forKey: .projectID)
        jobID = try container.decode(UUID.self, forKey: .jobID)
        outputMode = try container.decodeIfPresent(OutputMode.self, forKey: .outputMode)
    }
}

public struct EngineSubmitRequest: Codable, Sendable {
    public let engine: String
    public init(engine: String) { self.engine = engine }
}

public struct PianoProcessResponse: Codable, Sendable {
    public let created: Bool
    public let profileJobID: UUID
    public let jobID: UUID?

    enum CodingKeys: String, CodingKey {
        case created
        case profileJobID = "profile_job_id"
        case jobID = "job_id"
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

public struct EditorCapabilities: Codable, Sendable {
    public let enabled: Bool
}

public struct BrowserHandoffResponse: Codable, Sendable {
    public let handoffURL: String
    public let expiresSeconds: Int

    enum CodingKeys: String, CodingKey {
        case handoffURL = "handoff_url"
        case expiresSeconds = "expires_seconds"
    }
}

public struct BrowserHandoffRequest: Codable, Sendable {
    public let projectID: UUID
    enum CodingKeys: String, CodingKey { case projectID = "project_id" }
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
    case invalidInput(String)
    case unauthenticated
    case server(status: Int, detail: String)
    case decoding(String)

    public var errorDescription: String? {
        switch self {
        case .invalidResponse: "The server returned an invalid response."
        case let .invalidInput(detail): detail
        case .unauthenticated: "Sign in to continue."
        case let .server(_, detail): detail
        case let .decoding(detail): "Could not read the response: \(detail)"
        }
    }
}


public enum SourceValidator {
    public static let maximumFileBytes = 20 * 1024 * 1024
    public static let audioExtensions = Set(["mp3", "wav", "m4a", "ogg", "flac", "aac"])

    public static func supportedRemoteURL(_ value: String) -> URL? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard
            let components = URLComponents(string: trimmed),
            components.scheme?.lowercased() == "https",
            let host = components.host?.lowercased()
        else { return nil }

        let supported = host.hasPrefix("music.yandex.")
            || host == "open.spotify.com"
            || host == "youtube.com"
            || host.hasSuffix(".youtube.com")
            || host == "youtu.be"
            || host.hasSuffix(".youtu.be")
        return supported ? components.url : nil
    }

    public static func validateAudioFile(_ url: URL) throws {
        let suffix = url.pathExtension.lowercased()
        guard audioExtensions.contains(suffix) else {
            throw APIError.invalidInput("Choose an MP3, WAV, M4A, OGG, FLAC, or AAC file.")
        }
        let values = try url.resourceValues(forKeys: [.fileSizeKey, .isRegularFileKey])
        guard values.isRegularFile == true else {
            throw APIError.invalidInput("Choose a regular audio file.")
        }
        guard let size = values.fileSize, size > 0 else {
            throw APIError.invalidInput("The audio file is empty.")
        }
        guard size <= maximumFileBytes else {
            throw APIError.invalidInput("The audio file is larger than 20 MB.")
        }
    }
}
