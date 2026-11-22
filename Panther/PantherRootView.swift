import SwiftUI
import UniformTypeIdentifiers

/// Safe Panther interface. Embed PantherRootView in the WQ Files app's root controller.
/// Access to external files requires explicit user selection through the iOS Files picker.
struct PantherRootView: View {
    @State private var key = ""
    @State private var deviceID = UIDevice.current.identifierForVendor?.uuidString ?? UUID().uuidString
    @State private var authenticated = false
    @State private var patches: [PantherPatch] = []
    @State private var status = ""
    @State private var busy = false
    @State private var showImporter = false
    @State private var importedURL: URL?
    @State private var selectedTab = 0

    var body: some View {
        Group {
            if !authenticated {
                NavigationStack {
                    Form {
                        Section("Panther iOS") {
                            SecureField("Ingresa tu key", text: $key)
                            Button("Entrar") { Task { await login() } }
                                .disabled(key.isEmpty || busy)
                        }
                        Text(status).foregroundStyle(.secondary)
                    }
                    .navigationTitle("Panther iOS")
                }
            } else {
                TabView(selection: $selectedTab) {
                    NavigationStack {
                        Form {
                            Section("Archivos autorizados") {
                                Button("Seleccionar archivo en Files") { showImporter = true }
                                if let importedURL {
                                    Text(importedURL.lastPathComponent)
                                }
                            }
                            Text("El explorador original de WQ Files debe conectarse aquí desde su controlador existente.")
                                .font(.footnote).foregroundStyle(.secondary)
                        }
                        .navigationTitle("Files")
                    }
                    .tabItem { Label("Files", systemImage: "folder") }.tag(0)
                    NavigationStack {
                        List {
                            ForEach(["Head", "Cuello", "Pecho", "Sintura"], id: \.self) { category in
                                Section(category) {
                                    ForEach(patches.filter { ($0.category ?? "").localizedCaseInsensitiveCompare(category) == .orderedSame }) { patch in
                                        HStack {
                                            Text(patch.name)
                                            Spacer()
                                            Button("Descargar") { Task { await download(patch.id) } }
                                                .disabled(busy)
                                        }
                                    }
                                }
                            }
                            Text(status).font(.footnote).foregroundStyle(.secondary)
                        }
                        .navigationTitle("Patches")
                        .toolbar {
                            ToolbarItem(placement: .topBarLeading) {
                                Button("Salir") { PantherAPI.shared.logout(); authenticated = false; patches = [] }
                            }
                            ToolbarItem(placement: .topBarTrailing) {
                                Button("Actualizar") { Task { await refresh() } }
                            }
                        }
                        .task(id: authenticated) {
                            while !Task.isCancelled && authenticated {
                                await refresh()
                                try? await Task.sleep(for: .seconds(30))
                            }
                        }
                    }
                    .tabItem { Label("Patches", systemImage: "square.stack") }.tag(1)
                }
            }
        }
        .fileImporter(isPresented: $showImporter, allowedContentTypes: [.data], allowsMultipleSelection: false) { result in
            if case .success(let urls) = result { importedURL = urls.first }
        }
    }

    @MainActor private func login() async {
        busy = true; defer { busy = false }
        do {
            try await PantherAPI.shared.activate(key: key, deviceID: deviceID)
            authenticated = true
            status = "Sesión iniciada"
            await refresh()
        } catch { status = "No se pudo validar la key: \(error.localizedDescription)" }
    }

    @MainActor private func refresh() async {
        guard authenticated else { return }
        do { patches = try await PantherAPI.shared.catalog(); status = "Catálogo actualizado" }
        catch { status = "Error al consultar patches: \(error.localizedDescription)" }
    }

    @MainActor private func download(_ id: String) async {
        busy = true; defer { busy = false }
        do {
            let url = try await PantherAPI.shared.download(patchID: id)
            status = "Guardado en Documents: \(url.lastPathComponent)"
        } catch { status = "Error de descarga: \(error.localizedDescription)" }
    }
}
