import SwiftUI
import UIKit
import AVFoundation
import Security
import UserNotifications
import CryptoKit

@MainActor
enum PantherFeedbackAudio {
    static var player: AVAudioPlayer?
    static func play(_ name: String) {
        guard let url = Bundle.main.url(forResource: name, withExtension: "m4a") else {
            print("Audio no encontrado en el bundle: \(name).m4a")
            return
        }
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: [.mixWithOthers])
            try AVAudioSession.sharedInstance().setActive(true)
            player = try AVAudioPlayer(contentsOf: url)
            player?.prepareToPlay()
            player?.play()
        } catch {
            print("No se pudo reproducir el audio: \(error.localizedDescription)")
        }
    }
}


// Presenta las notificaciones también cuando la aplicación está abierta.
final class PantherNotificationDelegate: NSObject, UNUserNotificationCenterDelegate {
    func userNotificationCenter(_ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .list, .sound])
    }
}

@main
struct ThreeOneOSFiveApp: App {
    private let notificationDelegate = PantherNotificationDelegate()
    @StateObject private var appState = AppState()
    @StateObject private var pantherSession = PantherSession()
    @StateObject private var patchDraftCoordinator = PatchDraftCoordinator()
    @StateObject private var fileOperationCoordinator = FileOperationCoordinator()
    @AppStorage(AppLanguage.storageKey) private var languageCode = AppLanguage.english.rawValue
    @State private var showOnboarding = false
    @State private var calculatorUnlocked = false
    @State private var showPantherNotificationIntro = false
    @AppStorage("PantherNotificationIntroSeen") private var notificationIntroSeen = false
    @State private var showAttribution = false
    @State private var updateOffer: AppUpdateChecker.Offer?
    @Environment(\.scenePhase) private var scenePhase

    init() {
        UNUserNotificationCenter.current().delegate = notificationDelegate
        setupLogCapture()
        log("app: 3105 launching — iOS \(AppInfo.osVersion) (\(AppInfo.osBuild)) \(AppInfo.machineName)")
    }

    private var language: AppLanguage {
        AppLanguage(rawValue: languageCode) ?? .english
    }

    private func checkForUpdate() {
        Task {
            guard let offer = await AppUpdateChecker.check() else { return }
            await MainActor.run { updateOffer = offer }
        }
    }

    var body: some Scene {
        WindowGroup {
            ZStack {
                Group {
                    if !calculatorUnlocked {
                        PantherCalculatorView {
                            PantherFeedbackAudio.play("welcome_baby")
                            if notificationIntroSeen {
                                calculatorUnlocked = true
                            } else {
                                showPantherNotificationIntro = true
                            }
                        }
                    } else if pantherSession.role == nil {
                        PantherLoginView(session: pantherSession)
                    } else if pantherSession.role == "patches" {
                        PantherAssignedPatchesView(session: pantherSession)
                    } else {
                        ContentView()
                    }
                }
                    .environmentObject(appState)
                    .environmentObject(pantherSession)
                    .environmentObject(patchDraftCoordinator)
                    .environmentObject(fileOperationCoordinator)
                    .environment(\.appLanguage, language)
                    .environment(\.locale, language.locale)
                    .opacity(showOnboarding && pantherSession.role != nil ? 0 : 1)
                    .allowsHitTesting(!showOnboarding || pantherSession.role == nil)

                if false && showOnboarding && pantherSession.role != nil {
                    OnboardingView {
                        OnboardingStore.markCompleted()
                        withAnimation(.spring(response: 0.42, dampingFraction: 0.86)) {
                            showOnboarding = false
                        }
                        appState.detectSupport()
                        // Automatic update prompt disabled.
                    }
                    .environment(\.appLanguage, language)
                    .environment(\.locale, language.locale)
                    .transition(.opacity.combined(with: .scale(scale: 0.98)))
                    .zIndex(1)
                }
            }
            .sheet(isPresented: $showPantherNotificationIntro) {
                PantherNotificationIntro(onContinue: {
                    notificationIntroSeen = true
                    showPantherNotificationIntro = false
                    calculatorUnlocked = true
                }, onLater: {
                    // Permite continuar sin forzar el permiso de notificaciones.
                    notificationIntroSeen = true
                    showPantherNotificationIntro = false
                    calculatorUnlocked = true
                })
            }
            .displayIdentityAttribution(isPresented: $showAttribution, enabled: !showOnboarding && pantherSession.role == "admin")
            .sheet(isPresented: $showAttribution) {
                DisplayAttributionSheet()
            }
            .alert(item: $updateOffer) { offer in
                Alert(
                    title: Text(language.text("update.title")),
                    message: Text(language.text("update.message", offer.version)),
                    primaryButton: .default(Text(language.text("update.agree"))) {
                        // No external GitHub navigation from the patch menu.
                    },
                    secondaryButton: .cancel(Text(language.text("update.dismiss"))) {
                        AppUpdateChecker.dismiss(version: offer.version)
                    }
                )
            }
            .task {
                await pantherSession.restoreSavedKey()
            }
            .onAppear {
                if !showOnboarding && pantherSession.role != nil {
                    appState.detectSupport()
                    // Automatic update prompt disabled.
                }
            }
            .onChange(of: scenePhase) { phase in
                guard phase == .active, !showOnboarding, pantherSession.role != nil else { return }
                appState.detectSupport()
            }
            .task(id: pantherSession.role) {
                // Re-check the active key with Lovable every 30 seconds while logged in.
                // SwiftUI cancels this task automatically when the role changes.
                guard pantherSession.role != nil else { return }
                // Los patches solo se reciben del catálogo del servidor.
                await pantherSession.revalidate()
                while !Task.isCancelled && pantherSession.role != nil {
                    do {
                        try await Task.sleep(nanoseconds: 30_000_000_000)
                    } catch { break }
                    guard !Task.isCancelled, pantherSession.role != nil else { break }
                    await pantherSession.revalidate()
                }
            }
            .onChange(of: scenePhase) { phase in
                if phase == .active { Task { await pantherSession.revalidate() } }
            }
            .onChange(of: pantherSession.role) { newRole in
                if newRole == nil && calculatorUnlocked { calculatorUnlocked = false }
            }
            .onOpenURL { url in
                if pantherSession.role == "admin" { patchDraftCoordinator.presentImport(url) }
            }
        }
    }
}


