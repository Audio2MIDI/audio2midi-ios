import Audio2MIDICore
import AVFoundation
import SwiftUI
import UniformTypeIdentifiers

struct CreateView: View {
    enum Source: String, CaseIterable, Identifiable {
        case file = "File", record = "Record", link = "Link", search = "Search"
        var id: String { rawValue }
        var icon: String { switch self { case .file: "folder"; case .record: "mic"; case .link: "link"; case .search: "magnifyingglass" } }
    }

    @Bindable var model: AppModel
    @State private var source: Source = .file
    @State private var mode: OutputMode = .pianoCover
    @State private var showingImporter = false
    @State private var selectedFile: URL?
    @State private var sourceText = ""
    @State private var isRecording = false
    @State private var searchResults: [CatalogTrack] = []
    @State private var selectedTrack: CatalogTrack?
    @State private var isSubmitting = false
    @StateObject private var recorder = VoiceRecorder()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 26) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Make music usable.")
                        .font(.system(size: 31, weight: .bold, design: .rounded))
                    Text("Choose a source and what you want back.")
                        .foregroundStyle(StudioColor.secondary)
                }
                SourcePicker(selection: $source)
                sourcePanel
                SectionLabel(text: "Output")
                VStack(spacing: 10) {
                    ForEach(OutputMode.allCases) { candidate in
                        Button { mode = candidate } label: {
                            HStack(spacing: 14) {
                                Image(systemName: icon(for: candidate)).frame(width: 28).foregroundStyle(mode == candidate ? StudioColor.blue : .white)
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(candidate.title).font(.system(size: 16, weight: .semibold))
                                    Text(candidate.detail).font(.system(size: 13)).foregroundStyle(StudioColor.secondary)
                                }
                                Spacer()
                                Image(systemName: mode == candidate ? "checkmark.circle.fill" : "circle").foregroundStyle(mode == candidate ? StudioColor.blue : StudioColor.secondary)
                            }
                            .padding(16).background(StudioColor.surface).clipShape(RoundedRectangle(cornerRadius: 14))
                            .overlay(RoundedRectangle(cornerRadius: 14).stroke(mode == candidate ? StudioColor.blue : StudioColor.line, lineWidth: 1))
                        }.buttonStyle(.plain).accessibilityIdentifier("mode.\(candidate.rawValue)")
                    }
                }
                Button(isSubmitting ? "Creating…" : "Create \(mode.title)") { Task { await submit() } }
                    .disabled(!canSubmit || isSubmitting)
                    .buttonStyle(StudioButtonStyle(prominent: true))
                    .accessibilityIdentifier("create.submit")
            }.padding(20)
        }
        .background(StudioColor.black)
        .navigationTitle("Create")
        .navigationBarTitleDisplayMode(.inline)
        .fileImporter(isPresented: $showingImporter, allowedContentTypes: [.audio, .mpeg4Audio, .mp3]) { result in
            if case let .success(url) = result { selectedFile = url }
        }
    }

    @ViewBuilder private var sourcePanel: some View {
        switch source {
        case .file:
            Button { showingImporter = true } label: {
                VStack(spacing: 13) {
                    Image(systemName: selectedFile == nil ? "arrow.up.doc" : "checkmark.circle.fill").font(.system(size: 30)).foregroundStyle(StudioColor.blue)
                    Text(selectedFile?.lastPathComponent ?? "Choose an audio file").font(.system(size: 16, weight: .semibold)).lineLimit(1)
                    Text("MP3, WAV, M4A, FLAC · up to 20 MB").font(.caption).foregroundStyle(StudioColor.secondary)
                }.frame(maxWidth: .infinity, minHeight: 150).background(StudioColor.surface).clipShape(RoundedRectangle(cornerRadius: 16))
                    .overlay(RoundedRectangle(cornerRadius: 16).stroke(StudioColor.line, style: StrokeStyle(lineWidth: 1, dash: [6])))
            }.buttonStyle(.plain).accessibilityIdentifier("source.file.choose")
        case .record:
            Button { Task { await toggleRecording() } } label: {
                VStack(spacing: 13) {
                    ZStack { Circle().fill(isRecording ? StudioColor.danger : StudioColor.blue).frame(width: 64, height: 64); Image(systemName: isRecording ? "stop.fill" : "mic.fill").font(.title2).foregroundStyle(.white) }
                    Text(isRecording ? "Recording… tap to stop" : "Tap to record").font(.system(size: 16, weight: .semibold))
                    Text("Microphone access is requested only now").font(.caption).foregroundStyle(StudioColor.secondary)
                }.frame(maxWidth: .infinity, minHeight: 170).background(StudioColor.surface).clipShape(RoundedRectangle(cornerRadius: 16))
            }.buttonStyle(.plain).accessibilityIdentifier("source.record.toggle")
        case .link:
            inputPanel(icon: "link", placeholder: "Paste YouTube, Yandex Music, or Spotify link")
        case .search:
            VStack(spacing: 10) {
                inputPanel(icon: "magnifyingglass", placeholder: "Song or artist")
                Button("Search catalog") { Task { await search() } }
                    .buttonStyle(StudioButtonStyle(prominent: false))
                    .disabled(sourceText.count < 2)
                ForEach(searchResults) { track in
                    Button { selectedTrack = track } label: {
                        HStack {
                            VStack(alignment: .leading) { Text(track.title).fontWeight(.semibold); Text(track.artist).font(.caption).foregroundStyle(StudioColor.secondary) }
                            Spacer(); Image(systemName: selectedTrack?.id == track.id ? "checkmark.circle.fill" : "circle").foregroundStyle(StudioColor.blue)
                        }.padding(14).background(StudioColor.surface).clipShape(RoundedRectangle(cornerRadius: 12))
                    }.buttonStyle(.plain)
                }
            }
        }
    }

    private func inputPanel(icon: String, placeholder: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon).foregroundStyle(StudioColor.blue)
            TextField(placeholder, text: $sourceText).textInputAutocapitalization(.never).autocorrectionDisabled()
            if !sourceText.isEmpty { Button { sourceText = "" } label: { Image(systemName: "xmark.circle.fill").foregroundStyle(StudioColor.secondary) } }
        }.padding(16).background(StudioColor.surface).clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private func icon(for mode: OutputMode) -> String {
        switch mode { case .pianoCover: "pianokeys"; case .notesChords: "music.note.list"; case .stems: "slider.horizontal.3" }
    }

    private func toggleRecording() async {
        if isRecording {
            selectedFile = recorder.stop()
            isRecording = false
            return
        }
        let allowed = await AVAudioApplication.requestRecordPermission()
        if allowed {
            do { try recorder.start(); isRecording = true }
            catch { model.errorMessage = error.localizedDescription }
        } else { model.errorMessage = "Microphone access is disabled in Settings." }
    }

    private var canSubmit: Bool {
        switch source {
        case .file, .record: selectedFile != nil
        case .link: URL(string: sourceText)?.scheme != nil
        case .search: selectedTrack != nil
        }
    }

    private func search() async {
        do { searchResults = try await model.service.searchCatalog(sourceText) }
        catch { model.errorMessage = error.localizedDescription }
    }

    private func submit() async {
        isSubmitting = true
        defer { isSubmitting = false }
        do {
            switch source {
            case .file, .record:
                guard let selectedFile else { return }
                _ = try await model.service.create(fileURL: selectedFile, mode: mode)
            case .link:
                _ = try await model.service.create(remoteValue: sourceText, kind: "url", title: nil, mode: mode)
            case .search:
                guard let selectedTrack else { return }
                _ = try await model.service.create(remoteValue: selectedTrack.sourceID, kind: "catalog_track", title: "\(selectedTrack.artist) — \(selectedTrack.title)", mode: mode)
            }
            await model.refreshLibrary()
            model.selectedTab = 0
        } catch { model.errorMessage = error.localizedDescription }
    }
}

