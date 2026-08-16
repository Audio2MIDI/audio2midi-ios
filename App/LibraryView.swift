import Audio2MIDICore
import SwiftUI

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
        .navigationDestination(for: LibraryItem.self) { ProjectDetailView(item: $0) }
        .refreshable { await model.refreshLibrary() }
        .toolbar { ToolbarItem(placement: .topBarTrailing) { Button { model.selectedTab = 1 } label: { Image(systemName: "plus") } } }
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
    let item: Audio2MIDICore.LibraryItem
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                ZStack {
                    RoundedRectangle(cornerRadius: 18).fill(StudioColor.surface)
                    Image(systemName: "waveform").font(.system(size: 56, weight: .light)).foregroundStyle(StudioColor.blue)
                }.frame(height: 210)
                VStack(alignment: .leading, spacing: 7) {
                    Text(item.title).font(.system(size: 28, weight: .bold, design: .rounded))
                    Text(item.engine.replacingOccurrences(of: "_", with: " ").capitalized).foregroundStyle(StudioColor.secondary)
                }
                if item.state == .ready {
                    SectionLabel(text: "Files")
                    ForEach(item.artifacts) { artifact in
                        Link(destination: URL(string: artifact.downloadURL, relativeTo: URL(string: "https://app.audio2midi.ru/api"))!) {
                            HStack { Image(systemName: "arrow.down.circle.fill"); Text(artifact.role.replacingOccurrences(of: "_", with: " ").capitalized); Spacer(); Image(systemName: "arrow.up.right") }
                        }
                        .buttonStyle(StudioButtonStyle(prominent: false))
                    }
                    if let projectID = item.projectID {
                        NavigationLink("Open piano editor") { EditorView(projectID: projectID) }
                            .buttonStyle(StudioButtonStyle(prominent: true))
                    }
                } else if item.state == .failed {
                    Label("Processing did not finish. Your request was not charged.", systemImage: "exclamationmark.triangle")
                        .foregroundStyle(StudioColor.danger)
                } else {
                    ProgressView("Processing your track…").tint(StudioColor.blue)
                }
            }.padding(20)
        }.background(StudioColor.black).navigationBarTitleDisplayMode(.inline)
    }
}