// Calculadora independiente con controles al estilo iOS.
private struct PantherCalculatorView: View {
    let onUnlock: () -> Void
    @State private var display = "0"
    @State private var entry = ""
    @State private var lhs: Double?
    @State private var operation: String?
    @State private var freshEntry = true
    @State private var lastOperation: String?
    @State private var lastOperand: Double?
    @State private var history: [CalculationRecord] = []
    @State private var showHistory = false
    @State private var showModes = false
    @State private var showEditor = false
    @State private var mode = "Básica"

    private struct CalculationRecord: Identifiable {
        let id = UUID()
        let date = Date()
        let expression: String
        let result: String
    }
    private let rows = [
        ["⌫", "AC", "%", "÷"],
        ["7", "8", "9", "×"],
        ["4", "5", "6", "−"],
        ["1", "2", "3", "+"],
        ["+/−", "0", ".", "="]
    ]

    var body: some View {
        GeometryReader { geo in
            let gap: CGFloat = 10
            let diameter = min((geo.size.width - 32 - 3 * gap) / 4,
                               max(48, (geo.size.height - 230) / 5.5))
            ZStack(alignment: .top) {
                Color.black.ignoresSafeArea()
                VStack(spacing: 0) {
                    HStack {
                        Button { showHistory = true } label: {
                            Image(systemName: "list.bullet")
                                .font(.system(size: 22))
                                .frame(width: 48, height: 48)
                                .background(Color(white: 0.13), in: Circle())
                        }
                        Spacer()
                        Button("Acceder con key") { onUnlock() }
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(.white.opacity(0.75))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 8)
                            .background(Color(white: 0.13), in: Capsule())
                        Button { showModes.toggle() } label: {
                            Image(systemName: "calculator")
                                .font(.system(size: 22))
                                .frame(width: 48, height: 48)
                                .background(Color(white: 0.13), in: Circle())
                        }
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 20)
                    .padding(.top, 14)
                    Spacer(minLength: 12)
                    Text(visibleExpression)
                        .font(.system(size: min(74, geo.size.width * 0.18), weight: .light))
                        .lineLimit(1)
                        .minimumScaleFactor(0.35)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                        .padding(.horizontal, 26)
                        .padding(.bottom, 22)
                        .foregroundStyle(.white)
                        .contextMenu {
                            Button("Pegar", systemImage: "doc.on.clipboard") {
                                if let pasted = UIPasteboard.general.string,
                                   !pasted.isEmpty {
                                    display = pasted
                                    entry = pasted
                                    freshEntry = false
                                }
                            }
                            Button("Copiar", systemImage: "doc.on.doc") {
                                UIPasteboard.general.string = display
                            }
                        }
                    VStack(spacing: gap) {
                        ForEach(rows.indices, id: \.self) { row in
                            HStack(spacing: gap) {
                                ForEach(rows[row], id: \.self) { key in
                                    Button { tap(key) } label: {
                                        Text(key)
                                            .font(.system(size: diameter * 0.37, weight: .regular))
                                            .foregroundStyle(.white)
                                            .frame(width: diameter, height: diameter)
                                            .background(buttonColor(key), in: Circle())
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.bottom, 20)
                }
                if showModes {
                    VStack(alignment: .leading, spacing: 0) {
                        ForEach(["Básica", "Científica", "Notas matemáticas", "Convertir"], id: \.self) { item in
                            Button {
                                mode = item
                                showModes = false
                            } label: {
                                HStack(spacing: 16) {
                                    Image(systemName: mode == item ? "checkmark" : " ")
                                        .frame(width: 18)
                                    Image(systemName: modeIcon(item))
                                        .frame(width: 24)
                                    Text(item)
                                    Spacer()
                                }
                                .font(.system(size: 18))
                                .foregroundStyle(.white)
                                .frame(height: 54)
                            }
                            if item == "Notas matemáticas" {
                                Divider().overlay(Color.white.opacity(0.12)).padding(.vertical, 5)
                            }
                        }
                    }
                    .padding(.horizontal, 18)
                    .padding(.vertical, 10)
                    .background(Color(white: 0.09), in: RoundedRectangle(cornerRadius: 28))
                    .padding(.leading, 100)
                    .padding(.trailing, 18)
                    .padding(.top, 14)
                }
            }
        }
        .preferredColorScheme(.dark)
        .sheet(isPresented: $showHistory) {
            NavigationStack {
                List {
                    ForEach(groupedDays, id: \.self) { day in
                        Section(day) {
                            ForEach(history.filter { dayLabel($0.date) == day }) { record in
                                VStack(alignment: .leading, spacing: 8) {
                                    Text(record.expression).foregroundStyle(.secondary)
                                    Text(record.result).font(.title3)
                                }
                                .padding(.vertical, 12)
                            }
                            .onDelete { offsets in
                                let subset = history.filter { dayLabel($0.date) == day }
                                let ids = Set(offsets.map { subset[$0].id })
                                history.removeAll { ids.contains($0.id) }
                            }
                        }
                    }
                }
                .navigationTitle("Historial")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button(showEditor ? "Listo" : "Editar") { showEditor.toggle() }
                    }
                    ToolbarItem(placement: .topBarTrailing) {
                        Button { showHistory = false } label: {
                            Image(systemName: "xmark")
                        }
                    }
                }
                .environment(\.editMode, .constant(showEditor ? .active : .inactive))
            }
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
        }
    }

    private var visibleExpression: String {
        guard let left = lhs, let op = operation else { return display }
        return "\(format(left)) \(op) \(freshEntry ? "" : display)"
    }

    private var groupedDays: [String] {
        var result: [String] = []
        for item in history {
            let label = dayLabel(item.date)
            if !result.contains(label) { result.append(label) }
        }
        return result
    }
    private func dayLabel(_ date: Date) -> String {
        if Calendar.current.isDateInToday(date) { return "Hoy" }
        if Calendar.current.isDateInYesterday(date) { return "Ayer" }
        return date.formatted(date: .abbreviated, time: .omitted)
    }
    private func modeIcon(_ value: String) -> String {
        switch value {
        case "Científica": return "function"
        case "Notas matemáticas": return "pencil.and.outline"
        case "Convertir": return "arrow.left.arrow.right"
        default: return "plus.forwardslash.minus"
        }
    }
    private func buttonColor(_ key: String) -> Color {
        if ["÷", "×", "−", "+", "="].contains(key) { return Color(red: 1, green: 0.58, blue: 0.05) }
        if ["⌫", "AC", "%"].contains(key) { return Color(white: 0.38) }
        return Color(white: 0.19)
    }
    private func tap(_ key: String) {
        if key.count == 1, let digit = key.first, digit.isNumber {
            if freshEntry { entry = ""; freshEntry = false }
            if entry.count >= 16 { return }
            entry = entry == "0" ? key : entry + key
            display = entry
            return
        }
        switch key {
        case "AC":
            display = "0"; entry = ""; lhs = nil; operation = nil
            lastOperation = nil; lastOperand = nil; freshEntry = true
        case "⌫":
            if !freshEntry {
                entry = String(entry.dropLast())
                display = entry.isEmpty ? "0" : entry
            }
        case ".":
            if freshEntry { entry = "0"; freshEntry = false }
            if !entry.contains(".") { entry += "."; display = entry }
        case "+/−":
            if let value = Double(display) {
                display = format(-value); entry = display; freshEntry = false
            }
        case "%":
            if let value = Double(display) {
                let base = lhs ?? 0
                let result = (operation == "+" || operation == "−") ? base * value / 100 : value / 100
                display = format(result); entry = display; freshEntry = false
            }
        case "+", "−", "×", "÷":
            if let old = operation, let left = lhs, !freshEntry, let right = Double(display) {
                let value = evaluate(left, right, old)
                guard value.isFinite else { display = "Error"; return }
                display = format(value)
            }
            lhs = Double(display)
            operation = key
            freshEntry = true
        case "=":
            // "=" resuelve únicamente operaciones matemáticas.
            // El acceso por licencia utiliza el control visible "Acceder con key".
            if let left = lhs, let op = operation, let right = Double(display) {
                finish(left, right, op)
            } else if let op = lastOperation, let right = lastOperand, let left = Double(display) {
                finish(left, right, op)
            }
        default: break
        }
    }
    private func evaluate(_ left: Double, _ right: Double, _ op: String) -> Double {
        switch op {
        case "+": return left + right
        case "−": return left - right
        case "×": return left * right
        default: return right == 0 ? .nan : left / right
        }
    }
    private func finish(_ left: Double, _ right: Double, _ op: String) {
        let value = evaluate(left, right, op)
        let result = value.isFinite ? format(value) : "Error"
        history.insert(CalculationRecord(expression: "\(format(left))\(op)\(format(right))",
                                         result: result), at: 0)
        display = result
        entry = result
        lhs = nil
        operation = nil
        lastOperation = op
        lastOperand = right
        freshEntry = true
    }
    private func format(_ value: Double) -> String {
        guard value.isFinite else { return "Error" }
        if value.rounded() == value && abs(value) < 1e15 { return String(Int64(value)) }
        return String(format: "%.10g", value)
    }
}

class AppState: ObservableObject {
    @Published var exploitStatus: ExploitStatus = .notStarted
    @Published var unsupportedMessage: String?
    @Published var kernelExploitRunning = false

