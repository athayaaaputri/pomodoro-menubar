import SwiftUI
import AppKit
import ServiceManagement

// MARK: - Model

enum Phase: String {
    case focus, short, long

    var label: String {
        switch self {
        case .focus: return "Focus"
        case .short: return "Short break"
        case .long:  return "Long break"
        }
    }

    var color: Color {
        switch self {
        case .focus: return Color(red: 0.85, green: 0.33, blue: 0.31)
        case .short: return Color(red: 0.23, green: 0.62, blue: 0.48)
        case .long:  return Color(red: 0.24, green: 0.49, blue: 0.79)
        }
    }
}

enum Mode: String, CaseIterable, Identifiable {
    case classic, extended
    var id: String { rawValue }

    var title: String { self == .classic ? "25 / 5" : "50 / 10" }
    var focus: Int  { self == .classic ? 25 : 50 }
    var short: Int  { self == .classic ? 5 : 10 }
    var long: Int   { 15 }
    var every: Int  { self == .classic ? 4 : 2 }

    func minutes(_ p: Phase) -> Int {
        switch p {
        case .focus: return focus
        case .short: return short
        case .long:  return long
        }
    }
}

@MainActor
final class Pomodoro: ObservableObject {
    @Published private(set) var mode: Mode
    @Published private(set) var phase: Phase = .focus
    @Published private(set) var done = 0          // focus sessions done in current cycle
    @Published private(set) var totalToday = 0
    @Published private(set) var remaining: TimeInterval = 0
    @Published private(set) var isRunning = false

    @Published var autoStart: Bool { didSet { defaults.set(autoStart, forKey: "autoStart") } }
    @Published var sound: Bool     { didSet { defaults.set(sound, forKey: "sound") } }
    @Published var showPopup: Bool { didSet { defaults.set(showPopup, forKey: "showPopup") } }
    @Published var showTimeInBar: Bool { didSet { defaults.set(showTimeInBar, forKey: "showTimeInBar") } }

    private let defaults = UserDefaults.standard
    private var endAt: Date?
    private var timer: Timer?
    private let popup = PopupController()

    init() {
        defaults.register(defaults: ["autoStart": true, "sound": true, "showPopup": true, "showTimeInBar": true])
        mode = Mode(rawValue: defaults.string(forKey: "mode") ?? "") ?? .classic
        autoStart = defaults.bool(forKey: "autoStart")
        sound = defaults.bool(forKey: "sound")
        showPopup = defaults.bool(forKey: "showPopup")
        showTimeInBar = defaults.bool(forKey: "showTimeInBar")
        rollDay()
        totalToday = defaults.integer(forKey: "totalToday")
        remaining = duration
    }

    var duration: TimeInterval { TimeInterval(mode.minutes(phase) * 60) }
    var progress: Double { duration > 0 ? 1 - remaining / duration : 0 }
    var isFresh: Bool { remaining >= duration }

    var timeString: String {
        let s = Int(remaining.rounded(.up))
        return String(format: "%02d:%02d", s / 60, s % 60)
    }

    // MARK: Controls

    func toggle() { isRunning ? pause() : start() }

    func start() {
        guard !isRunning else { return }
        endAt = Date().addingTimeInterval(remaining)
        isRunning = true
        let t = Timer(timeInterval: 0.25, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.tick() }
        }
        RunLoop.main.add(t, forMode: .common)
        timer = t
    }

    func pause() {
        guard isRunning, let endAt else { return }
        remaining = max(0, endAt.timeIntervalSinceNow)
        stopTimer()
    }

    func reset() {
        stopTimer()
        remaining = duration
    }

    func skip() { advance(natural: false) }

    func setMode(_ m: Mode) {
        guard m != mode else { return }
        stopTimer()
        mode = m
        defaults.set(m.rawValue, forKey: "mode")
        done = 0
        phase = .focus
        remaining = duration
    }

    // MARK: Internals

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
        endAt = nil
        isRunning = false
    }

    private func tick() {
        guard let endAt else { return }
        remaining = max(0, endAt.timeIntervalSinceNow)
        if remaining <= 0 { advance(natural: true) }
    }

    private func advance(natural: Bool) {
        let wasRunning = isRunning
        stopTimer()
        let finished = phase
        let next: Phase
        if phase == .focus {
            if natural {
                rollDay()
                totalToday += 1
                defaults.set(totalToday, forKey: "totalToday")
            }
            done += 1
            next = done >= mode.every ? .long : .short
        } else {
            if phase == .long { done = 0 }
            next = .focus
        }
        phase = next
        remaining = duration

        if natural {
            if sound { NSSound(named: finished == .focus ? "Glass" : "Hero")?.play() }
            if showPopup { popup.show(finished: finished, next: next, minutes: mode.minutes(next), autoStarted: autoStart, model: self) }
        }
        if (natural && autoStart) || (!natural && wasRunning) { start() }
    }

    private func rollDay() {
        let today = DateFormatter.localizedString(from: Date(), dateStyle: .short, timeStyle: .none)
        if defaults.string(forKey: "day") != today {
            defaults.set(today, forKey: "day")
            defaults.set(0, forKey: "totalToday")
            totalToday = 0
        }
    }
}

// MARK: - Pop-up when a phase ends

@MainActor
final class PopupController {
    private var panel: NSPanel?
    private var closeWork: DispatchWorkItem?

