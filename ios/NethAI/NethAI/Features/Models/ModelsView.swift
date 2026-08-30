import SwiftUI
import UniformTypeIdentifiers

struct ModelsView: View {
    @Environment(AppState.self) private var appState
    @State private var showImporter = false
    @State private var loadingModel: InstalledModel?
    @State private var importError: String?

    var body: some View {
        NavigationStack {
            List {
                if appState.installedModels.isEmpty {
                    Section {
                        VStack(spacing: 10) {
                            Image(systemName: "cube.transparent")
                                .font(.system(size: 38))
                                .foregroundStyle(NethTheme.orange)
                            Text("No models installed.")
                                .font(.headline)
                            Text("Import a .gguf model file from Files, AirDrop, or iCloud Drive.")
                                .font(.caption)
                                .foregroundStyle(NethTheme.textSecondary)
                                .multilineTextAlignment(.center)
                            Button {
                                showImporter = true
                            } label: {
                                Label("Import Model", systemImage: "square.and.arrow.down")
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                                    .background(NethTheme.orange, in: Capsule())
                                    .foregroundStyle(.black)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 24)
                    }
                } else {
                    Section("Installed Models") {
                        ForEach(appState.installedModels) { model in
                            ModelRow(model: model,
                                     isCurrent: appState.currentModel?.id == model.id,
                                     isLoaded: appState.llmEngine.isLoaded && appState.currentModel?.id == model.id,
                                     isLoading: loadingModel?.id == model.id) {
                                Task { await load(model) }
                            }
                            .swipeActions {
                                Button(role: .destructive) {
                                    Task { await delete(model) }
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                        }
                    }

                    Section {
                        Button {
                            showImporter = true
                        } label: {
                            Label("Import Another Model", systemImage: "plus.circle")
                        }
                    }
                }

                if let err = importError {
                    Section {
                        Label(err, systemImage: "exclamationmark.triangle")
                            .foregroundStyle(NethTheme.errorGlow)
                    }
                }
            }
            .navigationTitle("Models")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showImporter = true
                    } label: {
                        Image(systemName: "plus.circle.fill").foregroundStyle(NethTheme.orange)
                    }
                }
            }
            .fileImporter(
                isPresented: $showImporter,
                allowedContentTypes: [UTType(filenameExtension: "gguf") ?? .data],
                allowsMultipleSelection: false
            ) { result in
                switch result {
                case .success(let urls):
                    if let url = urls.first {
                        Task { await importModel(from: url) }
                    }
                case .failure(let err):
                    importError = String(describing: err)
                }
            }
        }
    }

    private func importModel(from url: URL) async {
        importError = nil
        do {
            _ = try await appState.modelManager.importModel(from: url, replace: false)
            await appState.refreshInstalledModels()
        } catch {
            importError = error.localizedDescription
        }
    }

    private func load(_ model: InstalledModel) async {
        loadingModel = model
        defer { loadingModel = nil }
        do {
            try await appState.llmEngine.loadModel(at: appState.modelManager.path(for: model), gpuLayers: 99)
            appState.currentModel = model
            appState.isModelLoaded = true
        } catch {
            importError = error.localizedDescription
        }
    }

    private func delete(_ model: InstalledModel) async {
        try? appState.modelManager.delete(model)
        await appState.refreshInstalledModels()
        if appState.currentModel?.id == model.id {
            appState.currentModel = appState.installedModels.first
            await appState.llmEngine.unloadModel()
            appState.isModelLoaded = false
        }
    }
}

struct ModelRow: View {
    let model: InstalledModel
    let isCurrent: Bool
    let isLoaded: Bool
    let isLoading: Bool
    var onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(NethTheme.charcoal)
                        .frame(width: 40, height: 40)
                    Image(systemName: model.supportsVision ? "eye.fill" : "cube.fill")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(NethTheme.orange)
                }
                .overlay(
                    Circle().stroke(isLoaded ? NethTheme.orange.opacity(0.6) : .clear, lineWidth: 1.5)
                )

                VStack(alignment: .leading, spacing: 3) {
                    Text(model.displayName)
                        .font(.headline)
                        .foregroundStyle(NethTheme.textPrimary)
                    HStack(spacing: 6) {
                        if let p = model.parameterCount {
                            tag(p)
                        }
                        if let q = model.quantization {
                            tag(q)
                        }
                        tag(model.formattedSize)
                    }
                }
                Spacer()
                if isLoading {
                    ProgressView()
                } else if isLoaded {
                    Label("Loaded", systemImage: "checkmark.circle.fill")
                        .font(.caption2)
                        .foregroundStyle(NethTheme.orange)
                }
            }
            .padding(.vertical, 4)
        }
        .buttonStyle(.plain)
    }

    private func tag(_ s: String) -> some View {
        Text(s)
            .font(.caption2.weight(.medium))
            .foregroundStyle(NethTheme.textSecondary)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(NethTheme.charcoalRaised, in: Capsule())
    }
}