    private var autoRunAttempted = false

    var kernelExploitApplicable: Bool {
        KernelExploit.isApplicable(
            major: AppInfo.versionTuple.major,
            minor: AppInfo.versionTuple.minor,
            patch: AppInfo.versionTuple.patch,
            build: AppInfo.osBuild
        )
    }

    var isSupported: Bool { unsupportedMessage == nil }

    func detectSupport() {
        let v = AppInfo.versionTuple
        let supported = ExploitSupportPolicy.isSupported(
            major: v.major,
            minor: v.minor,
            patch: v.patch,
            build: AppInfo.osBuild
        )
#if targetEnvironment(simulator)
        if ProcessInfo.processInfo.arguments.contains("--simulate-access") {
            exploitStatus = .success(method: "Simulator preview")
        }
#endif

        unsupportedMessage = supported ? nil : "iOS \(AppInfo.osVersion) (\(AppInfo.osBuild))"
        if let unsupportedMessage {
            exploitStatus = .unsupported(unsupportedMessage)
            return
        }

        let applicable = KernelExploit.isApplicable(
            major: v.major,
            minor: v.minor,
            patch: v.patch,
            build: AppInfo.osBuild
        )
        guard applicable else { return }

        refreshKernelExploitStatus()
        maybeAutoRunKernelExploit()
    }

