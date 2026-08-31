import SwiftUI
import UniformTypeIdentifiers

struct ModelsView: View {
    @EnvironmentObject private var appState: AppState
    @State private var showImporter = false
    @State private var loadingModel: InstalledModel?
    @State private var importError: String?

    var body: some View {
        NavigationStack {
            ZStack {
                NethTheme.voidBlack.ignoresSafeArea()

                Group {
                    if appState.installedModels.isEmpty {
                        emptyState
                    } else {
                        modelList
                    }
                }
            }
            .navigationTitle("Models")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showImporter = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .foregroundStyle(NethTheme.orange)
                            .font(.system(size: 22))
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

    private var emptyState: some View {
        VStack(spacing: 20) {
            Image(systemName: "cube.transparent")
                .font(.system(size: 56))
                .foregroundStyle(NethTheme.orange)
                .shadow(color: NethTheme.orange.opacity(0.5), radius: 18)
            VStack(spacing: 8) {
                Text("No models installed")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(NethTheme.textPrimary)
                Text("Import a .gguf model file from Files,\nAirDrop, or iCloud Drive.")
                    .font(.subheadline)
                    .foregroundStyle(NethTheme.textSecondary)
                    .multilineTextAlignment(.center)
            }
            Button {
                showImporter = true
            } label: {
                Label("Import Model", systemImage: "square.and.arrow.down")
                    .padding(.horizontal, 22)
                    .padding(.vertical, 12)
                    .background(NethTheme.orange, in: Capsule())
                    .foregroundStyle(.black)
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
            }
            if let err = importError {
                Text(err)
                    .font(.caption)
                    .foregroundStyle(NethTheme.errorGlow)
                    .padding(.horizontal, 24)
                    .multilineTextAlignment(.center)
            }
        }
        .padding()
    }

    private var modelList: some View {
        List {
            Section {
                ForEach(appState.installedModels) { model in
                    ModelRow(model: model,
                             isCurrent: appState.currentModel?.id == model.id,
                             isLoaded: appState.llmEngine.isLoaded && appState.currentModel?.id == model.id,
                             isLoading: loadingModel?.id == model.id) {
                        Task { await load(model) }
                    }
                    .listRowBackground(NethTheme.charcoal.opacity(0.4))
                    .listRowSeparatorTint(NethTheme.hairline)
                    .swipeActions {
                        Button(role: .destructive) {
                            Task { await delete(model) }
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                }
            } header: {
                Text("Installed (\(appState.installedModels.count))")
                    .textCase(.uppercase)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(NethTheme.orange)
            }

            Section {
                Button {
                    showImporter = true
                } label: {
                    Label("Import Another Model", systemImage: "plus.circle")
                        .foregroundStyle(NethTheme.orange)
                }
                .listRowBackground(NethTheme.charcoal.opacity(0.4))
            }

            if let err = importError {
                Section {
                    Label(err, systemImage: "exclamationmark.triangle")
                        .foregroundStyle(NethTheme.errorGlow)
                        .font(.caption)
                }
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
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
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(NethTheme.charcoalRaised)
                        .frame(width: 44, height: 44)
                    Image(systemName: model.supportsVision ? "eye.fill" : "cube.fill")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(NethTheme.orange)
                }
                .overlay(
                    Circle().stroke(isLoaded ? NethTheme.orange.opacity(0.7) : .clear, lineWidth: 1.8)
                )
                .shadow(color: isLoaded ? NethTheme.orange.opacity(0.3) : .clear, radius: 8)

                VStack(alignment: .leading, spacing: 4) {
                    Text(model.displayName)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(NethTheme.textPrimary)
                    HStack(spacing: 6) {
                        if let p = model.parameterCount {
                            tag(p)
                        }
                        if let q = model.quantization {
                            tag(q)
                        }
                        tag(model.formattedSize)
                        if model.supportsVision {
                            Label("Vision", systemImage: "eye.fill")
                                .font(.caption2)
                                .foregroundStyle(NethTheme.amber)
                        }
                    }
                }
                Spacer()
                if isLoading {
                    ProgressView()
                } else if isLoaded {
                    Label("Loaded", systemImage: "checkmark.circle.fill")
                        .font(.caption2.weight(.semibold))
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
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(NethTheme.charcoalRaised, in: Capsule())
    }
}