@MainActor
private final class VoiceRecorder: NSObject, ObservableObject {
    private var recorder: AVAudioRecorder?
    private var fileURL: URL?

    func start() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("audio2midi-\(UUID().uuidString).m4a")
        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 44_100,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue,
        ]
        try AVAudioSession.sharedInstance().setCategory(.record, mode: .default)
        try AVAudioSession.sharedInstance().setActive(true)
        let recorder = try AVAudioRecorder(url: url, settings: settings)
        guard recorder.record() else { throw CocoaError(.fileWriteUnknown) }
        self.recorder = recorder
        fileURL = url
    }

    func stop() -> URL? {
        recorder?.stop()
        try? AVAudioSession.sharedInstance().setActive(false)
        recorder = nil
        return fileURL
    }
}

private struct SourcePicker: View {
    @Binding var selection: CreateView.Source
    var body: some View {
        HStack(spacing: 4) {
            ForEach(CreateView.Source.allCases) { item in
                Button { selection = item } label: {
                    VStack(spacing: 7) { Image(systemName: item.icon); Text(item.rawValue).font(.caption.weight(.medium)) }
                        .frame(maxWidth: .infinity, minHeight: 62)
                        .foregroundStyle(selection == item ? .white : StudioColor.secondary)
                        .background(selection == item ? StudioColor.raised : Color.clear)
                        .clipShape(RoundedRectangle(cornerRadius: 11))
                }.buttonStyle(.plain).accessibilityIdentifier("source.\(item.rawValue.lowercased())")
            }
        }.padding(4).background(StudioColor.surface).clipShape(RoundedRectangle(cornerRadius: 14))
    }
}
