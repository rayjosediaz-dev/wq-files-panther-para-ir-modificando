import SwiftUI
import UIKit
import UniformTypeIdentifiers

private enum PatchPackagePickerPolicy {
    static let packageType = UTType(filenameExtension: "3105") ?? .data
    static let allowedContentTypes: [UTType] = [packageType, .data]
    static let copiesSelectedDocument = true
}

struct PatchProjectsView: View {
    let ghostTheme: Bool
    @Environment(\.appLanguage) private var language
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @EnvironmentObject private var draftCoordinator: PatchDraftCoordinator
    @StateObject private var store = PatchProjectStore()
    @EnvironmentObject private var pantherSession: PantherSession
    @State private var countdownNow = Date()
    private let countdownTimer = Timer.publish(every: 0.05, on: .main, in: .common).autoconnect()
    private var keyCountdown: String {
        if pantherSession.permanent { return "Acceso permanente" }
        guard let expires = pantherSession.expiresAt else { return "Verificando key..." }
        let remaining = max(0, expires.timeIntervalSince(countdownNow))
        let seconds = Int(remaining)
        let days = seconds / 86400
        let hours = (seconds % 86400) / 3600
        let secs = seconds % 60
        let millis = Int((remaining - Double(seconds)) * 1000)
        return String(format: "%dd %02dh %02ds %03dms", days, hours, secs, millis)
    }
    @State private var showCreate = false
    @State private var showImporter = false
    @State private var searchText = ""
    @State private var busyPatchIDs: Set<UUID> = []
    @State private var busyRemoteIDs: Set<String> = []
    @State private var patchActionMessage: String?
    @State private var patchRefreshToken = 0
    @AppStorage("panther.patches.selectedBackground") private var selectedBackground = "Scary Movie"
    @State private var showBackgroundPicker = false
    @State private var pendingBackground = "Scary Movie"
    private let backgroundChoices = ["Scary Movie", "Solo Leveling", "Naruto", "Goku"]
    private var selectedBackgroundAsset: String {
        switch selectedBackground {
        case "Solo Leveling": return "SoloLevelingTheme"
        case "Naruto": return "NarutoTheme"
        case "Goku": return "GokuTheme"
        default: return "GhostPatchesBackground"
        }
    }

    // Paleta única por fondo: todos los controles visibles se actualizan juntos.
    private var themeAccent: Color {
        switch selectedBackground {
        case "Solo Leveling": return Color(red: 0.60, green: 0.30, blue: 1.0)
        case "Naruto": return Color(red: 1.0, green: 0.48, blue: 0.08)
        case "Goku": return Color(red: 0.10, green: 0.64, blue: 1.0)
        default: return Color(red: 1.0, green: 0.16, blue: 0.27)
        }
    }
    private var themeSecondary: Color {
        switch selectedBackground {
        case "Solo Leveling": return Color(red: 0.22, green: 0.56, blue: 1.0)
        case "Naruto": return Color(red: 1.0, green: 0.20, blue: 0.05)
        case "Goku": return Color(red: 0.43, green: 0.30, blue: 1.0)
        default: return Color(red: 0.22, green: 0.64, blue: 1.0)
        }
    }
    private var themePanel: Color { Color.black.opacity(0.84) }

    // Orden fijo de arriba hacia abajo, independiente del estado de activación.
    private func avatarRank(_ name: String) -> Int {
        switch name.lowercased().trimmingCharacters(in: .whitespacesAndNewlines) {
        case "head avatar": return 0
        case "cuello avatar": return 1
        case "pecho avatar": return 2
        case "sintura avatar": return 3
        default: return 4
        }
    }

    private var orderedAvatarItems: [PatchLibraryItem] {
        store.items.filter { item in
            let name = item.project?.name ?? item.packageURL.deletingPathExtension().lastPathComponent
            return avatarRank(name) < 4
        }.sorted { left, right in
            let a = left.project?.name ?? left.packageURL.deletingPathExtension().lastPathComponent
            let b = right.project?.name ?? right.packageURL.deletingPathExtension().lastPathComponent
            if avatarRank(a) != avatarRank(b) { return avatarRank(a) < avatarRank(b) }
            return left.id.uuidString < right.id.uuidString
        }
    }

    private var orderedPublishedPatches: [PantherPatch] {
        pantherSession.publishedPatches.sorted { left, right in
            let a = avatarRank(left.name)
            let b = avatarRank(right.name)
            if a != b { return a < b }
            let nameOrder = left.name.localizedStandardCompare(right.name)
            if nameOrder != .orderedSame { return nameOrder == .orderedAscending }
            return left.id < right.id
        }
    }

