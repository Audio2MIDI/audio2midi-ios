import Audio2MIDICore
import SwiftUI
import UIKit

struct LibraryView: View {
    @Bindable var model: AppModel
    var body: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                if model.library.isEmpty && !model.isLoading {
                    ContentUnavailableView {
                        Label("No projects yet", systemImage: "waveform.badge.plus")
                    } description: {
                        Text("Your converted tracks will appear here.")
                    } actions: {
                        Button("Create your first") { model.selectedTab = 1 }
                            .buttonStyle(.borderedProminent)
                    }
                    .frame(minHeight: 480)
                    .accessibilityIdentifier("library.empty")
                } else {
                    ForEach(model.library) { item in
                        NavigationLink(value: item) { ProjectRow(item: item) }
                            .buttonStyle(.plain)
                        Divider().overlay(StudioColor.line)
                    }
                }
            }
            .padding(.horizontal, 18)
        }
        .background(StudioColor.black)
        .navigationTitle("Library")
        .navigationDestination(for: LibraryItem.self) { item in
            ProjectDetailView(model: model, initialItem: item)
        }
        .refreshable { await model.refreshLibrary() }
        .task { await pollWhileProcessing() }
        .toolbar { ToolbarItem(placement: .topBarTrailing) { Button { model.selectedTab = 1 } label: { Image(systemName: "plus") } } }
    }

    private func pollWhileProcessing() async {
        while !Task.isCancelled {
            guard model.library.contains(where: { [.uploading, .queued, .processing].contains($0.state) }) else { return }
            try? await Task.sleep(for: .seconds(4))
            guard !Task.isCancelled else { return }
            await model.refreshLibrary(showLoading: false)
        }
    }
}

private struct ProjectRow: View {
    let item: Audio2MIDICore.LibraryItem
    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 10).fill(StudioColor.raised)
                Image(systemName: item.state == .ready ? "waveform" : item.state == .failed ? "exclamationmark" : "ellipsis")
                    .foregroundStyle(item.state == .failed ? StudioColor.danger : StudioColor.blue)
            }.frame(width: 52, height: 52)
            VStack(alignment: .leading, spacing: 5) {
                Text(item.title).font(.system(size: 16, weight: .semibold)).lineLimit(1)
                Text(statusText).font(.system(size: 13)).foregroundStyle(StudioColor.secondary)
            }
            Spacer()
            Image(systemName: "chevron.right").font(.caption.bold()).foregroundStyle(StudioColor.secondary)
        }
        .padding(.vertical, 14)
        .contentShape(Rectangle())
        .accessibilityIdentifier("project.\(item.id)")
    }

    private var statusText: String {
        switch item.state {
        case .ready: "Ready · \(item.artifacts.count) files"
        case .processing: "Processing"
        case .queued: "Waiting in queue"
        case .failed: "Needs attention"
        case .uploading: "Uploading"
        }
    }
}

struct ProjectDetailView: View {
    @Bindable var model: AppModel
    let initialItem: Audio2MIDICore.LibraryItem
    @State private var downloadedFile: DownloadedFile?
    @State private var downloadingArtifactID: String?

    private var item: Audio2MIDICore.LibraryItem {
        model.library.first(where: { $0.id == initialItem.id }) ?? initialItem
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                ZStack {
                    RoundedRectangle(cornerRadius: 18).fill(StudioColor.surface)
                    Image(systemName: "waveform").font(.system(size: 56, weight: .light)).foregroundStyle(StudioColor.blue)
                }.frame(height: 210)
                VStack(alignment: .leading, spacing: 7) {
                    Text(item.title).font(.system(size: 28, weight: .bold, design: .rounded))
                    Text(methodTitle).foregroundStyle(StudioColor.secondary)
                }
                if item.state == .ready {
                    SectionLabel(text: "Files")
                    ForEach(item.artifacts) { artifact in
                        Button { Task { await download(artifact) } } label: {
                            HStack {
                                if downloadingArtifactID == artifact.id { ProgressView().tint(StudioColor.blue) }
                                else { Image(systemName: "arrow.down.circle.fill") }
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(artifactTitle(artifact.role))
                                    if let size = artifact.sizeBytes {
                                        Text(ByteCountFormatter.string(fromByteCount: Int64(size), countStyle: .file))
                                            .font(.caption).foregroundStyle(StudioColor.secondary)
                                    }
                                }
                                Spacer()
                                Image(systemName: "square.and.arrow.up")
                            }
                        }
                        .disabled(downloadingArtifactID != nil)
                        .buttonStyle(StudioButtonStyle(prominent: false))
                    }
                    if model.editorAvailable, let projectID = item.projectID {
                        NavigationLink("Open piano editor") { EditorView(model: model, projectID: projectID) }
                            .buttonStyle(StudioButtonStyle(prominent: true))
                    }
                } else if item.state == .failed {
                    Label("Processing did not finish. Your request was not charged.", systemImage: "exclamationmark.triangle")
                        .foregroundStyle(StudioColor.danger)
                } else {
                    ProgressView("Processing your track…").tint(StudioColor.blue)
                    Text("This screen updates automatically. You can also close the app and return later.")
                        .font(.footnote).foregroundStyle(StudioColor.secondary)
                }
            }.padding(20)
        }
        .background(StudioColor.black)
        .navigationBarTitleDisplayMode(.inline)
        .task { await pollUntilFinished() }
        .sheet(item: $downloadedFile) { file in ShareSheet(activityItems: [file.url]) }
    }

    private var methodTitle: String {
        switch item.engine {
        case "picogen": "Piano cover"
        case "piano_transcription": "Piano transcription"
        case "sheetsage": "Notes & chords"
        case "music2midi": "Quick MIDI"
        case "audio_separator": "Split into stems"
        default: item.engine.replacingOccurrences(of: "_", with: " ").capitalized
        }
    }

    private func artifactTitle(_ role: String) -> String {
        let labels = [
            "midi": "MIDI", "source_midi": "Source MIDI", "score_midi": "Score MIDI",
            "musicxml": "MusicXML", "pdf": "Score PDF", "mp3": "Audio MP3", "wav": "Audio WAV",
            "full_audio": "Full audio", "preview_mp3": "30-second preview", "vocals": "Vocals",
            "accompaniment": "Instrumental", "video": "Video", "transcript": "Transcript"
        ]
        return labels[role] ?? role.replacingOccurrences(of: "_", with: " ").capitalized
    }

    private func pollUntilFinished() async {
        while !Task.isCancelled, [.uploading, .queued, .processing].contains(item.state) {
            try? await Task.sleep(for: .seconds(4))
            guard !Task.isCancelled else { return }
            await model.refreshLibrary(showLoading: false)
        }
    }

    private func download(_ artifact: Artifact) async {
        downloadingArtifactID = artifact.id
        defer { downloadingArtifactID = nil }
        do { downloadedFile = DownloadedFile(url: try await model.service.download(artifact)) }
        catch { model.errorMessage = error.localizedDescription }
    }
}

private struct DownloadedFile: Identifiable {
    let url: URL
    var id: URL { url }
}

private struct ShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