    private func maybeAutoRunKernelExploit() {
        guard !kernelExploitRunning,
              !exploitStatus.isSuccess,
              !exploitStatus.isFailed,
              !autoRunAttempted else { return }
        autoRunAttempted = true
        log("app: starting kernel exploit automatically")
        runKernelExploitIfNeeded()
    }

    private func refreshKernelExploitStatus() {
        guard !kernelExploitRunning else { return }

        // iOS < 26: kernel R/W success persists (no sandbox probe)
        // iOS >= 26: verify full sandbox escape is still active
        if KernelExploit.requiresSandboxEscape {
            if KernelExploit.hasSandboxAccess() {
                if !exploitStatus.isSuccess {
                    exploitStatus = .success(method: "kexploit")
                    log("app: existing sandbox access is still active; skipping kernel exploit")
                }
            } else if exploitStatus.isSuccess {
                exploitStatus = .notStarted
                log("app: sandbox access is no longer active")
            }
        }
    }

    func runKernelExploitIfNeeded() {
        refreshKernelExploitStatus()
        guard !kernelExploitRunning,
              !exploitStatus.isSuccess,
              !exploitStatus.isFailed else { return }
        kernelExploitRunning = true
        exploitStatus = .notStarted
        log("app: running kernel exploit on background...")
        DispatchQueue.global(qos: .userInitiated).async {
            let ok = KernelExploit.run()
            DispatchQueue.main.async {
                self.kernelExploitRunning = false
                if ok {
                    self.exploitStatus = .success(method: "kexploit")
                    if KernelExploit.requiresSandboxEscape {
                        log("app: kernel exploit success — sandbox access verified")
                    } else {
                        log("app: kernel exploit success — kernel access active")
                    }
                } else {
                    self.exploitStatus = .failed(method: "kexploit", code: -1)
                    log("app: kernel exploit failed — relaunch the app before retrying")
                }
            }
        }
    }
}



// Pantalla de marca antes del diálogo de permisos del sistema.
private struct PantherNotificationIntro: View {
    let onContinue: () -> Void
    let onLater: () -> Void
    @State private var working = false
    var body: some View {
        ZStack {
            LinearGradient(colors: [.black, Color(red: 0.02, green: 0.08, blue: 0.20), .black],
                           startPoint: .top, endPoint: .bottom).ignoresSafeArea()
            VStack(spacing: 18) {
                Spacer()
                Image("PantherLaunch")
                    .resizable().scaledToFit().frame(maxWidth: 290, maxHeight: 280)
                    .clipShape(RoundedRectangle(cornerRadius: 22))
                Text("PANTHER iOS").font(.system(size: 30, weight: .black))
                    .foregroundStyle(.white)
                Text("Activa las notificaciones para recibir tu bienvenida, los avisos cada hora en las últimas 24 horas y el aviso de vencimiento de tu key.")
                    .multilineTextAlignment(.center).foregroundStyle(.white.opacity(0.85))
                    .padding(.horizontal, 26)
                Spacer()
                Button {
                    guard !working else { return }
                    working = true
                    Task {
                        let center = UNUserNotificationCenter.current()
                        let settings = await center.notificationSettings()
                        if settings.authorizationStatus == .notDetermined {
                            _ = try? await center.requestAuthorization(options: [.alert, .sound, .badge])
                        }
                        onContinue()
                    }
                } label: {
                    Text(working ? "Continuando…" : "Continuar")
                        .font(.headline).frame(maxWidth: .infinity).padding()
                        .background(Color.blue, in: RoundedRectangle(cornerRadius: 14))
                        .foregroundStyle(.white)
                }.disabled(working)
                Button("Ahora no") { onLater() }
                    .foregroundStyle(.white.opacity(0.8)).padding(.bottom, 24)
            }.padding(24)
        }
    }
}

// MARK: - Recordatorio local de licencia
// Cada instalación programa su propio aviso a partir de la fecha verificada por el servidor.
@MainActor
enum PantherExpiryReminder {
    private static let identifierPrefix = "panther.license.expires.hourly."
    private static let legacyIdentifier = "panther.license.expires.in.24h"
    private static let expiredIdentifier = "panther.license.expired"
    private static let welcomeIdentifier = "panther.license.welcome"
    private static let hour: TimeInterval = 60 * 60

