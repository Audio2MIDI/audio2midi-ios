import Foundation
import Testing
@testable import Audio2MIDICore

@Test func outputModesKeepBackendWireValues() {
    #expect(OutputMode.pianoCover.rawValue == "piano_cover")
    #expect(OutputMode.notesChords.rawValue == "notes_chords")
    #expect(OutputMode.stems.rawValue == "stems")
}

@Test func fixtureServiceProvidesDeterministicReadyState() async throws {
    let service = FixtureService(scenario: .ready)
    let library = try await service.library()
    #expect(library.count == 2)
    #expect(library.first?.state == .ready)
    #expect(library.first?.artifacts.first?.role == "midi")
}

@Test func libraryDecodesSnakeCaseContract() throws {
    let data = #"{"items":[{"id":"1","project_id":"018f7777-9c82-72a5-b4b7-b15ce341dc13","engine":"picogen","status":"ready","title":"Demo","artifacts":[]}] }"#.data(using: .utf8)!
    let response = try JSONDecoder().decode(LibraryEnvelope.self, from: data)
    #expect(response.items.first?.projectID != nil)
}