    private var filteredItems: [PatchLibraryItem] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return store.items }
        return store.items.filter { item in
            if item.packageURL.lastPathComponent.localizedCaseInsensitiveContains(query) {
                return true
            }
            guard let project = item.project else { return false }
            return project.name.localizedCaseInsensitiveContains(query)
                || project.allBundleIdentifiers.contains {
                    $0.localizedCaseInsensitiveContains(query)
                }
                || project.directories.contains {
                    $0.relativePath.localizedCaseInsensitiveContains(query)
                }
                || project.rules.contains {
                    $0.relativePath.localizedCaseInsensitiveContains(query)
                        || $0.replacementFilename.localizedCaseInsensitiveContains(query)
                }
        }
    }

    init(ghostTheme: Bool = true) {
        self.ghostTheme = true // Pantalla neon para todas las entradas de Patches
#if targetEnvironment(simulator)
        _showCreate = State(
            initialValue: ProcessInfo.processInfo.arguments.contains("--simulate-patch-editor")
        )
#endif
    }

    var body: some View {
        NavigationStack {
            if ghostTheme {
                neonPatchScreen
                .ignoresSafeArea(.container, edges: .all)
            } else {
            VStack(spacing: 0) {
                AppSearchField(
                    text: $searchText,
                    prompt: language.text("patch.search"),
                    clearLabel: language.text("common.clear")
                )
                Divider()
                List {
                    if store.items.isEmpty && !store.isBusy {
                        emptyState
                            .listRowSeparator(.hidden)
                    } else if filteredItems.isEmpty && !store.isBusy {
                        searchEmptyState
                            .listRowSeparator(.hidden)
                    } else {
                        ForEach(filteredItems) { item in
                            itemRow(item)
                        }
                        .onDelete { offsets in
                            offsets.map { filteredItems[$0] }.forEach(store.delete)
                        }
                    }
                }
                .listStyle(.insetGrouped)
                .scrollContentBackground(ghostTheme ? .hidden : .visible)
                .background(ghostTheme ? Color.black.opacity(0.38) : Color.clear)
            }
            .background {
                if ghostTheme {
                    GeometryReader { geometry in
                        Image("GhostPatchesBackground")
                            .resizable()
                            .scaledToFill()
                            .frame(width: geometry.size.width, height: geometry.size.height)
                            .clipped()
                            .overlay(Color.black.opacity(0.28))
                    }
                    .ignoresSafeArea()
                }
            }
            .navigationTitle(language.text("patch.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button {
                            showCreate = true
                        } label: {
                            Label(language.text("patch.new"), systemImage: "doc.badge.plus")
                        }
                        Button {
                            showImporter = true
                        } label: {
                            Label(language.text("patch.import"), systemImage: "square.and.arrow.down")
                        }
                    } label: {
                        if store.isBusy {
                            ProgressView()
                        } else {
                            Image(systemName: "plus")
                        }
                    }
                    .disabled(store.isBusy)
                    .accessibilityLabel(language.text("patch.add"))
                }
            }
            .sheet(isPresented: $showImporter) {
                FileDocumentPicker(
                    allowedContentTypes: PatchPackagePickerPolicy.allowedContentTypes,
                    copiesSelectedDocument: PatchPackagePickerPolicy.copiesSelectedDocument,
                    allowsMultipleSelection: false,
                    onSelection: { result in
                        showImporter = false
                        if case .success(let urls) = result, let url = urls.first {
                            store.importPackage(at: url)
                        }
                    },
                    onCancel: {
                        showImporter = false
                    }
                )
                .ignoresSafeArea()
            }
            .sheet(isPresented: $showCreate) {
                PatchProjectEditorView(
                    existingProject: nil,
                    passwordIsProtected: false
                ) { project, password in
                    store.create(project: project, password: password)
                }
            }
            .sheet(item: $draftCoordinator.request) { request in
                PatchProjectEditorView(
                    existingProject: nil,
                    passwordIsProtected: false,
                    initialDraft: request.draft
                ) { project, password in
                    store.create(project: project, password: password)
                    draftCoordinator.clear()
                }
            }
            .sheet(item: $store.passwordRequest, onDismiss: store.cancelUnlock) { _ in
                PatchUnlockView(store: store)
            }
            .alert(item: $store.alert) { alert in
                Alert(
                    title: Text(language.text(alert.titleKey)),
                    message: Text(alert.message(language: language)),
                    dismissButton: .default(Text(language.text("common.ok")))
                )
            }
            .onAppear {
                consumeExternalImport()
                Task { await pantherSession.refreshCatalog() }
            }
            .onChange(of: draftCoordinator.importRequest?.id) { _ in
                consumeExternalImport()
            }
            } // original project interface
        }
    }


    private var neonPatchScreen: some View {
        GeometryReader { geometry in
            neonPatchLayout(geometry: geometry)
                .frame(width: geometry.size.width, height: geometry.size.height, alignment: .topLeading)
        }
        .ignoresSafeArea(.container, edges: .all)
        .task {
            while !Task.isCancelled {
                await pantherSession.refreshCatalog()
                try? await Task.sleep(nanoseconds: 30_000_000_000)
            }
        }
        .onReceive(countdownTimer) { now in
            countdownNow = now
            pantherSession.checkExpiry()
        }
        .toolbar(.hidden, for: .navigationBar)
        .statusBarHidden(true)
        .background(Color.black.ignoresSafeArea())
        .sheet(isPresented: $showBackgroundPicker) {
            backgroundGallery
                .presentationDetents([.height(460), .large])
                .presentationDragIndicator(.visible)
        }
        .alert("Panther iOS", isPresented: Binding(
            get: { patchActionMessage != nil },
            set: { if !$0 { patchActionMessage = nil } }
        )) {
            Button("Aceptar", role: .cancel) { patchActionMessage = nil }
        } message: {
            Text(patchActionMessage ?? "")
        }
        .onAppear {
            consumeExternalImport()
            store.reload()
        }
        .sheet(item: $store.passwordRequest, onDismiss: store.cancelUnlock) { _ in PatchUnlockView(store: store) }
        .alert(item: $store.alert) { alert in
            Alert(title: Text(language.text(alert.titleKey)), message: Text(alert.message(language: language)), dismissButton: .default(Text(language.text("common.ok"))))
        }
    }

    // Galería de fondos con miniaturas reales: no usa el menú blanco del sistema.
    private func backgroundAsset(for name: String) -> String {
        switch name {
        case "Solo Leveling": return "SoloLevelingTheme"
        case "Naruto": return "NarutoTheme"
        case "Goku": return "GokuTheme"
        default: return "GhostPatchesBackground"
        }
    }

    private var backgroundGallery: some View {
        VStack(spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Cambiar fondo")
                        .font(.system(size: 23, weight: .bold))
                        .foregroundStyle(.white)
                    Text("Elige el estilo del menú Patches")
                        .font(.system(size: 13))
                        .foregroundStyle(.white.opacity(0.65))
                }
                Spacer()
                Button { showBackgroundPicker = false } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 26))
                        .foregroundStyle(.white.opacity(0.7))
                }
            }
            .padding(.top, 24)

            LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                ForEach(backgroundChoices, id: \.self) { choice in
                    Button {
                        pendingBackground = choice
                    } label: {
                        ZStack(alignment: .bottom) {
                            GeometryReader { geo in
                                Image(backgroundAsset(for: choice))
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: geo.size.width, height: geo.size.height)
                                    .clipped()
                            }
                            LinearGradient(colors: [.clear, .black.opacity(0.9)], startPoint: .center, endPoint: .bottom)
                            HStack(spacing: 5) {
                                Text(choice)
                                    .font(.system(size: 14, weight: .bold))
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.8)
                                Spacer(minLength: 0)
                                if pendingBackground == choice {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(themeAccent)
                                }
                            }
                            .foregroundStyle(.white)
                            .padding(10)
                        }
                        .frame(height: 126)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                        .overlay(RoundedRectangle(cornerRadius: 14)
                            .stroke(pendingBackground == choice ? themeAccent : .white.opacity(0.2), lineWidth: pendingBackground == choice ? 3 : 1))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Elegir fondo " + choice)
                }
            }

            Button {
                selectedBackground = pendingBackground
                showBackgroundPicker = false
            } label: {
                Label("Aplicar fondo", systemImage: "checkmark")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 13)
                    .background(themeAccent, in: RoundedRectangle(cornerRadius: 14))
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 20)
        .background(Color(red: 0.035, green: 0.035, blue: 0.08))
    }

    private func neonPatchLayout(geometry: GeometryProxy) -> some View {
        let scale = min(geometry.size.width / 390, geometry.size.height / 844)
        return ZStack(alignment: .top) {
            Color.black
            animatedPatchBackground(width: 390)
            VStack(spacing: 0) {
                HStack(spacing: 12) {
                    Spacer()
                    Button {
                        pendingBackground = selectedBackground
                        showBackgroundPicker = true
                    } label: {
                        Image(systemName: "photo.on.rectangle.angled")
                            .font(.system(size: 23, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(width: 48, height: 48)
                            .background(Color.black.opacity(0.72), in: Circle())
                            .overlay(Circle().stroke(themeAccent, lineWidth: 2))
                    }
                    .accessibilityLabel("Cambiar fondo")
                    Link(destination: URL(string: "https://t.me/+6L89Qcso3w9kN2Yx")!) {
                        Image(systemName: "paperplane.fill")
                            .font(.system(size: 25, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(width: 48, height: 48)
                            .background(Color.black.opacity(0.65), in: Circle())
                            .overlay(Circle().stroke(themeAccent, lineWidth: 2))
                            .shadow(color: themeAccent, radius: 8)
                    }
                    .accessibilityLabel("Abrir grupo de Telegram")
                }
                .padding(.trailing, 20)
                .frame(height: 78)
                Spacer().frame(height: 152)
                HStack(spacing: 7) {
                    Image("PantherAppMark")
                        .resizable()
                        .scaledToFill()
                        .frame(width: 45, height: 45)
                        .clipShape(Circle())
                        .overlay(Circle().stroke(themeAccent, lineWidth: 1.5))
                    Text("Panther iOS")
                        .font(.system(size: 39, weight: .bold, design: .serif))
                        .italic().foregroundStyle(.white)
                        .lineLimit(1).minimumScaleFactor(0.8)
                    Image(systemName: "crown.fill")
                        .font(.system(size: 24)).foregroundStyle(themeAccent)
                }
                .shadow(color: themeAccent, radius: 9)
                .frame(width: 370, height: 74)
                Spacer().frame(height: 14)
                countdownLabel
                    .frame(width: 366, height: 66)
                Spacer().frame(height: 12)
                onlineCatalogHeader
                    .frame(width: 366, height: 74)
                Spacer().frame(height: 12)
                VStack(spacing: 10) {
                    ForEach(orderedPublishedPatches) { patch in
                        remotePatchSlot(patch)
                    }
                    if orderedPublishedPatches.isEmpty {
                        Text(pantherSession.catalogMessage ?? "No hay patches asignados a esta key.")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(.white.opacity(0.8))
                            .multilineTextAlignment(.center)
                            .frame(width: 366)
                            .frame(minHeight: 64)
                    }
                }
                Spacer()
                HStack(spacing: 10) {
                    Button {
                        pantherSession.signOut()
                    } label: {
                        Label("Cerrar sesión", systemImage: "rectangle.portrait.and.arrow.right")
                            .font(.system(size: 15, weight: .bold))
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                            .foregroundStyle(.white)
                            .frame(width: 173, height: 60)
                            .background(themePanel, in: RoundedRectangle(cornerRadius: 18))
                            .overlay(RoundedRectangle(cornerRadius: 18).stroke(themeAccent, lineWidth: 2))
                    }
                    Button(action: openFreeFireMax) {
                        HStack(spacing: 5) {
                            VStack(alignment: .leading, spacing: 0) {
                                Text("FREE FIRE")
                                    .font(.system(size: 17, weight: .black, design: .rounded))
                                Text("MAX")
                                    .font(.system(size: 12, weight: .black, design: .rounded))
                            }
                            .foregroundStyle(.yellow)
                            Image(systemName: "bolt.fill")
                                .font(.system(size: 15, weight: .heavy))
                                .foregroundStyle(.white)
                            VStack(alignment: .leading, spacing: 1) {
                                Text("GOKU BLACK")
                                    .font(.system(size: 12, weight: .black, design: .rounded))
                                Text("EDICIÓN ROSÉ")
                                    .font(.system(size: 9, weight: .bold))
                            }
                            .foregroundStyle(.white)
                        }
                        .frame(width: 173, height: 60)
                        .background(
                            LinearGradient(colors: [Color.black.opacity(0.92), themeAccent.opacity(0.46)], startPoint: .leading, endPoint: .trailing),
                            in: RoundedRectangle(cornerRadius: 18)
                        )
                        .overlay(RoundedRectangle(cornerRadius: 18).stroke(themeAccent, lineWidth: 2))
                    }
                    .accessibilityLabel("Abrir Free Fire MAX")
                }
                .shadow(color: themeAccent.opacity(0.75), radius: 8)
                Spacer().frame(height: 35)
            }
            .frame(width: 390, height: 844)
        }
        .frame(width: 390, height: 844)
        .scaleEffect(x: geometry.size.width / 390, y: geometry.size.height / 844, anchor: .topLeading)
        .frame(width: geometry.size.width, height: geometry.size.height, alignment: .topLeading)
        .clipped()
    }

    private func openFreeFireMax() {
        // This scheme is a candidate only: Garena has not publicly confirmed it.
        // iOS can open the game only when its installed version registers the scheme.
        guard let gameURL = URL(string: "freefiremax://") else {
            patchActionMessage = "No hay un enlace válido para abrir Free Fire MAX."
            return
        }
        UIApplication.shared.open(gameURL, options: [:]) { didOpen in
            guard !didOpen else { return }
            DispatchQueue.main.async {
                patchActionMessage = "No se pudo abrir Free Fire MAX directamente. El juego puede estar instalado, pero esta versión de iOS o del juego no admite el enlace de apertura."
            }
        }
    }

    private func animatedPatchBackground(width: CGFloat) -> some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: reduceMotion)) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate
            Image(selectedBackgroundAsset)
                .resizable()
                .scaledToFill()
                .frame(width: 390, height: 844)
                // Move the Ghostface artwork lower while keeping the entire viewport covered.
                .scaleEffect(reduceMotion ? 1.13 : 1.13 + 0.014 * sin(t * 1.8))
                .offset(x: reduceMotion ? 0 : 6 * sin(t * 1.5),
                        y: reduceMotion ? 0 : 4 * sin(t * 2.0))
                .clipped()
                // Deja los personajes nítidos; oscurece solo la zona de controles.
                .overlay {
                    LinearGradient(colors: [.clear, .black.opacity(0.16), .black.opacity(0.52)],
                                   startPoint: .top, endPoint: .bottom)
                        .allowsHitTesting(false)
                }
                .overlay {
                    if !reduceMotion {
                        LinearGradient(
                            colors: [Color.clear, themeAccent.opacity(0.08 + 0.06 * sin(t * 2.8)), Color.clear],
                            startPoint: .topLeading, endPoint: .bottomTrailing
                        )
                        .allowsHitTesting(false)
                    }
                }
        }
    }

    private var countdownLabel: some View {
        HStack(spacing: 9) {
            Image(systemName: "key.fill")
                .font(.system(size: 22)).foregroundStyle(themeAccent)
            Text("Key activa")
                .font(.system(size: 14, weight: .bold))
            Rectangle().fill(themeAccent.opacity(0.7)).frame(width: 1, height: 42)
            Image(systemName: "calendar")
                .font(.system(size: 21)).foregroundStyle(themeAccent)
            VStack(alignment: .trailing, spacing: 2) {
                Text("Tiempo restante:").font(.system(size: 13, weight: .bold))
                Text(keyCountdown)
                    .font(.system(size: 13, weight: .bold, design: .monospaced))
                    .foregroundStyle(themeAccent)
                    .lineLimit(1).minimumScaleFactor(0.7)
            }
            Spacer(minLength: 0)
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 12)
        .frame(height: 66)
        .background(themePanel, in: RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(themeAccent, lineWidth: 1.5))
    }

    private var onlineCatalogHeader: some View {
        HStack(spacing: 12) {
            Image(systemName: "icloud.and.arrow.down")
                .font(.system(size: 32)).foregroundStyle(themeAccent)
            VStack(alignment: .leading, spacing: 3) {
                Text("CATÁLOGO EN LÍNEA")
                    .font(.system(size: 18, weight: .bold)).foregroundStyle(.white)
                Text("Patches actualizados en tiempo real")
                    .font(.system(size: 11)).foregroundStyle(.white.opacity(0.85))
            }
            Spacer(minLength: 0)
            Button { Task { await pantherSession.refreshCatalog() } } label: {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 25, weight: .bold))
                    .foregroundStyle(themeAccent)
                    .frame(width: 48, height: 48)
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(themeAccent, lineWidth: 2))
            }
        }
        .padding(.horizontal, 14)
        .frame(height: 74)
        .background(themePanel, in: RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(themeAccent, lineWidth: 2))
        .shadow(color: themeAccent.opacity(0.4), radius: 6)
    }

    private func avatarSlot(_ name: String) -> some View {
        let item = orderedAvatarItems.first {
            ($0.project?.name ?? $0.packageURL.deletingPathExtension().lastPathComponent)
                .caseInsensitiveCompare(name) == .orderedSame
        }
        let active = item.map { DevicePatchService.latestReceipt(projectID: $0.id) != nil } ?? false
        let busy = item.map { busyPatchIDs.contains($0.id) } ?? false
        return Button {
            if let item = item { togglePatch(item) }
            else { patchActionMessage = "El patch \\(name) todavía no está disponible." }
        } label: {
            HStack(spacing: 17) {
                Image(systemName: "cube.transparent.fill")
                    .font(.system(size: 29)).foregroundStyle(themeAccent)
                    .frame(width: 43)
                Rectangle().fill(themeAccent.opacity(0.6)).frame(width: 1, height: 38)
                Text(name).font(.system(size: 20, weight: .bold))
                    .foregroundStyle(.white)
                Spacer(minLength: 0)
                if busy {
                    ProgressView().tint(themeAccent).frame(width: 49)
                } else {
                    ZStack(alignment: active ? .trailing : .leading) {
                        Capsule().fill(active ? themeAccent : Color.gray.opacity(0.55))
                            .frame(width: 54, height: 32)
                        Circle().fill(.white).frame(width: 26, height: 26)
                            .padding(.horizontal, 3)
                    }
                    .frame(width: 54, height: 32)
                }
            }
            .padding(.horizontal, 16)
            .frame(width: 366, height: 60)
            .background(themePanel, in: RoundedRectangle(cornerRadius: 15))
            .overlay(RoundedRectangle(cornerRadius: 15).stroke(themeAccent, lineWidth: 2))
            .shadow(color: themeAccent.opacity(0.55), radius: 6)
        }
        .buttonStyle(.plain)
        .disabled(busy)
    }

    // La lista visible procede exclusivamente del servidor. Los paquetes no vienen en la IPA.
    private func remotePatchSlot(_ patch: PantherPatch) -> some View {
        let local = store.items.first {
            ($0.project?.name ?? $0.packageURL.deletingPathExtension().lastPathComponent)
                .caseInsensitiveCompare(patch.name) == .orderedSame
        }
        let active = local.map { DevicePatchService.latestReceipt(projectID: $0.id) != nil } ?? false
        let busy = busyRemoteIDs.contains(patch.id)
        return Button {
            guard !busy else { return }
            if let local, active {
                togglePatch(local)
            } else {
                Task { await downloadAndActivate(patch) }
            }
        } label: {
            HStack(spacing: 17) {
                Image(systemName: "cube.transparent.fill")
                    .font(.system(size: 29))
                    .foregroundStyle(themeAccent)
                    .frame(width: 43)
                Rectangle().fill(themeAccent.opacity(0.6)).frame(width: 1, height: 38)
                Text(patch.name).font(.system(size: 20, weight: .bold))
                    .foregroundStyle(.white).lineLimit(1).minimumScaleFactor(0.75)
                Spacer(minLength: 0)
                if busy { ProgressView().tint(themeAccent) }
                else {
                    Text(active ? "Apagar" : "Encender")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(.white)
                }
            }
            .padding(.horizontal, 16)
            .frame(width: 366, height: 60)
            .background(themePanel, in: RoundedRectangle(cornerRadius: 15))
            .overlay(RoundedRectangle(cornerRadius: 15).stroke(themeAccent, lineWidth: 2))
        }
        .buttonStyle(.plain)
        .disabled(busy)
    }

    @MainActor
    private func downloadAndActivate(_ patch: PantherPatch) async {
        guard !busyRemoteIDs.contains(patch.id) else { return }
        busyRemoteIDs.insert(patch.id)
        defer { busyRemoteIDs.remove(patch.id) }
        do {
            let url = try await pantherSession.downloadPatch(patch)
            defer { try? FileManager.default.removeItem(at: url) }
            let data = try PatchProjectLibrary.readPackage(at: url)
            let summary = try PatchPackageCodec.inspect(data)
            guard !summary.isPasswordProtected else {
                patchActionMessage = "El patch requiere contraseña para importarse."
                return
            }
            let decoded = try PatchPackageCodec.decode(data, password: nil)
            let previous = store.items.first { $0.id == summary.packageID }?.packageURL
            try PatchProjectLibrary.installImportedPackage(data: data, decoded: decoded,
                                                           summary: summary, existingURL: previous)
            store.reload()
            guard let item = store.items.first(where: { $0.id == summary.packageID }),
                  let project = item.project else {
                patchActionMessage = "No se pudo preparar el patch descargado."
                return
            }
            let prepared = item.summary.schemaVersion >= 2
                ? try PatchProjectLibrary.synchronizeWorkspace(item: item) : project
            _ = try DevicePatchService.apply(project: prepared)
            PantherFeedbackAudio.play("opcion_activada")
            store.reload()
            patchRefreshToken += 1
        } catch {
            patchActionMessage = "No se pudo activar el patch: \(error.localizedDescription)"
        }
    }

    private func togglePatch(_ item: PatchLibraryItem) {
        guard !busyPatchIDs.contains(item.id) else { return }
        let currentReceipt = DevicePatchService.latestReceipt(projectID: item.id)
        guard currentReceipt != nil || item.project != nil else {
            patchActionMessage = "El paquete no contiene un proyecto válido para aplicar."
            return
        }
        busyPatchIDs.insert(item.id)
        Task.detached(priority: .userInitiated) {
            do {
                if let receipt = currentReceipt {
                    try DevicePatchService.restore(receipt: receipt)
                } else if let project = item.project {
                    let prepared = item.summary.schemaVersion >= 2
                        ? try PatchProjectLibrary.synchronizeWorkspace(item: item)
                        : project
                    _ = try DevicePatchService.apply(project: prepared)
                }
                await MainActor.run {
                    PantherFeedbackAudio.play(currentReceipt != nil ? "opcion_desactivada" : "opcion_activada")
                    store.reload()
                    busyPatchIDs.remove(item.id)
                    patchRefreshToken += 1
                }
            } catch {
                await MainActor.run {
                    busyPatchIDs.remove(item.id)
                    patchActionMessage = "No se pudo completar la operación: \(error.localizedDescription)"
                }
            }
        }
    }

    private func consumeExternalImport() {
        guard let request = draftCoordinator.importRequest else { return }
        draftCoordinator.clearImport()
        store.importPackage(from: request.source)
    }

    @ViewBuilder
    private func itemRow(_ item: PatchLibraryItem) -> some View {
        if item.isLocked {
            Button { store.requestUnlock(for: item) } label: {
                PatchProjectRow(item: item, language: language)
            }
            .buttonStyle(.plain)
        } else {
            NavigationLink {
                PatchProjectDetailView(store: store, projectID: item.id)
            } label: {
                PatchProjectRow(item: item, language: language)
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "shippingbox")
                .font(.system(size: AppTheme.emptyIconSize, weight: .light))
                .foregroundStyle(AppTheme.accent)
            Text(language.text("patch.empty_title"))
                .font(.headline)
            Text(language.text("patch.empty_message"))
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button(language.text("patch.new")) { showCreate = true }
                .buttonStyle(.bordered)
                .controlSize(.large)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 64)
    }

    private var searchEmptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: AppTheme.emptyIconSize, weight: .light))
                .foregroundStyle(.secondary)
            Text(language.text("patch.search_empty"))
                .font(.headline)
            Text(language.text("patch.search_empty_message"))
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 64)
    }
}