    static func cancel() {
        let ids = [legacyIdentifier, expiredIdentifier] + (0..<24).map { "\(identifierPrefix)\($0)" }
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ids)
        UserDefaults.standard.removeObject(forKey: "PantherExpiryScheduledStamp")
    }

    private static func pantherAttachment() -> UNNotificationAttachment? {
        guard let image = UIImage(named: "PantherLaunch"),
              let data = image.jpegData(compressionQuality: 0.85) else { return nil }
        let path = FileManager.default.temporaryDirectory.appendingPathComponent("panther-notification.jpg")
        guard (try? data.write(to: path, options: .atomic)) != nil else { return nil }
        return try? UNNotificationAttachment(identifier: "panther", url: path, options: nil)
    }

    static func welcome(key: String) async {
        // Una sola bienvenida por key nueva en esta instalación.
        let fingerprint = SHA256.hash(data: Data(key.utf8)).map { String(format: "%02x", $0) }.joined()
        let storageKey = "PantherWelcomedKey." + fingerprint
        guard !UserDefaults.standard.bool(forKey: storageKey) else { return }
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        if settings.authorizationStatus == .notDetermined { return }
        let updated = await center.notificationSettings()
        guard updated.authorizationStatus == .authorized || updated.authorizationStatus == .provisional else { return }
        let content = UNMutableNotificationContent()
        content.title = "🐆 PANTHER iOS"
        content.body = "¡Gracias por preferir Panther iOS!"
        content.sound = .default
        if let attachment = pantherAttachment() { content.attachments = [attachment] }
        let request = UNNotificationRequest(identifier: welcomeIdentifier, content: content,
            trigger: UNTimeIntervalNotificationTrigger(timeInterval: 2, repeats: false))
        center.removePendingNotificationRequests(withIdentifiers: [welcomeIdentifier])
        do {
            try await center.add(request)
            UserDefaults.standard.set(true, forKey: storageKey)
        } catch { print("Panther welcome notification error: \(error.localizedDescription)") }
    }

    static func update(expiry: Date?, permanent: Bool, key: String?) async {
        let center = UNUserNotificationCenter.current()
        guard !permanent, let expiry, expiry > Date() else {
            cancel()
            return
        }
        // No borrar y recrear avisos en cada verificación de 30 segundos.
        let expiryStamp = String(Int(expiry.timeIntervalSince1970))
        let scheduledStamp = UserDefaults.standard.string(forKey: "PantherExpiryScheduledStamp")
        let existing = await center.pendingNotificationRequests()
        if scheduledStamp == expiryStamp && existing.contains(where: {
            $0.identifier.hasPrefix(identifierPrefix) || $0.identifier == expiredIdentifier
        }) { return }
        cancel()
        let settings = await center.notificationSettings()
        if settings.authorizationStatus == .notDetermined { return }
        let updatedSettings = await center.notificationSettings()
        guard updatedSettings.authorizationStatus == .authorized || updatedSettings.authorizationStatus == .provisional else { return }

        // Avisos en las horas 24, 23, ..., 1 antes del vencimiento.
        // Al renovar, se cancelan y se reconstruyen usando la fecha nueva del servidor.
        for remainingHours in (1...24).reversed() {
            let fireDate = expiry.addingTimeInterval(-Double(remainingHours) * hour)
            let seconds = fireDate.timeIntervalSinceNow
            guard seconds > 0 else { continue }
            let content = UNMutableNotificationContent()
            content.title = "🐆 PANTHER iOS"
            content.body = "A tu Eternal ya le faltan menos de 24 horas para vencer. ¡Renueva tu key!"
            content.sound = .default
            content.categoryIdentifier = "PANTHER_KEY_EXPIRY"
            if let attachment = pantherAttachment() { content.attachments = [attachment] }
            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: seconds, repeats: false)
            let identifier = "\(identifierPrefix)\(24 - remainingHours)"
            try? await center.add(UNNotificationRequest(identifier: identifier, content: content, trigger: trigger))
        }
        // El aviso final queda programado para el instante exacto del vencimiento.
        // Al renovar y revalidar, update() cancela este aviso y lo reprograma.
        let expired = UNMutableNotificationContent()
        expired.title = "🐆 PANTHER iOS — Key vencida"
        let displayedKey = (key ?? "tu key").trimmingCharacters(in: .whitespacesAndNewlines)
        expired.body = "Tu key \(displayedKey) ha vencido. Compra otra key o renuévala con @Panther ios en Telegram."
        expired.sound = .default
        if let attachment = pantherAttachment() { expired.attachments = [attachment] }
        let secondsToExpiry = expiry.timeIntervalSinceNow
        if secondsToExpiry > 0 {
            try? await center.add(UNNotificationRequest(identifier: expiredIdentifier, content: expired,
                trigger: UNTimeIntervalNotificationTrigger(timeInterval: secondsToExpiry, repeats: false)))
        }
        UserDefaults.standard.set(expiryStamp, forKey: "PantherExpiryScheduledStamp")
    }
}

