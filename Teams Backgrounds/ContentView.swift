import SwiftUI

struct ContentView: View {
    @State private var model = PackagerModel()

    var body: some View {
        HStack(spacing: 0) {
            OptionsView(model: model)
                .frame(width: 380)

            Divider()

            ImageListView(model: model)
                .frame(minWidth: 420, maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(minWidth: 820, minHeight: 600)
        .alert(
            "Build Failed",
            isPresented: Binding(
                get: { model.errorMessage != nil },
                set: { if !$0 { model.errorMessage = nil } }
            )
        ) {
            Button("OK") { model.errorMessage = nil }
        } message: {
            Text(model.errorMessage ?? "")
        }
    }
}

// MARK: - Image list

private struct ImageListView: View {
    @Bindable var model: PackagerModel

    private let columns = [GridItem(.adaptive(minimum: 180), spacing: 12)]

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Backgrounds")
                    .font(.headline)
                Text("\(model.items.count)")
                    .foregroundStyle(.secondary)
                Spacer()
                Button("Add Images…", systemImage: "plus") {
                    model.chooseImages()
                }
                Button("Clear", systemImage: "trash") {
                    model.removeAll()
                }
                .disabled(model.items.isEmpty || model.isBuilding)
            }
            .padding()

            Divider()

            Group {
                if model.items.isEmpty {
                    ContentUnavailableView(
                        "Drop Images Here",
                        systemImage: "photo.on.rectangle.angled",
                        description: Text("Drag in images or folders of images. Any format macOS can read is converted to PNG and renamed to the UUID format Teams expects.")
                    )
                } else {
                    ScrollView {
                        LazyVGrid(columns: columns, spacing: 12) {
                            ForEach(model.items) { item in
                                ImageTile(item: item) {
                                    model.remove(item)
                                }
                            }
                        }
                        .padding()
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .dropDestination(for: URL.self) { urls, _ in
                model.add(urls)
                return !urls.isEmpty
            }
        }
    }
}

private struct ImageTile: View {
    let item: BackgroundItem
    let onRemove: () -> Void

    @State private var preview: CGImage?

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            ZStack {
                Rectangle()
                    .fill(.quaternary)
                if let preview {
                    Image(decorative: preview, scale: 1)
                        .resizable()
                        .scaledToFill()
                } else {
                    ProgressView()
                        .controlSize(.small)
                }
            }
            .aspectRatio(16 / 9, contentMode: .fit)
            .clipShape(.rect(cornerRadius: 6))
            .overlay(alignment: .topTrailing) {
                Button("Remove", systemImage: "xmark.circle.fill", action: onRemove)
                    .labelStyle(.iconOnly)
                    .buttonStyle(.plain)
                    .foregroundStyle(.white, .black.opacity(0.6))
                    .padding(4)
            }

            Text(item.sourceURL.lastPathComponent)
                .font(.callout)
                .lineLimit(1)
                .truncationMode(.middle)
            Text(item.fileName)
                .font(.caption.monospaced())
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .truncationMode(.middle)
        }
        .contextMenu {
            Button("Remove", action: onRemove)
        }
        .task(id: item.sourceURL) {
            preview = await loadPreview(item.sourceURL)
        }
    }

    @concurrent
    private func loadPreview(_ url: URL) async -> CGImage? {
        ImageConverter.preview(of: url)
    }
}

// MARK: - Options

private struct OptionsView: View {
    @Bindable var model: PackagerModel

