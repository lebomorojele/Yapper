import SwiftUI
import AppKit

@MainActor
final class HistoryViewModel: ObservableObject {
    @Published var entries: [HistoryEntry] = []
    @Published var selectedEntryID: UUID?
    @Published var isGenerating = false
    @Published var actionMessage: String?

    private let historyStore: HistoryStoreProtocol
    private let llmProcessor: LLMProcessorProtocol

    init(
        historyStore: HistoryStoreProtocol = HistoryStore.shared,
        llmProcessor: LLMProcessorProtocol = LLMProcessor()
    ) {
        self.historyStore = historyStore
        self.llmProcessor = llmProcessor
        reload()
    }

    var selectedEntry: HistoryEntry? {
        get { entries.first(where: { $0.id == selectedEntryID }) }
        set { selectedEntryID = newValue?.id }
    }

    func reload() {
        entries = (try? historyStore.loadEntries()) ?? []
        if selectedEntryID == nil {
            selectedEntryID = entries.first?.id
        }
    }

    func generateSummary() {
        runEnrichment(instruction: "Summarize this meeting transcript as concise bullet points. Return only the summary text.") { entry, output in
            entry.enrichment.summary = output
        }
    }

    func generateActionItems() {
        runEnrichment(instruction: "Extract action items from this meeting transcript. Return one action item per line, no bullets or numbering.") { entry, output in
            entry.enrichment.actionItems = output
                .split(whereSeparator: \.isNewline)
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
        }
    }

    func copyTranscript() {
        guard let entry = selectedEntry else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(entry.transcript, forType: .string)
        actionMessage = "Copied transcript"
    }

    func exportSelectedTranscript() {
        guard var entry = selectedEntry else { return }

        do {
            entry.exportedFilePath = try TranscriptExporter.exportTranscript(entry, settings: SettingsManager.shared.settings)
            entry.enrichment.lastError = nil
            try historyStore.update(entry: entry)
            reload()
            selectedEntryID = entry.id
            actionMessage = entry.exportedFilePath == nil ? "Transcript export is disabled in settings" : "Exported transcript"
        } catch {
            entry.enrichment.lastError = "Could not export transcript: \(error.localizedDescription)"
            try? historyStore.update(entry: entry)
            reload()
            selectedEntryID = entry.id
            actionMessage = "Export failed"
        }
    }

    func revealExportedFile() {
        guard
            let path = selectedEntry?.exportedFilePath,
            FileManager.default.fileExists(atPath: path)
        else {
            actionMessage = "Exported file is unavailable"
            return
        }

        NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: path)])
    }

    private func runEnrichment(
        instruction: String,
        update: @escaping (inout HistoryEntry, String) -> Void
    ) {
        guard var entry = selectedEntry, !isGenerating else { return }
        isGenerating = true

        Task { [weak self] in
            guard let self else { return }
            do {
                let output = try await llmProcessor.process(text: entry.transcript, instruction: instruction)
                update(&entry, output)
                entry.enrichment.lastError = nil
                try historyStore.update(entry: entry)
                await MainActor.run {
                    self.isGenerating = false
                    self.reload()
                    self.selectedEntryID = entry.id
                }
            } catch {
                entry.enrichment.lastError = error.localizedDescription
                try? historyStore.update(entry: entry)
                await MainActor.run {
                    self.isGenerating = false
                    self.reload()
                    self.selectedEntryID = entry.id
                }
            }
        }
    }
}

struct HistoryView: View {
    @StateObject private var model = HistoryViewModel()

    var body: some View {
        NavigationSplitView {
            List(model.entries, selection: $model.selectedEntryID) { entry in
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Label(entry.kind == .meeting ? "Meeting" : "Dictation", systemImage: entry.kind == .meeting ? "person.2" : "text.cursor")
                            .font(.headline)
                        Spacer()
                        Text(entry.createdAt, format: .dateTime.month(.abbreviated).day().hour().minute())
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    HStack(spacing: 8) {
                        Text("\(Int(entry.duration))s")
                            .font(.caption2.weight(.medium))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(.tertiary.opacity(0.2), in: Capsule())
                        if let outcome = entry.insertionOutcome {
                            Text(outcome == .clipboard ? "Clipboard" : "Inserted")
                                .font(.caption2.weight(.medium))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(.tertiary.opacity(0.2), in: Capsule())
                        }
                    }
                    Text(entry.transcript.isEmpty ? "No transcript text" : entry.transcript)
                        .lineLimit(2)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 4)
                .tag(entry.id)
            }
            .navigationTitle("History")
            .navigationSplitViewColumnWidth(min: 260, ideal: 300)
        } detail: {
            if let entry = model.selectedEntry {
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        HStack {
                            Label(entry.kind == .meeting ? "Meeting" : "Dictation", systemImage: entry.kind == .meeting ? "person.2" : "text.cursor")
                            Spacer()
                            VStack(alignment: .trailing, spacing: 4) {
                                Text("\(Int(entry.duration))s")
                                    .foregroundStyle(.secondary)
                                Text(entry.createdAt, format: .dateTime.month(.wide).day().year().hour().minute())
                                    .font(.caption)
                                    .foregroundStyle(.tertiary)
                            }
                        }
                        .font(.headline)

                        HStack(spacing: 12) {
                            Button("Copy Transcript") {
                                model.copyTranscript()
                            }

                            Button("Export Transcript") {
                                model.exportSelectedTranscript()
                            }

                            if entry.exportedFilePath != nil {
                                Button("Reveal in Finder") {
                                    model.revealExportedFile()
                                }
                            }
                        }

                        GroupBox("Transcript") {
                            Text(entry.transcript)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .textSelection(.enabled)
                        }

                        if entry.kind == .meeting {
                            HStack(spacing: 12) {
                                Button("Generate Summary") {
                                    model.generateSummary()
                                }
                                .disabled(model.isGenerating)

                                Button("Extract Action Items") {
                                    model.generateActionItems()
                                }
                                .disabled(model.isGenerating)
                            }

                            if let summary = entry.enrichment.summary, !summary.isEmpty {
                                GroupBox("Summary") {
                                    Text(summary)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .textSelection(.enabled)
                                }
                            }

                            if !entry.enrichment.actionItems.isEmpty {
                                GroupBox("Action Items") {
                                    VStack(alignment: .leading, spacing: 8) {
                                        ForEach(entry.enrichment.actionItems, id: \.self) { item in
                                            Text("• \(item)")
                                                .frame(maxWidth: .infinity, alignment: .leading)
                                        }
                                    }
                                }
                            }
                        }

                        if let actionMessage = model.actionMessage, !actionMessage.isEmpty {
                            Text(actionMessage)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        if let exportedFilePath = entry.exportedFilePath {
                            LabeledContent("Saved File") {
                                Text(exportedFilePath)
                                    .foregroundStyle(.secondary)
                                    .textSelection(.enabled)
                            }
                        }

                        if let error = entry.enrichment.lastError, !error.isEmpty {
                            Text(error)
                                .foregroundStyle(.red)
                        }
                    }
                    .padding(24)
                }
                .navigationTitle("Entry")
            } else {
                ContentUnavailableView("No History Yet", systemImage: "clock.arrow.circlepath", description: Text("Meeting recordings and dictation entries will appear here."))
            }
        }
        .frame(minWidth: 860, minHeight: 560)
    }
}