// MARK: - Panther iOS license API (Lovable)
@MainActor
final class PantherSession: ObservableObject {
    @Published var role: String?
    @Published var expiresAt: Date?
    @Published var permanent = false
    @Published var expiredNotice = false
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var publishedPatches: [PantherPatch] = []
    @Published var catalogMessage: String?
    @Published var catalogLoading = false

    private let apiBase = (Bundle.main.object(forInfoDictionaryKey: "PantherAPIBaseURL") as? String ?? "https://panther-servidor.onrender.com")
        .trimmingCharacters(in: CharacterSet(charactersIn: "/"))
    // The key is saved in the iOS Keychain, never in a public app resource.
    private let savedKeyService = "PantherIOS.ActiveLicense"
    private let savedKeyAccount = "current-device"
    private var activeKey: String?
    private var accessToken: String?

    private func saveKey(_ key: String) {
        let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword,
                                    kSecAttrService as String: savedKeyService,
                                    kSecAttrAccount as String: savedKeyAccount]
        SecItemDelete(query as CFDictionary)
        var item = query
        item[kSecValueData as String] = Data(key.utf8)
        item[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        let status = SecItemAdd(item as CFDictionary, nil)
        if status != errSecSuccess { print("Could not save license in Keychain: \(status)") }
    }

    private func readSavedKey() -> String? {
        let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword,
                                    kSecAttrService as String: savedKeyService,
                                    kSecAttrAccount as String: savedKeyAccount,
                                    kSecReturnData as String: true,
                                    kSecMatchLimit as String: kSecMatchLimitOne]
        var result: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    private func clearSavedKey() {
        SecItemDelete([kSecClass as String: kSecClassGenericPassword,
                       kSecAttrService as String: savedKeyService,
                       kSecAttrAccount as String: savedKeyAccount] as CFDictionary)
    }

    func restoreSavedKey() async {
        guard role == nil, !isLoading, let saved = readSavedKey() else { return }
        await activate(key: saved, restored: true)
        // If revoked or expired, require a new key on the next launch.
        if role == nil, let errorMessage,
           errorMessage.contains("revocada") || errorMessage.contains("vencid") || errorMessage.contains("no existe") || errorMessage.contains("otro dispositivo") {
            clearSavedKey()
        }
    }
    private var deviceID: String {
        UIDevice.current.identifierForVendor?.uuidString ?? "unavailable-device"
    }