private struct PatchProjectRow: View {
    let item: PatchLibraryItem
    let language: AppLanguage

    var body: some View {
        HStack(spacing: 12) {
            AppRowIcon(systemName: item.isLocked ? "lock.doc.fill" : "shippingbox.fill")
            VStack(alignment: .leading, spacing: 3) {
                Text(item.project?.name ?? language.text("patch.locked_project"))
                    .font(.body.weight(.semibold))
                    .foregroundStyle(.primary)
                Text(item.isLocked
                     ? language.text("patch.tap_to_unlock")
                     : language.text(
                        item.summary.schemaVersion >= 2 ? "patch.workspace_items_count" : "patch.rules_count",
                        Int64((item.project?.rules.count ?? 0) + (item.project?.directories.count ?? 0))
                     ))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if item.summary.isPasswordProtected {
                Image(systemName: "key.fill")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .accessibilityLabel(language.text("patch.password_protected"))
            }
        }
        .padding(.vertical, 4)
    }
}

private struct PatchUnlockView: View {
    @Environment(\.appLanguage) private var language
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var store: PatchProjectStore
    @State private var password = ""

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    SecureField(language.text("patch.password"), text: $password)
                        .textContentType(.password)
                        .submitLabel(.done)
                        .onSubmit(unlock)
                        .onChange(of: password) { _ in
                            store.clearUnlockError()
                        }
                    if let errorKey = store.unlockErrorKey {
                        Text(language.text(errorKey))
                            .font(.footnote)
                            .foregroundStyle(.red)
                    }
                } footer: {
                    Text(language.text("patch.password_once_message"))
                }
            }
            .navigationTitle(language.text("patch.unlock"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(language.text("common.cancel")) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(language.text("patch.unlock"), action: unlock)
                        .disabled(password.isEmpty || store.isBusy)
                }
            }
        }
    }

    private func unlock() {
        guard !password.isEmpty else { return }
        store.unlock(password: password)
    }
}