    func show(finished: Phase, next: Phase, minutes: Int, autoStarted: Bool, model: Pomodoro) {
        close()
        let title = finished == .focus ? "Focus session done!" : "Break's over"
        let subtitle = finished == .focus
            ? "Time for a \(next.label.lowercased()) — \(minutes) min."
            : "Back to focus — \(minutes) min."

        let view = PopupView(title: title, subtitle: subtitle, color: next.color,
                             showStart: !autoStarted,
                             onStart: { [weak self] in model.start(); self?.close() },
                             onDismiss: { [weak self] in self?.close() })
        let host = NSHostingView(rootView: view)
        host.frame = NSRect(x: 0, y: 0, width: 320, height: 110)

        let p = NSPanel(contentRect: host.frame,
                        styleMask: [.nonactivatingPanel, .borderless],
                        backing: .buffered, defer: false)
        p.contentView = host
        p.isOpaque = false
        p.backgroundColor = .clear
        p.hasShadow = true
        p.level = .statusBar
        p.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        p.isMovableByWindowBackground = true

        if let screen = NSScreen.main {
            let f = screen.visibleFrame
            p.setFrameOrigin(NSPoint(x: f.maxX - 320 - 16, y: f.maxY - 110 - 16))
        }
        p.alphaValue = 0
        p.orderFrontRegardless()
        NSAnimationContext.runAnimationGroup { $0.duration = 0.25; p.animator().alphaValue = 1 }
        panel = p

        // Stay up longer when the user needs to click Start.
        let work = DispatchWorkItem { [weak self] in self?.close() }
        closeWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + (autoStarted ? 10 : 60), execute: work)
    }

    func close() {
        closeWork?.cancel()
        panel?.orderOut(nil)
        panel = nil
    }
}

struct PopupView: View {
    let title: String
    let subtitle: String
    let color: Color
    let showStart: Bool
    let onStart: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: "timer")
                .font(.system(size: 26, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 48, height: 48)
                .background(Circle().fill(color))
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.headline)
                Text(subtitle).font(.subheadline).foregroundStyle(.secondary)
                HStack {
                    if showStart {
                        Button("Start", action: onStart).buttonStyle(.borderedProminent).tint(color)
                    }
                    Button("Dismiss", action: onDismiss)
                }
                .controlSize(.small)
                .padding(.top, 2)
            }
            Spacer(minLength: 0)
        }
        .padding(14)
        .frame(width: 320, height: 110)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
    }
}

// MARK: - Menu bar panel

struct PanelView: View {
    @ObservedObject var model: Pomodoro
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled

    var body: some View {
        VStack(spacing: 14) {
            Picker("", selection: Binding(get: { model.mode }, set: { model.setMode($0) })) {
                ForEach(Mode.allCases) { Text($0.title).tag($0) }
            }
            .pickerStyle(.segmented)
            .labelsHidden()

            Text("\(model.mode.focus)m focus · \(model.mode.short)m break · \(model.mode.long)m long break after \(model.mode.every)")
                .font(.caption)
                .foregroundStyle(.secondary)

            ZStack {
                Circle().stroke(Color.secondary.opacity(0.15), lineWidth: 9)
                Circle()
                    .trim(from: 0, to: model.progress)
                    .stroke(model.phase.color, style: StrokeStyle(lineWidth: 9, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .animation(.linear(duration: 0.25), value: model.progress)
                VStack(spacing: 2) {
                    Text(model.phase.label.uppercased())
                        .font(.caption.weight(.bold))
                        .tracking(1)
                        .foregroundStyle(model.phase.color)
                    Text(model.timeString)
                        .font(.system(size: 44, weight: .light).monospacedDigit())
                }
            }
            .frame(width: 180, height: 180)
            .padding(.vertical, 4)

            HStack(spacing: 8) {
                ForEach(0..<model.mode.every, id: \.self) { i in
                    Circle()
                        .strokeBorder(Phase.focus.color, lineWidth: 2)
                        .background(Circle().fill(i < model.done ? Phase.focus.color : .clear))
                        .frame(width: 11, height: 11)
                }
            }
            Text("\(model.totalToday) focus session\(model.totalToday == 1 ? "" : "s") today")
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack(spacing: 10) {
                Button("Reset") { model.reset() }
                Button(model.isRunning ? "Pause" : (model.isFresh ? "Start" : "Resume")) { model.toggle() }
                    .buttonStyle(.borderedProminent)
                    .tint(model.phase.color)
                    .keyboardShortcut(.space, modifiers: [])
                Button("Skip") { model.skip() }
            }
            .controlSize(.large)

            Divider()

            VStack(alignment: .leading, spacing: 6) {
                Toggle("Auto-start next phase", isOn: $model.autoStart)
                Toggle("Pop-up when time's up", isOn: $model.showPopup)
                Toggle("Sound", isOn: $model.sound)
                Toggle("Show time in menu bar", isOn: $model.showTimeInBar)
                Toggle("Open at login", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { _, on in
                        do { on ? try SMAppService.mainApp.register() : try SMAppService.mainApp.unregister() }
                        catch { launchAtLogin = SMAppService.mainApp.status == .enabled }
                    }
            }
            .toggleStyle(.checkbox)
            .font(.callout)
            .frame(maxWidth: .infinity, alignment: .leading)

            HStack {
                Spacer()
                Button("Quit Pomodoro") { NSApp.terminate(nil) }
                    .buttonStyle(.link)
                    .font(.caption)
            }
        }
        .padding(18)
        .frame(width: 280)
    }
}

// MARK: - App

@main
struct PomodoroApp: App {
    @StateObject private var model = Pomodoro()

    var body: some Scene {
        MenuBarExtra {
            PanelView(model: model)
        } label: {
            if model.showTimeInBar && (model.isRunning || !model.isFresh) {
                HStack(spacing: 3) {
                    Image(systemName: model.phase == .focus ? "timer" : "cup.and.saucer.fill")
                    Text(model.timeString).monospacedDigit()
                }
            } else {
                Image(systemName: "timer")
            }
        }
        .menuBarExtraStyle(.window)
    }
}