    private func post(_ path: String, key: String) async throws -> (Data, Int) {
        guard let url = URL(string: apiBase + path), url.scheme == "https" else {
            throw PantherAPIError.message("La URL HTTPS de Panther Servidor no está configurada.")
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 20
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: ["key": key, "device_id": deviceID])
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw PantherAPIError.message("Respuesta HTTP no válida.")
        }
        return (data, http.statusCode)
    }

    private func message(_ data: Data, status: Int) -> String {
        let body = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] ?? [:]
        let code = body["error"] as? String ?? ""
        switch code {
        case "invalid_key": return "La key no existe."
        case "device_mismatch": return "Esta key está vinculada a otro dispositivo."
        case "revoked": return "Esta key fue revocada."
        case "expired": return "La key ha vencido."
        case "not_activated": return "La key aún no está activada."
        case "invalid_request": return "La key o el identificador del dispositivo no es válido."
        default: return "El servidor rechazó la solicitud (HTTP \(status))."
        }
    }

    private func getAuthorized(_ path: String) async throws -> (Data, Int) {
        guard let accessToken else { throw PantherAPIError.message("Falta el token de sesión. Vuelve a ingresar tu key.") }
        guard let url = URL(string: apiBase + path), url.scheme == "https" else {
            throw PantherAPIError.message("La URL HTTPS de Panther Servidor no está configurada.")
        }
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 25
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw PantherAPIError.message("Respuesta HTTP no válida.") }
        return (data, http.statusCode)
    }

    func activate(key: String, restored: Bool = false) async {
        let enteredKey = key.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !enteredKey.isEmpty else { errorMessage = "Introduce una key."; return }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            let (data, status) = try await post("/v1/activate", key: enteredKey)
            guard (200...299).contains(status) else {
                errorMessage = message(data, status: status)
                return
            }
            let result = try JSONDecoder().decode(PantherActivationResponse.self, from: data)
            guard !result.token.isEmpty else { errorMessage = "El servidor no devolvió un token válido."; return }
            guard result.permanent == true || result.expiry != nil else { errorMessage = "El servidor no devolvió la fecha de vencimiento."; return }
            if let date = result.expiry, date <= Date(), result.permanent != true { errorMessage = "Key vencida."; return }
            expiresAt = result.expiry
            permanent = result.permanent == true
            expiredNotice = false
            activeKey = enteredKey
            accessToken = result.token
            saveKey(enteredKey)
            role = "patches"
            await PantherExpiryReminder.update(expiry: expiresAt, permanent: permanent, key: activeKey)
            if !restored { await PantherExpiryReminder.welcome(key: enteredKey) }
            await refreshCatalog()
        } catch {
            errorMessage = "No se pudo verificar la key: \(error.localizedDescription)"
        }
    }

    func checkExpiry() {
        if role != nil && !permanent, let expiresAt, Date() >= expiresAt { signOut(expired: true) }
    }
    func revalidate() async {
        guard let activeKey, role != nil else { return }
        do {
            let (data, status) = try await post("/v1/activate", key: activeKey)
            guard (200...299).contains(status) else {
                let obj = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
                signOut(expired: (obj?["error"] as? String) == "expired")
                return
            }
            let result = try JSONDecoder().decode(PantherActivationResponse.self, from: data)
            guard !result.token.isEmpty, result.permanent == true || result.expiry != nil else { signOut(); return }
            accessToken = result.token
            expiresAt = result.expiry
            permanent = result.permanent == true
            await PantherExpiryReminder.update(expiry: expiresAt, permanent: permanent, key: activeKey)
            checkExpiry()
        } catch { checkExpiry() }
    }
    func refreshCatalog() async {
        guard activeKey != nil else { return }
        catalogLoading = true
        catalogMessage = nil
        defer { catalogLoading = false }
        do {
            let (data, status) = try await getAuthorized("/v1/patches")
            guard (200...299).contains(status) else {
                catalogMessage = message(data, status: status)
                return
            }
            let result = try JSONDecoder().decode(PantherPatchResponse.self, from: data)
            publishedPatches = result.patches
            if result.patches.isEmpty { catalogMessage = "No hay patches publicados todavía." }
        } catch {
            catalogMessage = "No se pudo actualizar el catálogo: \(error.localizedDescription)"
        }
    }

    // Descarga autenticada: el servidor debe validar key + dispositivo en cada solicitud.
    func downloadPatch(_ patch: PantherPatch) async throws -> URL {
        guard activeKey != nil else { throw PantherAPIError.message("Inicia sesión con una key válida.") }
        guard let identifier = patch.id.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) else {
            throw PantherAPIError.message("Identificador de patch inválido.")
        }
        let (data, status) = try await getAuthorized("/v1/patches/\(identifier)/download")
        guard (200...299).contains(status) else { throw PantherAPIError.message(message(data, status: status)) }
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("PantherRemotePatches", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let filename = UUID().uuidString + ".3105"
        let destination = directory.appendingPathComponent(filename)
        try data.write(to: destination, options: [.atomic, .completeFileProtection])
        return destination
    }

    func signOut(expired: Bool = false) {
        if !expired { PantherExpiryReminder.cancel() }
        clearSavedKey()
        expiredNotice = expired
        expiresAt = nil
        permanent = false
        publishedPatches = []
        catalogMessage = nil
        role = nil
        activeKey = nil
        accessToken = nil
        errorMessage = nil
    }
}

private enum PantherAPIError: LocalizedError {
    case message(String)
    var errorDescription: String? {
        if case .message(let value) = self { return value }
        return nil
    }
}

private struct PantherActivationResponse: Decodable {
    let token: String
    let expires_at: String?
    let permanent: Bool?
    var expiry: Date? {
        guard let expires_at else { return nil }
        let parser = ISO8601DateFormatter()
        if let date = parser.date(from: expires_at) { return date }
        parser.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return parser.date(from: expires_at)
    }
}

private struct PantherPatchResponse: Decodable {
    let patches: [PantherPatch]
}