    var body: some View {
        VStack(spacing: 0) {
            BrandHeader()

            Form {
                Section("Output") {
                    TextField("Package name", text: $model.packageName)
                    Picker("Format", selection: $model.outputFormat) {
                        ForEach(OutputFormat.allCases) { format in
                            Text(format.rawValue).tag(format)
                        }
                    }
                    .pickerStyle(.segmented)
                    Text(model.outputFormat.summary)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    LabeledContent("Save to") {
                        HStack {
                            Text(model.destination.lastPathComponent)
                                .lineLimit(1)
                                .truncationMode(.middle)
                            Button("Choose…") { model.chooseDestination() }
                        }
                    }
                }

                Section("Image Conversion") {
                    Picker("Resize", selection: $model.resizeMode) {
                        ForEach(ResizeMode.allCases) { mode in
                            Text(mode.rawValue).tag(mode)
                        }
                    }
                    Picker("Resolution", selection: $model.resolution) {
                        ForEach(OutputResolution.allCases) { resolution in
                            Text(resolution.rawValue).tag(resolution)
                        }
                    }
                    .disabled(model.resizeMode == .original)
                    Text("Saved as <uuid>.png with a \(ImageConverter.thumbnailWidth) × \(ImageConverter.thumbnailHeight) <uuid>_thumb.png.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Section("Teams") {
                    Picker("Install for", selection: $model.teamsTarget) {
                        ForEach(TeamsTarget.allCases) { target in
                            Text(target.rawValue).tag(target)
                        }
                    }
                    Toggle("Restart Teams if running", isOn: $model.restartTeams)
                    Toggle("All local users when run as root", isOn: $model.installForAllUsers)
                }

                if model.outputFormat == .pkg {
                    Section("Installer Package") {
                        TextField("Identifier", text: $model.packageIdentifier)
                        TextField("Version", text: $model.packageVersion)
                        TextField("Signing identity", text: $model.signingIdentity, prompt: Text("Optional: Developer ID Installer: …"))
                    }
                }
            }
            .formStyle(.grouped)
            .disabled(model.isBuilding)

            BuildPanel(model: model)
        }
    }
}

/// Logo, app name and version shown above the options, on a blue-to-indigo
/// gradient that picks up the logo's blue and the Teams indigo.
private struct BrandHeader: View {
    private static let gradient = LinearGradient(
        colors: [
            Color(red: 0.16, green: 0.36, blue: 0.85),
            Color(red: 0.36, green: 0.37, blue: 0.78),
            Color(red: 0.29, green: 0.24, blue: 0.62)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    private var versionText: String {
        let info = Bundle.main.infoDictionary
        let version = info?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = info?["CFBundleVersion"] as? String ?? "1"
        return "Version \(version) (\(build))"
    }

    var body: some View {
        HStack(spacing: 14) {
            Image("Logo")
                .resizable()
                .scaledToFit()
                .frame(width: 60, height: 60)
                .padding(6)
                .background(.white.opacity(0.9), in: .circle)
                .shadow(color: .black.opacity(0.2), radius: 4, y: 2)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 4) {
                Text("Teams Backgrounds")
                    .font(.title2.bold())
                Text(versionText)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.85))
            }
            .foregroundStyle(.white)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .frame(maxWidth: .infinity)
        .background(Self.gradient)
    }
}

private struct BuildPanel: View {
    let model: PackagerModel

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Button {
                    Task { await model.build() }
                } label: {
                    Label("Build \(model.outputFormat.rawValue)", systemImage: "shippingbox")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(!model.canBuild)

                if model.lastOutput != nil {
                    Button("Reveal", systemImage: "folder") {
                        model.revealOutput()
                    }
                    .controlSize(.large)
                }
            }

            if model.isBuilding {
                ProgressView()
                    .progressViewStyle(.linear)
            }

            if !model.logLines.isEmpty {
                ScrollViewReader { proxy in
                    ScrollView {
                        VStack(alignment: .leading, spacing: 2) {
                            ForEach(model.logLines.indices, id: \.self) { index in
                                Text(model.logLines[index])
                                    .id(index)
                            }
                        }
                        .font(.caption.monospaced())
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .frame(height: 120)
                    .onChange(of: model.logLines.count) { _, count in
                        proxy.scrollTo(count - 1, anchor: .bottom)
                    }
                }
            }
        }
        .padding()
        .background(.bar)
    }
}

#Preview {
    ContentView()
}