private struct PatchProjectDetailView: View {
    @Environment(\.appLanguage) private var language
    @ObservedObject var store: PatchProjectStore
    let projectID: UUID
    @State private var showEditor = false
    @State private var editingRule: PatchRule?
    @State private var showApplyConfirmation = false
    @State private var showRestoreConfirmation = false
    @State private var isWorking = false
    @State private var actionAlert: PatchStoreAlert?
    @State private var shareRequest: PatchShareRequest?

    private var item: PatchLibraryItem? {
        store.items.first(where: { $0.id == projectID })
    }

    private var receipt: PatchTransactionReceipt? {
        DevicePatchService.latestReceipt(projectID: projectID)
    }

    private var isWorkspaceProject: Bool {
        (item?.summary.schemaVersion ?? 1) >= 2
    }

    var body: some View {
        List {
            if let item, let project = item.project {
                if isWorkspaceProject {
                    Section {
                        ForEach(project.allBundleIdentifiers, id: \.self) { bundleID in
                            Label {
                                Text(bundleID)
                                    .font(.subheadline.monospaced())
                            } icon: {
                                Image(systemName: "app.dashed")
                                    .foregroundStyle(AppTheme.accent)
                            }
                        }
                        LabeledContent(language.text("patch.files")) {
                            Text("\(project.rules.count)")
                        }
                        LabeledContent(language.text("patch.folders")) {
                            Text("\(project.directories.count)")
                        }
                        if let workspaceURL = item.workspaceURL {
                            NavigationLink {
                                FileBrowserView(
                                    containerPath: workspaceURL.path,
                                    title: project.name,
                                    bundleID: nil
                                )
                            } label: {
                                Label(
                                    language.text("patch.open_workspace"),
                                    systemImage: "folder"
                                )
                            }
                        }
                    } header: {
                        Text(language.text("patch.workspace"))
                    } footer: {
                        Text(language.text("patch.workspace_detail_footer"))
                    }
                } else {
                    Section {
                        ForEach(project.rules) { rule in
                            Button {
                                editingRule = rule
                            } label: {
                                HStack(spacing: 10) {
                                    ruleSummary(rule)
                                    Spacer(minLength: 8)
                                    Image(systemName: "chevron.right")
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(.tertiary)
                                }
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .accessibilityHint(language.text("patch.edit_rule_hint"))
                        }
                    } header: {
                        Text(language.text("patch.rules"))
                    } footer: {
                        Text(language.text("patch.legacy_footer"))
                    }
                }

                Section(language.text("patch.password")) {
                    HStack(spacing: 12) {
                        Image(systemName: item.summary.isPasswordProtected ? "lock.fill" : "lock.open")
                            .foregroundStyle(AppTheme.accent)
                            .frame(width: 24)
                        Text(language.text(item.summary.isPasswordProtected
                            ? "patch.password_locked"
                            : "patch.no_password"))
                            .font(.subheadline)
                    }
                }

                Section {
                    Button {
                        showApplyConfirmation = true
                    } label: {
                        actionLabel("patch.apply", systemImage: "checkmark.shield.fill")
                    }
                    .disabled(isWorking)

                    if receipt != nil {
                        Button(role: .destructive) {
                            showRestoreConfirmation = true
                        } label: {
                            actionLabel("patch.restore", systemImage: "arrow.uturn.backward.circle")
                        }
                        .disabled(isWorking)
                    }

                    Button(action: prepareExport) {
                        actionLabel("patch.export", systemImage: "square.and.arrow.up")
                    }
                    .disabled(isWorking)
                } footer: {
                    Text(language.text("patch.apply_footer"))
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle(item?.project?.name ?? language.text("patch.title"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                if isWorking {
                    ProgressView()
                } else if !isWorkspaceProject {
                    Button(language.text("patch.edit")) { showEditor = true }
                        .disabled(item?.project == nil)
                }
            }
        }
        .sheet(isPresented: $showEditor) {
            if let item, let project = item.project {
                PatchProjectEditorView(
                    existingProject: project,
                    passwordIsProtected: item.summary.isPasswordProtected
                ) { updatedProject, _ in
                    store.update(project: updatedProject)
                }
            }
        }
        .sheet(item: $editingRule) { rule in
            PatchRuleEditorView(rule: rule) { updatedRule in
                updateRule(updatedRule)
            }
        }
        .confirmationDialog(
            language.text("patch.apply_confirm_title"),
            isPresented: $showApplyConfirmation,
            titleVisibility: .visible
        ) {
            Button(language.text("patch.apply")) { apply() }
            Button(language.text("common.cancel"), role: .cancel) {}
        } message: {
            Text(language.text("patch.apply_confirm_message"))
        }
        .confirmationDialog(
            language.text("patch.restore_confirm_title"),
            isPresented: $showRestoreConfirmation,
            titleVisibility: .visible
        ) {
            Button(language.text("patch.restore"), role: .destructive) { restore() }
            Button(language.text("common.cancel"), role: .cancel) {}
        }
        .alert(item: $actionAlert) { alert in
            Alert(
                title: Text(language.text(alert.titleKey)),
                message: Text(alert.message(language: language)),
                dismissButton: .default(Text(language.text("common.ok")))
            )
        }
        .sheet(item: $shareRequest) { request in
            PatchActivityView(items: [request.url])
                .ignoresSafeArea()
        }
    }

    private func actionLabel(_ key: String, systemImage: String) -> some View {
        Label(language.text(key), systemImage: systemImage)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func ruleSummary(_ rule: PatchRule) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(rule.bundleID)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.primary)
            Text(rule.relativePath)
                .font(.caption.monospaced())
                .foregroundStyle(.secondary)
                .lineLimit(2)
            Label(rule.replacementFilename, systemImage: "arrow.triangle.2.circlepath")
                .font(.caption)
                .foregroundStyle(AppTheme.accent)
        }
        .padding(.vertical, 3)
    }

    private func updateRule(_ updatedRule: PatchRule) {
        guard var project = item?.project,
              let index = project.rules.firstIndex(where: { $0.id == updatedRule.id }) else {
            return
        }
        project.rules[index] = updatedRule
        project.updatedAt = Date()
        do {
            try PatchPackageCodec.validate(project)
            store.update(project: project)
        } catch let error as PatchPackageError {
            actionAlert = PatchStoreAlert(
                titleKey: "common.failed",
                messageKey: error.localizationKey,
                messageArgument: error.localizationArgument
            )
        } catch {
            actionAlert = PatchStoreAlert(
                titleKey: "common.failed",
                messageKey: "patch.error.invalid_project"
            )
        }
    }

    private func apply() {
        guard let item, let baseProject = item.project else { return }
        isWorking = true
        Task.detached(priority: .userInitiated) {
            do {
                let project = item.summary.schemaVersion >= 2
                    ? try PatchProjectLibrary.synchronizeWorkspace(item: item)
                    : baseProject
                _ = try DevicePatchService.apply(project: project)
                await MainActor.run {
                    store.reload()
                    isWorking = false
                    actionAlert = PatchStoreAlert(titleKey: "common.done", messageKey: "patch.applied_message")
                }
            } catch let error as PatchPackageError {
                await MainActor.run {
                    isWorking = false
                    actionAlert = PatchStoreAlert(
                        titleKey: "common.failed",
                        messageKey: error.localizationKey,
                        messageArgument: error.localizationArgument
                    )
                }
            } catch {
                await MainActor.run {
                    isWorking = false
                    actionAlert = PatchStoreAlert(titleKey: "common.failed", messageKey: "patch.error.apply")
                }
            }
        }
    }

    private func prepareExport() {
        guard let item else { return }
        isWorking = true
        Task.detached(priority: .userInitiated) {
            do {
                if item.summary.schemaVersion >= 2 {
                    _ = try PatchProjectLibrary.synchronizeWorkspace(item: item)
                }
                await MainActor.run {
                    store.reload()
                    isWorking = false
                    shareRequest = PatchShareRequest(url: item.packageURL)
                }
            } catch let error as PatchPackageError {
                await MainActor.run {
                    isWorking = false
                    actionAlert = PatchStoreAlert(
                        titleKey: "common.failed",
                        messageKey: error.localizationKey,
                        messageArgument: error.localizationArgument
                    )
                }
            } catch {
                await MainActor.run {
                    isWorking = false
                    actionAlert = PatchStoreAlert(
                        titleKey: "common.failed",
                        messageKey: "patch.error.invalid_project"
                    )
                }
            }
        }
    }

    private func restore() {
        guard let receipt else { return }
        isWorking = true
        Task.detached(priority: .userInitiated) {
            do {
                try DevicePatchService.restore(receipt: receipt)
                await MainActor.run {
                    isWorking = false
                    actionAlert = PatchStoreAlert(titleKey: "common.done", messageKey: "patch.restored_message")
                }
            } catch let error as PatchPackageError {
                await MainActor.run {
                    isWorking = false
                    actionAlert = PatchStoreAlert(
                        titleKey: "common.failed",
                        messageKey: error.localizationKey,
                        messageArgument: error.localizationArgument
                    )
                }
            } catch {
                await MainActor.run {
                    isWorking = false
                    actionAlert = PatchStoreAlert(titleKey: "common.failed", messageKey: "patch.error.restore")
                }
            }
        }
    }
}

private struct PatchShareRequest: Identifiable {
    let id = UUID()
    let url: URL
}

private struct PatchActivityView: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(
        _ uiViewController: UIActivityViewController,
        context: Context
    ) {}
}