struct PantherPatch: Decodable, Identifiable {
    let id: String
    let name: String
    let description: String?
    let version: String?
    let category: String?
    let download_url: String?
    enum CodingKeys: String, CodingKey { case id, name, description, version, category, download_url }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        name = try c.decode(String.self, forKey: .name)
        description = try c.decodeIfPresent(String.self, forKey: .description)
        if let v = try? c.decode(String.self, forKey: .version) { version = v }
        else if let v = try? c.decode(Int.self, forKey: .version) { version = String(v) }
        else { version = nil }
        category = try c.decodeIfPresent(String.self, forKey: .category)
        download_url = try c.decodeIfPresent(String.self, forKey: .download_url)
    }
}
private struct PantherNeonBrand: View {
    var body: some View {
        HStack(spacing: 6) {
            Image("PantherAppMark")
                .resizable()
                .scaledToFit()
                .frame(width: 59, height: 59)
                .clipShape(Circle())
            Text("Panther iOS")
                .font(.system(size: 37, weight: .bold, design: .serif))
                .italic()
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
            Image(systemName: "crown.fill")
                .font(.system(size: 23))
                .foregroundStyle(.cyan)
        }
        .shadow(color: .cyan.opacity(0.9), radius: 8)
        .accessibilityElement(children: .combine)
    }
}

private struct PantherLoginView: View {
    @ObservedObject var session: PantherSession
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var key = ""

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .topLeading) {
                Color.black
                TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: reduceMotion)) { timeline in
                    let t = timeline.date.timeIntervalSinceReferenceDate
                    Image("GhostKeyBackground")
                        .resizable()
                        .scaledToFill()
                        .frame(width: 390, height: 844)
                        .scaleEffect(reduceMotion ? 1.04 : 1.04 + 0.014 * sin(t * 1.8))
                        .offset(x: reduceMotion ? 0 : 6 * sin(t * 1.5),
                                y: reduceMotion ? 0 : 5 * sin(t * 2.0))
                        .frame(width: 390, height: 844)
                        .clipped()
                }
                PantherNeonBrand()
                    .frame(width: 350, height: 68)
                    .position(x: 195, y: 365)

                HStack(spacing: 12) {
                    Image(systemName: "key.fill")
                        .font(.system(size: 21))
                        .foregroundStyle(.white)
                    Rectangle()
                        .fill(Color.cyan.opacity(0.7))
                        .frame(width: 1, height: 27)
                    TextField("", text: $key,
                              prompt: Text("Ingresa tu Key")
                                .foregroundColor(.white.opacity(0.38)))
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .foregroundStyle(.white)
                        .font(.system(size: 20, weight: .medium))
                }
                .padding(.horizontal, 20)
                .frame(width: 350, height: 57)
                .background(Color.black.opacity(0.86), in: RoundedRectangle(cornerRadius: 19))
                .overlay(RoundedRectangle(cornerRadius: 19).stroke(Color.cyan, lineWidth: 2))
                .shadow(color: .cyan.opacity(0.75), radius: 8)
                .position(x: 195, y: 447)

                // The error is fixed between the input and button, so it never moves controls.
                Group {
                    if session.expiredNotice {
                        Text("Key vencida")
                    } else if let message = session.errorMessage {
                        Text(message)
                    }
                }
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.orange)
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .frame(width: 340, height: 34)
                .position(x: 195, y: 492)

                Button {
                    Task { await session.activate(key: key) }
                } label: {
                    Label(session.isLoading ? "Verificando..." : "Entrar",
                          systemImage: "rectangle.portrait.and.arrow.right")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 275, height: 57)
                        .background(Color.black.opacity(0.85), in: RoundedRectangle(cornerRadius: 19))
                        .overlay(RoundedRectangle(cornerRadius: 19).stroke(Color.cyan, lineWidth: 2))
                        .shadow(color: .cyan.opacity(0.9), radius: 9)
                }
                .disabled(session.isLoading)
                .position(x: 195, y: 550)

                Text("¿No tienes una Key?")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(.white)
                    .position(x: 195, y: 685)

                Link(destination: URL(string: "https://t.me/+6L89Qcso3w9kN2Yx")!) {
                    Label("Únete a mi Telegram", systemImage: "paperplane.fill")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(.cyan)
                        .frame(width: 320, height: 52)
                        .background(Color.black.opacity(0.85), in: Capsule())
                        .overlay(Capsule().stroke(Color.cyan, lineWidth: 2))
                        .shadow(color: .cyan.opacity(0.6), radius: 7)
                }
                .position(x: 195, y: 735)
            }
            .frame(width: 390, height: 844)
            .scaleEffect(x: proxy.size.width / 390,
                         y: proxy.size.height / 844,
                         anchor: .topLeading)
            .frame(width: proxy.size.width, height: proxy.size.height, alignment: .topLeading)
        }
        .ignoresSafeArea()
        .statusBarHidden(true)
    }
}

// Normal keys use the same original patch project interface as the administrator.
// No per-key patch assignments, online catalog or separate package viewer.
private struct PantherAssignedPatchesView: View {
    @ObservedObject var session: PantherSession

    var body: some View {
        PatchProjectsView(ghostTheme: true)
            .background(Color.black.ignoresSafeArea())
            .statusBarHidden(true)
    }
}
