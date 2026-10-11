// ANDROID_LITE_BUILD=5
import SwiftUI
import AVFoundation
import WebKit
import ImageIO

// MARK: - Theme (Material 3 Expressive / Pixel look)
enum T {
    static let bg = Color(red: 0.08, green: 0.09, blue: 0.11)
    static let card = Color(red: 0.16, green: 0.18, blue: 0.22)
    static let accent = Color(red: 0.66, green: 0.78, blue: 1.0)
    static let onAccent = Color(red: 0.0, green: 0.18, blue: 0.38)
}

func fmtDate(_ f: String) -> String {
    let d = DateFormatter()
    d.dateFormat = f
    return d.string(from: Date())
}

// MARK: - Models
struct AppInfo: Identifiable {
    let id: String
    let name: String
    let icon: String
    let tint: Color
}

let allApps: [AppInfo] = [
    AppInfo(id: "phone", name: "Phone", icon: "phone.fill", tint: Color(red: 0.55, green: 0.9, blue: 0.6)),
    AppInfo(id: "msg", name: "Messages", icon: "message.fill", tint: Color(red: 0.55, green: 0.75, blue: 1.0)),
    AppInfo(id: "web", name: "Chrome", icon: "globe", tint: Color(red: 1.0, green: 0.75, blue: 0.4)),
    AppInfo(id: "cam", name: "Camera", icon: "camera.fill", tint: Color(red: 0.95, green: 0.6, blue: 0.85)),
    AppInfo(id: "calc", name: "Calculator", icon: "plus.forwardslash.minus", tint: Color(red: 1.0, green: 0.85, blue: 0.45)),
    AppInfo(id: "cal", name: "Calendar", icon: "calendar", tint: Color(red: 0.6, green: 0.8, blue: 1.0)),
    AppInfo(id: "clock", name: "Clock", icon: "clock.fill", tint: Color(red: 0.75, green: 0.7, blue: 1.0)),
    AppInfo(id: "photos", name: "Photos", icon: "photo.fill", tint: Color(red: 1.0, green: 0.65, blue: 0.6)),
    AppInfo(id: "notes", name: "Keep Notes", icon: "note.text", tint: Color(red: 1.0, green: 0.9, blue: 0.5)),
    AppInfo(id: "settings", name: "Settings", icon: "gearshape.fill", tint: Color(red: 0.7, green: 0.8, blue: 0.85))
]

func appFor(_ id: String) -> AppInfo? { allApps.first(where: { $0.id == id }) }
func iconFor(_ id: String) -> String { appFor(id)?.icon ?? "bell.fill" }
func tintFor(_ id: String) -> Color { appFor(id)?.tint ?? T.accent }

let sortedApps: [AppInfo] = allApps.sorted { $0.name < $1.name }
let dockApps: [AppInfo] = ["phone", "msg", "web", "cam"].compactMap { appFor($0) }
let homeApps: [AppInfo] = ["calc", "cal", "clock", "photos", "notes", "settings"].compactMap { appFor($0) }

struct Notif: Identifiable {
    let id = UUID()
    let appId: String
    let title: String
    let body: String
    let date: Date
}

struct Contact: Identifiable {
    let id: String
    let name: String
    let color: Color
}

struct Msg: Identifiable {
    let id = UUID()
    let text: String
    let mine: Bool
}

let contacts: [Contact] = [
    Contact(id: "team", name: "Pixel Team", color: Color(red: 0.5, green: 0.85, blue: 0.6)),
    Contact(id: "mom", name: "Mom", color: Color(red: 1.0, green: 0.6, blue: 0.7)),
    Contact(id: "alex", name: "Alex", color: Color(red: 0.55, green: 0.7, blue: 1.0))
]
let canned: [String] = ["Haha okay!", "Sounds good 👍", "Call you later", "On my way", "Nice!", "Let's do it"]

enum Panel { case none, notif, qs }

// MARK: - "OS" state
final class OS: ObservableObject {
    @Published var open: AppInfo? = nil
    @Published var recents: [AppInfo] = []
    @Published var panel: Panel = .none
    @Published var showRecents = false
    @Published var drawer = false
    @Published var appShown = false
    @Published var backDrag: CGFloat = 0
    @Published var backLeft = true
    @Published var dragProg: CGFloat = 0
    @Published var wifi = true
    @Published var bt = true
    @Published var dnd = false
    @Published var airplane = false
    @Published var saver = false
    @Published var rotate = true
    @Published var flash = false { didSet { OS.torch(flash) } }
    @Published var brightness: Double = Double(UIScreen.main.brightness) {
        didSet { UIScreen.main.brightness = CGFloat(brightness) }
    }
    @Published var notifs: [Notif] = []
    @Published var banner: Notif? = nil
    @Published var threads: [String: [Msg]] = [
        "team": [Msg(text: "Welcome to your new Pixel-style phone ✨", mine: false)],
        "mom": [Msg(text: "Did you eat?", mine: false)],
        "alex": [Msg(text: "Are we still on for later?", mine: false)]
    ]
    @Published var viewingChat: String? = nil
    @Published var events: [String: [String]] = [:]
    @Published var top: CGFloat = 47
    @Published var bottom: CGFloat = 34
    lazy var browser = WebModel()
    var origin: CGPoint? = nil
    var backHandlers: [String: () -> Bool] = [:]

    init() {
        notifs = [Notif(appId: "msg", title: "Pixel Team", body: "Welcome to Android Lite 16 ✨", date: Date())]
    }

    var padTop: CGFloat { max(top, 24) + 34 }

    static func torch(_ on: Bool) {
        guard let d = AVCaptureDevice.default(for: .video), d.hasTorch else { return }
        try? d.lockForConfiguration()
        d.torchMode = on ? .on : .off
        d.unlockForConfiguration()
    }

    func post(_ appId: String, _ title: String, _ body: String) {
        let n = Notif(appId: appId, title: title, body: body, date: Date())
        notifs.insert(n, at: 0)
        if dnd { return }
        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) { banner = n }
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.5) { [weak self] in
            if self?.banner?.id == n.id {
                withAnimation { self?.banner = nil }
            }
        }
    }

    func closePanel() {
        withAnimation(.easeOut(duration: 0.25)) { panel = .none }
    }

    func goBack() {
        if panel != .none { closePanel(); return }
        if showRecents { home(); return }
        if drawer {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.88)) { drawer = false }
            return
        }
        if let a = open {
            if let h = backHandlers[a.id], h() { return }
            home()
        }
    }

    func launch(_ a: AppInfo, from p: CGPoint? = nil) {
        origin = p
        withAnimation(.spring(response: 0.35, dampingFraction: 0.88)) {
            recents.removeAll { $0.id == a.id }
            recents.insert(a, at: 0)
            showRecents = false
            drawer = false
            panel = .none
        }
        appShown = false
        open = a
        DispatchQueue.main.async {
            withAnimation(.spring(response: 0.48, dampingFraction: 0.84)) { self.appShown = true }
        }
    }

    func home() {
        let id = open?.id
        withAnimation(.spring(response: 0.45, dampingFraction: 0.86)) {
            appShown = false
            showRecents = false
            drawer = false
            panel = .none
            dragProg = 0
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
            if !self.appShown && self.open?.id == id { self.open = nil }
        }
    }
}

// MARK: - Entry (UIKit host: hidden home bar, double-swipe exit, all gestures)
extension UIViewController {
    static func installFullScreenHooks() {
        let c = UIViewController.self
        if let m = class_getInstanceMethod(c, #selector(getter: UIViewController.prefersHomeIndicatorAutoHidden)) {
            let blk: @convention(block) (AnyObject) -> Bool = { _ in true }
            method_setImplementation(m, imp_implementationWithBlock(blk))
        }
        if let m = class_getInstanceMethod(c, #selector(getter: UIViewController.preferredScreenEdgesDeferringSystemGestures)) {
            let blk: @convention(block) (AnyObject) -> UInt = { _ in UInt(UIRectEdge.all.rawValue) }
            method_setImplementation(m, imp_implementationWithBlock(blk))
        }
        if let m = class_getInstanceMethod(c, #selector(getter: UIViewController.prefersStatusBarHidden)) {
            let blk: @convention(block) (AnyObject) -> Bool = { _ in true }
            method_setImplementation(m, imp_implementationWithBlock(blk))
        }
    }
}

final class PanHandler: NSObject, UIGestureRecognizerDelegate {
    let os: OS
    var start = CGPoint.zero
    var mode = 0   // 1 left edge, 2 right edge, 3 bottom, 4 top, 5 free

    init(os: OS) { self.os = os }

    func gestureRecognizer(_ g: UIGestureRecognizer,
                           shouldRecognizeSimultaneouslyWith o: UIGestureRecognizer) -> Bool { true }

    @objc func pan(_ g: UIPanGestureRecognizer) {
        guard let v = g.view else { return }
        let w = v.bounds.width
        let h = v.bounds.height
        let t = g.translation(in: v)
        switch g.state {
        case .began:
            let loc = g.location(in: v)
            start = CGPoint(x: loc.x - t.x, y: loc.y - t.y)
            if start.x < 28 { mode = 1 }
            else if start.x > w - 28 { mode = 2 }
            else if start.y > h - 70 { mode = 3 }
            else if start.y < 90 { mode = 4 }
            else { mode = 5 }
        case .changed:
            if mode == 1 {
                os.backLeft = true
                os.backDrag = max(0, t.x)
            } else if mode == 2 {
                os.backLeft = false
                os.backDrag = max(0, -t.x)
            } else if mode == 3 && os.open != nil && os.appShown {
                os.dragProg = min(1, max(0, -t.y) / 300)
            }
        case .ended, .cancelled:
            let vel = g.velocity(in: v)
            withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                os.backDrag = 0
                os.dragProg = 0
            }
            if g.state == .ended { finish(t, vel, w, h) }
        default:
            break
        }
    }

    func finish(_ t: CGPoint, _ vel: CGPoint, _ w: CGFloat, _ h: CGFloat) {
        switch mode {
        case 1:
            if t.x > 70 { os.goBack() }
        case 2:
            if t.x < -70 { os.goBack() }
        case 3:
            if t.y < -150 && abs(vel.y) < 500 {
                withAnimation(.easeOut(duration: 0.25)) { os.showRecents = true }
            } else if t.y < -30 {
                if os.open == nil && !os.drawer && !os.showRecents {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.88)) { os.drawer = true }
                } else {
                    os.home()
                }
            }
        case 4:
            if t.y > 30 {
                if os.panel == .none {
                    withAnimation(.easeOut(duration: 0.25)) { os.panel = start.x < w / 2 ? .notif : .qs }
                } else if os.panel == .notif {
                    withAnimation(.easeOut(duration: 0.25)) { os.panel = .qs }
                }
            } else if t.y < -30 && os.panel != .none {
                os.closePanel()
            }
        default:
            if os.panel != .none {
                if t.y < -40 && (start.y > 380 || t.y < -140) {
                    os.closePanel()
                } else if t.y > 50 && os.panel == .notif && start.y < 260 {
                    withAnimation(.easeOut(duration: 0.25)) { os.panel = .qs }
                }
            } else if os.open == nil && !os.drawer && !os.showRecents {
                if abs(t.y) > abs(t.x) {
                    if t.y > 60 {
                        withAnimation(.easeOut(duration: 0.25)) { os.panel = .notif }
                    } else if t.y < -60 {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.88)) { os.drawer = true }
                    }
                }
            } else if os.drawer && t.y > 80 && start.y < 170 {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.88)) { os.drawer = false }
            }
        }
    }
}

final class HostVC: UIHostingController<AnyView> {
    var handler: PanHandler? = nil

    override var prefersHomeIndicatorAutoHidden: Bool { true }
    override var prefersStatusBarHidden: Bool { true }
    override var preferredScreenEdgesDeferringSystemGestures: UIRectEdge { .all }

    func attach(_ os: OS) {
        let h = PanHandler(os: os)
        handler = h
        let p = UIPanGestureRecognizer(target: h, action: #selector(PanHandler.pan(_:)))
        p.maximumNumberOfTouches = 1
        p.cancelsTouchesInView = false
        p.delaysTouchesBegan = false
        p.delaysTouchesEnded = false
        p.delegate = h
        view.addGestureRecognizer(p)
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        setNeedsUpdateOfHomeIndicatorAutoHidden()
        setNeedsUpdateOfScreenEdgesDeferringSystemGestures()
    }
}

final class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?
    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        guard let ws = scene as? UIWindowScene else { return }
        let os = OS()
        let w = UIWindow(windowScene: ws)
        let vc = HostVC(rootView: AnyView(PhoneView(os: os).preferredColorScheme(.dark)))
        vc.view.backgroundColor = .black
        vc.attach(os)
        w.rootViewController = vc
        w.makeKeyAndVisible()
        window = w
    }
}

@main
final class AppDelegate: UIResponder, UIApplicationDelegate {
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        UITextView.appearance().backgroundColor = .clear
        UIViewController.installFullScreenHooks()
        return true
    }

    func application(_ application: UIApplication,
                     configurationForConnecting connectingSceneSession: UISceneSession,
                     options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        let c = UISceneConfiguration(name: "Default", sessionRole: connectingSceneSession.role)
        c.delegateClass = SceneDelegate.self
        return c
    }
}

// MARK: - Root
struct PhoneView: View {
    @ObservedObject var os: OS

    func anchor() -> UnitPoint {
        let s = UIScreen.main.bounds.size
        guard let o = os.origin, s.width > 0, s.height > 0 else { return .center }
        return UnitPoint(x: o.x / s.width, y: o.y / s.height)
    }

    var body: some View {
        GeometryReader { g in
            ZStack {
                Wallpaper().ignoresSafeArea()
                Home()
                    .scaleEffect(os.appShown ? 0.94 : 1)
                    .opacity(os.appShown ? 0.6 : 1)
                if let a = os.open {
                    AppWindow(app: a)
                        .clipShape(RoundedRectangle(cornerRadius: os.appShown ? 46 * os.dragProg : 220,
                                                    style: .continuous))
                        .scaleEffect(os.appShown ? 1 - 0.25 * os.dragProg : 0.12, anchor: anchor())
                        .opacity(os.appShown ? 1 : 0)
                        .zIndex(1)
                }
                if os.drawer && os.open == nil {
                    Drawer().transition(.move(edge: .bottom)).zIndex(2)
                }
                if os.showRecents {
                    Recents().transition(.opacity).zIndex(3)
                }
                VStack(spacing: 0) {
                    StatusBar()
                    if let b = os.banner {
                        Banner(n: b).transition(.move(edge: .top).combined(with: .opacity))
                    }
                    Spacer()
                }
                .zIndex(4)
                VStack {
                    Spacer()
                    NavZone()
                }
                .zIndex(4)
                if os.backDrag > 4 {
                    HStack {
                        if !os.backLeft { Spacer() }
                        Image(systemName: os.backLeft ? "chevron.left" : "chevron.right")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(T.onAccent)
                            .frame(width: 44, height: 44)
                            .background(Circle().fill(T.accent.opacity(min(1, Double(os.backDrag) / 70))))
                            .offset(x: (os.backLeft ? 1 : -1) * min(os.backDrag, 90) * 0.45)
                        if os.backLeft { Spacer() }
                    }
                    .padding(.horizontal, 6)
                    .allowsHitTesting(false)
                    .zIndex(6)
                }
                if os.panel != .none {
                    Shade()
                        .transition(.move(edge: .top).combined(with: .opacity))
                        .zIndex(5)
                }
            }
            .ignoresSafeArea(.container)
            .onAppear {
                os.top = g.safeAreaInsets.top
                os.bottom = g.safeAreaInsets.bottom
            }
        }
        .environmentObject(os)
    }
}

// MARK: - Wallpaper (cheap gradients, no blur)
struct Wallpaper: View {
    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(red: 0.05, green: 0.08, blue: 0.2),
                                    Color(red: 0.16, green: 0.1, blue: 0.3)],
                           startPoint: .top, endPoint: .bottom)
            RadialGradient(colors: [Color(red: 0.3, green: 0.5, blue: 0.9).opacity(0.55), .clear],
                           center: .topLeading, startRadius: 10, endRadius: 440)
            RadialGradient(colors: [Color(red: 0.85, green: 0.4, blue: 0.7).opacity(0.4), .clear],
                           center: .bottomTrailing, startRadius: 10, endRadius: 500)
        }
    }
}

// MARK: - Status bar (left half = notifications, right half = quick settings)
struct Zone: View {
    let action: () -> Void
    var body: some View {
        Color.clear
            .contentShape(Rectangle())
            .onTapGesture { action() }
    }
}

struct StatusBar: View {
    @EnvironmentObject var os: OS

    func show(_ p: Panel) {
        withAnimation(.easeOut(duration: 0.25)) { os.panel = p }
    }

    var body: some View {
        HStack(spacing: 6) {
            Text(Date(), style: .time).font(.system(size: 14, weight: .semibold))
            ForEach(os.notifs.prefix(3)) { n in
                Image(systemName: iconFor(n.appId)).font(.system(size: 11))
            }
            Spacer()
            if os.dnd { Image(systemName: "moon.fill") }
            if os.airplane {
                Image(systemName: "airplane")
            } else {
                Image(systemName: os.wifi ? "wifi" : "wifi.slash")
                Image(systemName: "antenna.radiowaves.left.and.right")
            }
            Image(systemName: os.saver ? "battery.25" : "battery.100")
        }
        .font(.system(size: 13))
        .foregroundColor(.white)
        .padding(.horizontal, 26)
        .frame(height: max(os.top, 30))
        .overlay(
            HStack(spacing: 0) {
                Zone { show(.notif) }
                Zone { show(.qs) }
            }
        )
    }
}

struct Banner: View {
    @EnvironmentObject var os: OS
    let n: Notif
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: iconFor(n.appId))
                .foregroundColor(tintFor(n.appId))
                .frame(width: 34, height: 34)
                .background(Circle().fill(tintFor(n.appId).opacity(0.2)))
            VStack(alignment: .leading, spacing: 2) {
                Text(n.title).font(.system(size: 14, weight: .semibold))
                Text(n.body).font(.system(size: 13)).opacity(0.8).lineLimit(1)
            }
            Spacer()
        }
        .foregroundColor(.white)
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 28, style: .continuous).fill(T.card))
        .padding(.horizontal, 12)
        .padding(.top, 4)
        .onTapGesture {
            withAnimation { os.banner = nil }
            if let a = appFor(n.appId) { os.launch(a) }
        }
    }
}

// MARK: - Gesture nav pill (swipes are handled by the UIKit pan layer)
struct NavZone: View {
    var body: some View {
        Capsule()
            .fill(Color.white.opacity(0.85))
            .frame(width: 118, height: 5)
            .shadow(color: .black.opacity(0.4), radius: 2)
            .frame(maxWidth: .infinity, minHeight: 36, alignment: .center)
            .allowsHitTesting(false)
    }
}

// MARK: - Home
struct FramePref: PreferenceKey {
    static var defaultValue: CGRect = .zero
    static func reduce(value: inout CGRect, nextValue: () -> CGRect) { value = nextValue() }
}

struct Icon: View {
    @EnvironmentObject var os: OS
    let app: AppInfo
    var label = true
    @State var frame: CGRect = .zero

    var body: some View {
        Button {
            let p: CGPoint? = frame == .zero ? nil : CGPoint(x: frame.midX, y: frame.midY)
            os.launch(app, from: p)
        } label: {
            VStack(spacing: 6) {
                Image(systemName: app.icon)
                    .font(.system(size: 24, weight: .medium))
                    .foregroundColor(app.tint)
                    .frame(width: 58, height: 58)
                    .background(Circle().fill(app.tint.opacity(0.22)))
                if label {
                    Text(app.name)
                        .font(.system(size: 11))
                        .foregroundColor(.white)
                        .lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
        .background(GeometryReader { gp in
            Color.clear.preference(key: FramePref.self, value: gp.frame(in: .global))
        })
        .onPreferenceChange(FramePref.self) { frame = $0 }
    }
}

struct StackClock: View {
    func s(_ f: String) -> String { fmtDate(f) }
    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { _ in
            VStack(alignment: .leading, spacing: -12) {
                Text(s("hh")).foregroundColor(.white)
                Text(s("mm")).foregroundColor(T.accent)
            }
            .font(.system(size: 78, weight: .bold, design: .rounded))
        }
    }
}

struct Home: View {
    @EnvironmentObject var os: OS
    @State var q = ""
    @FocusState var focus: Bool
    let cols = Array(repeating: GridItem(.flexible(), spacing: 8), count: 4)

    func openDrawer() {
        withAnimation(.spring(response: 0.35, dampingFraction: 0.88)) { os.drawer = true }
    }

    func search() {
        let t = q.trimmingCharacters(in: .whitespacesAndNewlines)
        if t.isEmpty { return }
        os.browser.go(t)
        q = ""
        focus = false
        if let w = appFor("web") { os.launch(w) }
    }

    var body: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 4) {
                StackClock()
                Text(fmtDate("EEEE, MMM d"))
                    .font(.system(size: 17, weight: .medium))
                    .foregroundColor(.white)
                Text("build 5")
                    .font(.system(size: 11))
                    .foregroundColor(.white.opacity(0.35))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 28)
            Spacer(minLength: 8)
            LazyVGrid(columns: cols, spacing: 18) {
                ForEach(homeApps) { a in Icon(app: a) }
            }
            .padding(.horizontal, 12)
            Spacer(minLength: 8)
            HStack {
                ForEach(dockApps) { a in Icon(app: a, label: false) }
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 14)
            HStack(spacing: 12) {
                Text("G").font(.system(size: 20, weight: .bold)).foregroundColor(T.accent)
                TextField("Search", text: $q)
                    .focused($focus)
                    .foregroundColor(.white)
                    .textInputAutocapitalization(.never)
                    .disableAutocorrection(true)
                    .keyboardType(.webSearch)
                    .submitLabel(.search)
                    .onSubmit { search() }
                Image(systemName: "mic.fill").foregroundColor(.white.opacity(0.8))
                Image(systemName: "camera.viewfinder").foregroundColor(.white.opacity(0.8))
            }
            .padding(.horizontal, 20)
            .frame(height: 52)
            .background(Capsule().fill(T.card.opacity(0.95)))
            .padding(.horizontal, 16)
            Spacer().frame(height: 50)
        }
        .padding(.top, os.padTop)
        .contentShape(Rectangle())
    }
}

// MARK: - App drawer
struct Drawer: View {
    @EnvironmentObject var os: OS
    @State var q = ""
    let cols = Array(repeating: GridItem(.flexible(), spacing: 8), count: 4)

    var list: [AppInfo] {
        if q.isEmpty { return sortedApps }
        return sortedApps.filter { $0.name.lowercased().contains(q.lowercased()) }
    }

    var body: some View {
        VStack(spacing: 12) {
            Capsule().fill(Color.white.opacity(0.3))
                .frame(width: 40, height: 5)
                .frame(maxWidth: .infinity, minHeight: 28)
                .contentShape(Rectangle())
                .gesture(DragGesture().onEnded { v in
                    if v.translation.height > 40 {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.88)) { os.drawer = false }
                    }
                })
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass").foregroundColor(.white.opacity(0.7))
                TextField("Search apps", text: $q)
                    .foregroundColor(.white)
                    .disableAutocorrection(true)
                    .submitLabel(.search)
                    .onSubmit {
                        let t = q.trimmingCharacters(in: .whitespacesAndNewlines)
                        if let f = list.first {
                            os.launch(f)
                        } else if !t.isEmpty {
                            os.browser.go(t)
                            if let w = appFor("web") { os.launch(w) }
                        }
                    }
            }
            .padding(.horizontal, 18)
            .frame(height: 52)
            .background(Capsule().fill(T.card))
            .padding(.horizontal, 16)
            ScrollView {
                LazyVGrid(columns: cols, spacing: 22) {
                    ForEach(list) { a in Icon(app: a) }
                }
                .padding(.horizontal, 12)
                .padding(.top, 12)
            }
        }
        .padding(.top, os.padTop - 24)
        .padding(.bottom, 40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(T.bg.opacity(0.97).ignoresSafeArea())
    }
}

// MARK: - Recents (swipe a card up to dismiss)
struct RecentCard: View {
    @EnvironmentObject var os: OS
    let app: AppInfo
    @State var dy: CGFloat = 0

    var body: some View {
        Button { os.launch(app) } label: {
            VStack(spacing: 14) {
                Image(systemName: app.icon).font(.system(size: 54)).foregroundColor(app.tint)
                Text(app.name).foregroundColor(.white)
            }
            .frame(width: 210, height: 380)
            .background(RoundedRectangle(cornerRadius: 32, style: .continuous).fill(T.card))
        }
        .buttonStyle(.plain)
        .offset(y: dy)
        .opacity(1 - Double(abs(dy)) / 400)
        .gesture(
            DragGesture()
                .onChanged { v in dy = min(0, v.translation.height) }
                .onEnded { v in
                    if v.translation.height < -90 {
                        withAnimation { os.recents.removeAll { $0.id == app.id } }
                    } else {
                        withAnimation { dy = 0 }
                    }
                }
        )
    }
}

struct Recents: View {
    @EnvironmentObject var os: OS
    var body: some View {
        ZStack {
            Color.black.opacity(0.55).ignoresSafeArea().onTapGesture { os.home() }
            if os.recents.isEmpty {
                Text("No recent items").foregroundColor(.white.opacity(0.75))
            } else {
                VStack(spacing: 22) {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 16) {
                            ForEach(os.recents) { a in RecentCard(app: a) }
                        }
                        .padding(.horizontal, 40)
                    }
                    .frame(height: 400)
                    Button {
                        withAnimation { os.recents = [] }
                    } label: {
                        Text("Clear all")
                            .foregroundColor(T.onAccent)
                            .padding(.horizontal, 24).padding(.vertical, 12)
                            .background(Capsule().fill(T.accent))
                    }
                }
            }
        }
    }
}

// MARK: - Notification shade + quick settings (Android 16 split panels)
struct BigTile: View {
    let icon: String
    let title: String
    @Binding var on: Bool
    var body: some View {
        Button { on.toggle() } label: {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .medium))
                    .frame(width: 38, height: 38)
                    .background(Circle().fill(on ? T.onAccent.opacity(0.18) : Color.white.opacity(0.08)))
                VStack(alignment: .leading, spacing: 1) {
                    Text(title).font(.system(size: 14, weight: .semibold)).lineLimit(1)
                    Text(on ? "On" : "Off").font(.system(size: 12)).opacity(0.75)
                }
                Spacer()
            }
            .padding(.horizontal, 12)
            .frame(height: 68)
            .foregroundColor(on ? T.onAccent : .white)
            .background(RoundedRectangle(cornerRadius: 34, style: .continuous).fill(on ? T.accent : T.card))
        }
        .buttonStyle(.plain)
    }
}

struct SmallTile: View {
    let icon: String
    @Binding var on: Bool
    var body: some View {
        Button { on.toggle() } label: {
            Image(systemName: icon)
                .font(.system(size: 20))
                .frame(width: 64, height: 64)
                .foregroundColor(on ? T.onAccent : .white)
                .background(Circle().fill(on ? T.accent : T.card))
        }
        .buttonStyle(.plain)
    }
}

struct BrightBar: View {
    @Binding var v: Double
    var body: some View {
        GeometryReader { g in
            ZStack(alignment: .leading) {
                Capsule().fill(T.card)
                Capsule().fill(T.accent)
                    .frame(width: max(56, g.size.width * CGFloat(v)))
                Image(systemName: "sun.max.fill")
                    .foregroundColor(T.onAccent)
                    .padding(.leading, 20)
            }
            .contentShape(Capsule())
            .gesture(DragGesture(minimumDistance: 0).onChanged { val in
                v = min(1, max(0.05, Double(val.location.x / g.size.width)))
            })
        }
        .frame(height: 56)
    }
}

struct NotifCard: View {
    @EnvironmentObject var os: OS
    let n: Notif
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: iconFor(n.appId))
                .foregroundColor(tintFor(n.appId))
                .frame(width: 36, height: 36)
                .background(Circle().fill(tintFor(n.appId).opacity(0.2)))
            VStack(alignment: .leading, spacing: 2) {
                Text("\(appFor(n.appId)?.name ?? "System") · \(n.date, style: .relative)")
                    .font(.system(size: 12)).opacity(0.65)
                Text(n.title).font(.system(size: 15, weight: .semibold))
                Text(n.body).font(.system(size: 14)).opacity(0.85)
            }
            Spacer()
            Button {
                withAnimation { os.notifs.removeAll { $0.id == n.id } }
            } label: {
                Image(systemName: "xmark").font(.system(size: 13)).opacity(0.6).padding(6)
            }
        }
        .foregroundColor(.white)
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 26, style: .continuous).fill(T.card))
        .onTapGesture {
            if let a = appFor(n.appId) { os.launch(a) }
        }
    }
}

struct NotifPanel: View {
    @EnvironmentObject var os: OS
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(Date(), style: .time).font(.system(size: 38, weight: .light))
                    Text(fmtDate("EEEE, MMM d")).font(.system(size: 15)).opacity(0.85)
                }
                Spacer()
                Button {
                    withAnimation { os.panel = .qs }
                } label: {
                    Image(systemName: "slider.horizontal.3")
                        .foregroundColor(T.onAccent)
                        .frame(width: 48, height: 48)
                        .background(Circle().fill(T.accent))
                }
            }
            if os.notifs.isEmpty {
                Text("No notifications")
                    .opacity(0.6)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 40)
            } else {
                ScrollView {
                    VStack(spacing: 8) {
                        ForEach(os.notifs) { n in NotifCard(n: n) }
                    }
                }
                .frame(maxHeight: 440)
                Button {
                    withAnimation { os.notifs = [] }
                } label: {
                    Text("Clear all")
                        .foregroundColor(T.onAccent)
                        .padding(.horizontal, 22).padding(.vertical, 10)
                        .background(Capsule().fill(T.accent))
                }
                .frame(maxWidth: .infinity)
            }
        }
    }
}

struct QSPanel: View {
    @EnvironmentObject var os: OS
    let cols = [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)]
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(Date(), style: .time).font(.system(size: 38, weight: .light))
                    Text(fmtDate("EEEE, MMM d")).font(.system(size: 15)).opacity(0.85)
                }
                Spacer()
                Button {
                    withAnimation { os.panel = .notif }
                } label: {
                    Image(systemName: os.notifs.isEmpty ? "bell" : "bell.badge.fill")
                        .foregroundColor(T.onAccent)
                        .frame(width: 48, height: 48)
                        .background(Circle().fill(T.accent))
                }
            }
            LazyVGrid(columns: cols, spacing: 10) {
                BigTile(icon: "wifi", title: "Internet", on: $os.wifi)
                BigTile(icon: "dot.radiowaves.left.and.right", title: "Bluetooth", on: $os.bt)
                BigTile(icon: "flashlight.on.fill", title: "Flashlight", on: $os.flash)
                BigTile(icon: "moon.fill", title: "Do Not Disturb", on: $os.dnd)
            }
            HStack(spacing: 0) {
                SmallTile(icon: "airplane", on: $os.airplane)
                Spacer()
                SmallTile(icon: "battery.25", on: $os.saver)
                Spacer()
                SmallTile(icon: "screenrotation", on: $os.rotate)
                Spacer()
                Button {
                    os.post("settings", "Test notification", "Notifications work!")
                } label: {
                    Image(systemName: "bell.fill")
                        .font(.system(size: 20))
                        .frame(width: 64, height: 64)
                        .foregroundColor(.white)
                        .background(Circle().fill(T.card))
                }
            }
            BrightBar(v: $os.brightness)
        }
    }
}

struct Shade: View {
    @EnvironmentObject var os: OS
    var body: some View {
        ZStack(alignment: .top) {
            Color.black.opacity(0.55).ignoresSafeArea().onTapGesture { os.closePanel() }
            VStack(spacing: 14) {
                if os.panel == .notif { NotifPanel() } else { QSPanel() }
            }
            .foregroundColor(.white)
            .padding(.horizontal, 16)
            .padding(.top, os.padTop - 12)
            .padding(.bottom, 20)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 36, style: .continuous)
                    .fill(T.bg)
                    .ignoresSafeArea(edges: .top)
            )
        }
    }
}

// MARK: - App window (full screen)
struct AppWindow: View {
    @EnvironmentObject var os: OS
    let app: AppInfo

    var body: some View {
        content
            .padding(.top, app.id == "cam" ? 0 : os.padTop - 8)
            .padding(.bottom, app.id == "cam" ? 0 : 34)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(T.bg.ignoresSafeArea())
    }

    @ViewBuilder var content: some View {
        switch app.id {
        case "calc": CalcView()
        case "clock": ClockApp()
        case "cal": CalendarApp()
        case "notes": NotesApp()
        case "settings": SettingsApp()
        case "phone": DialerApp()
        case "web": BrowserApp()
        case "msg": MessagesApp()
        case "cam": CameraApp()
        case "photos": PhotosApp()
        default: EmptyView()
        }
    }
}

struct Title: View {
    let text: String
    var body: some View {
        Text(text)
            .font(.system(size: 30, weight: .regular))
            .foregroundColor(.white)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 22)
            .padding(.vertical, 10)
    }
}

// MARK: - Calculator
struct CalcView: View {
    @State var disp = "0"
    @State var acc: Double? = nil
    @State var op: String? = nil
    @State var fresh = true
    let rows: [[String]] = [
        ["C", "±", "%", "÷"],
        ["7", "8", "9", "×"],
        ["4", "5", "6", "−"],
        ["1", "2", "3", "+"],
        ["0", ".", "⌫", "="]
    ]

    func fmt(_ d: Double) -> String {
        if d == d.rounded() && abs(d) < 1e12 { return String(Int(d)) }
        return String(d)
    }

    func commit() {
        guard let v = Double(disp) else { return }
        if let a = acc, let o = op {
            var r = v
            switch o {
            case "+": r = a + v
            case "−": r = a - v
            case "×": r = a * v
            default: r = v == 0 ? 0 : a / v
            }
            acc = r
            disp = fmt(r)
        } else {
            acc = v
        }
    }

    func tap(_ k: String) {
        switch k {
        case "C": disp = "0"; acc = nil; op = nil; fresh = true
        case "±": if let v = Double(disp) { disp = fmt(-v) }
        case "%": if let v = Double(disp) { disp = fmt(v / 100) }
        case "+", "−", "×", "÷": commit(); op = k; fresh = true
        case "=": commit(); op = nil; fresh = true
        case ".":
            if fresh { disp = "0."; fresh = false }
            else if !disp.contains(".") { disp += "." }
        case "⌫":
            disp = String(disp.dropLast())
            if disp.isEmpty || disp == "-" { disp = "0"; fresh = true }
        default:
            if fresh { disp = k; fresh = false }
            else { disp = disp == "0" ? k : disp + k }
        }
    }

    func isOp(_ k: String) -> Bool { ["÷", "×", "−", "+", "="].contains(k) }

    var body: some View {
        VStack(spacing: 10) {
            Spacer()
            Text(disp)
                .font(.system(size: 68, weight: .light))
                .minimumScaleFactor(0.4)
                .lineLimit(1)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity, alignment: .trailing)
                .padding(.horizontal, 24)
            ForEach(rows, id: \.self) { row in
                HStack(spacing: 10) {
                    ForEach(row, id: \.self) { k in
                        Button { tap(k) } label: {
                            Text(k)
                                .font(.system(size: 26))
                                .frame(maxWidth: .infinity, minHeight: 66)
                                .foregroundColor(isOp(k) ? T.onAccent : .white)
                                .background(RoundedRectangle(cornerRadius: 33, style: .continuous)
                                    .fill(isOp(k) ? T.accent : T.card))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 14)
            }
        }
    }
}

// MARK: - Clock (clock / timer / stopwatch)
struct ClockApp: View {
    @State var tab = 0
    let names = ["Clock", "Timer", "Stopwatch"]

    var body: some View {
        VStack(spacing: 16) {
            Title(text: "Clock")
            HStack(spacing: 8) {
                ForEach(0..<3) { i in
                    Button { tab = i } label: {
                        Text(names[i])
                            .font(.system(size: 14, weight: .medium))
                            .padding(.horizontal, 16).padding(.vertical, 9)
                            .foregroundColor(tab == i ? T.onAccent : .white)
                            .background(Capsule().fill(tab == i ? T.accent : T.card))
                    }
                }
            }
            if tab == 0 {
                VStack(spacing: 8) {
                    Text(Date(), style: .time).font(.system(size: 64, weight: .light)).foregroundColor(.white)
                    Text(TimeZone.current.identifier).foregroundColor(.white.opacity(0.6))
                }
                .padding(.top, 30)
            } else if tab == 1 {
                TimerView()
            } else {
                StopwatchView()
            }
            Spacer()
        }
    }
}

struct TimerView: View {
    @EnvironmentObject var os: OS
    @State var minutes = 1
    @State var remaining = 0
    @State var running = false
    let tick = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    func fmt(_ s: Int) -> String { String(format: "%02d:%02d", s / 60, s % 60) }

    var body: some View {
        VStack(spacing: 22) {
            Text(fmt(remaining > 0 ? remaining : minutes * 60))
                .font(.system(size: 72, weight: .light).monospacedDigit())
                .foregroundColor(.white)
            if !running && remaining == 0 {
                HStack(spacing: 20) {
                    Button { minutes = max(1, minutes - 1) } label: {
                        Image(systemName: "minus").foregroundColor(.white)
                            .frame(width: 48, height: 48).background(Circle().fill(T.card))
                    }
                    Text("\(minutes) min").foregroundColor(.white)
                    Button { minutes = min(180, minutes + 1) } label: {
                        Image(systemName: "plus").foregroundColor(.white)
                            .frame(width: 48, height: 48).background(Circle().fill(T.card))
                    }
                }
            }
            HStack(spacing: 14) {
                Button {
                    if remaining == 0 { remaining = minutes * 60 }
                    running.toggle()
                } label: {
                    Text(running ? "Pause" : (remaining > 0 ? "Resume" : "Start"))
                        .foregroundColor(T.onAccent)
                        .frame(width: 110, height: 52)
                        .background(Capsule().fill(T.accent))
                }
                if remaining > 0 {
                    Button { running = false; remaining = 0 } label: {
                        Text("Reset").foregroundColor(.white)
                            .frame(width: 110, height: 52)
                            .background(Capsule().fill(T.card))
                    }
                }
            }
        }
        .padding(.top, 24)
        .onReceive(tick) { _ in
            guard running else { return }
            remaining -= 1
            if remaining <= 0 {
                running = false
                remaining = 0
                os.post("clock", "Timer", "Time's up!")
                UINotificationFeedbackGenerator().notificationOccurred(.success)
            }
        }
    }
}

struct StopwatchView: View {
    @State var running = false
    @State var base: TimeInterval = 0
    @State var started: Date? = nil

    func fmt(_ t: TimeInterval) -> String {
        let m = Int(t) / 60
        let s = Int(t) % 60
        let c = Int((t - floor(t)) * 100)
        return String(format: "%02d:%02d.%02d", m, s, c)
    }

    var body: some View {
        VStack(spacing: 24) {
            TimelineView(.periodic(from: .now, by: 0.05)) { ctx in
                let el = base + (started.map { ctx.date.timeIntervalSince($0) } ?? 0)
                Text(fmt(el))
                    .font(.system(size: 56, weight: .light).monospacedDigit())
                    .foregroundColor(T.accent)
            }
            HStack(spacing: 14) {
                Button {
                    if running {
                        if let s = started { base += Date().timeIntervalSince(s) }
                        started = nil
                    } else {
                        started = Date()
                    }
                    running.toggle()
                } label: {
                    Text(running ? "Pause" : "Start")
                        .foregroundColor(T.onAccent)
                        .frame(width: 110, height: 52)
                        .background(Capsule().fill(T.accent))
                }
                Button {
                    running = false; started = nil; base = 0
                } label: {
                    Text("Reset").foregroundColor(.white)
                        .frame(width: 110, height: 52)
                        .background(Capsule().fill(T.card))
                }
            }
        }
        .padding(.top, 30)
    }
}

// MARK: - Calendar (months + events)
struct CalendarApp: View {
    @EnvironmentObject var os: OS
    @State var monthOffset = 0
    @State var selected = Date()
    @State var newEvent = ""
    let cal = Calendar.current
    let cols = Array(repeating: GridItem(.flexible()), count: 7)

    func key(_ d: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: d)
    }

    var monthDate: Date { cal.date(byAdding: .month, value: monthOffset, to: Date()) ?? Date() }

    var body: some View {
        let first = cal.date(from: cal.dateComponents([.year, .month], from: monthDate)) ?? monthDate
        let days = cal.range(of: .day, in: .month, for: first)?.count ?? 30
        let off = cal.component(.weekday, from: first) - 1
        let letters = ["S", "M", "T", "W", "T", "F", "S"]
        VStack(spacing: 10) {
            HStack {
                Text({ () -> String in
                    let f = DateFormatter()
                    f.dateFormat = "MMMM yyyy"
                    return f.string(from: monthDate)
                }())
                    .font(.system(size: 26)).foregroundColor(.white)
                Spacer()
                Button { monthOffset -= 1 } label: {
                    Image(systemName: "chevron.left").foregroundColor(.white).frame(width: 40, height: 40)
                }
                Button { monthOffset += 1 } label: {
                    Image(systemName: "chevron.right").foregroundColor(.white).frame(width: 40, height: 40)
                }
            }
            .padding(.horizontal, 22)
            HStack {
                ForEach(0..<7) { i in
                    Text(letters[i])
                        .font(.system(size: 13))
                        .foregroundColor(.white.opacity(0.6))
                        .frame(maxWidth: .infinity)
                }
            }
            .padding(.horizontal, 12)
            LazyVGrid(columns: cols, spacing: 6) {
                ForEach(0..<(off + days), id: \.self) { i in
                    if i < off {
                        Color.clear.frame(height: 42)
                    } else {
                        let date = cal.date(byAdding: .day, value: i - off, to: first) ?? first
                        let isToday = cal.isDateInToday(date)
                        let isSel = cal.isDate(date, inSameDayAs: selected)
                        Button { selected = date } label: {
                            VStack(spacing: 2) {
                                Text("\(i - off + 1)")
                                    .foregroundColor(isToday ? T.onAccent : .white)
                                Circle()
                                    .fill((os.events[key(date)]?.isEmpty ?? true) ? Color.clear : (isToday ? T.onAccent : T.accent))
                                    .frame(width: 4, height: 4)
                            }
                            .frame(width: 42, height: 42)
                            .background(Circle().fill(isToday ? T.accent : Color.clear))
                            .overlay(Circle().stroke(isSel && !isToday ? T.accent : Color.clear, lineWidth: 1.5))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(.horizontal, 12)
            Divider().background(Color.white.opacity(0.2))
            VStack(alignment: .leading, spacing: 8) {
                Text({ () -> String in
                    let f = DateFormatter()
                    f.dateFormat = "EEEE, MMM d"
                    return f.string(from: selected)
                }())
                    .font(.system(size: 16, weight: .medium)).foregroundColor(.white)
                ScrollView {
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(Array((os.events[key(selected)] ?? []).enumerated()), id: \.offset) { pair in
                            Text(pair.element)
                                .foregroundColor(T.onAccent)
                                .padding(.horizontal, 14).padding(.vertical, 8)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(T.accent))
                        }
                    }
                }
                HStack {
                    TextField("Add event", text: $newEvent)
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .frame(height: 46)
                        .background(Capsule().fill(T.card))
                    Button {
                        let t = newEvent.trimmingCharacters(in: .whitespaces)
                        if !t.isEmpty {
                            os.events[key(selected), default: []].append(t)
                            newEvent = ""
                        }
                    } label: {
                        Image(systemName: "plus").foregroundColor(T.onAccent)
                            .frame(width: 46, height: 46).background(Circle().fill(T.accent))
                    }
                }
            }
            .padding(.horizontal, 20)
        }
    }
}

// MARK: - Notes
struct NotesApp: View {
    @AppStorage("androidlite_note") private var note = ""
    var body: some View {
        VStack(spacing: 0) {
            Title(text: "Keep Notes")
            TextEditor(text: $note)
                .foregroundColor(.white)
                .padding(14)
                .background(RoundedRectangle(cornerRadius: 28, style: .continuous).fill(T.card))
                .padding(.horizontal, 16)
                .padding(.bottom, 8)
        }
    }
}

// MARK: - Settings
struct SettingsApp: View {
    @EnvironmentObject var os: OS

    func row(_ icon: String, _ title: String, _ on: Binding<Bool>) -> some View {
        Toggle(isOn: on) {
            HStack(spacing: 14) {
                Image(systemName: icon).foregroundColor(T.accent).frame(width: 26)
                Text(title).foregroundColor(.white)
            }
        }
        .toggleStyle(SwitchToggleStyle(tint: T.accent))
        .padding(.horizontal, 18)
        .frame(height: 58)
    }

    var body: some View {
        VStack(spacing: 0) {
            Title(text: "Settings")
            ScrollView {
                VStack(spacing: 2) {
                    row("wifi", "Network & internet", $os.wifi)
                    row("dot.radiowaves.left.and.right", "Bluetooth", $os.bt)
                    row("airplane", "Airplane mode", $os.airplane)
                    row("moon.fill", "Do Not Disturb", $os.dnd)
                    row("battery.25", "Battery Saver", $os.saver)
                    row("screenrotation", "Auto-rotate", $os.rotate)
                    BrightBar(v: $os.brightness).padding(.horizontal, 14).padding(.vertical, 8)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("About phone").foregroundColor(.white)
                        Text("Android Lite · Android 16 style · Build 5")
                            .font(.system(size: 13)).foregroundColor(.white.opacity(0.6))
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(18)
                }
                .background(RoundedRectangle(cornerRadius: 28, style: .continuous).fill(T.card))
                .padding(.horizontal, 16)
            }
        }
    }
}

// MARK: - Phone (real calls through iOS)
struct DialerApp: View {
    @State var num = ""
    let keys = ["1", "2", "3", "4", "5", "6", "7", "8", "9", "*", "0", "#"]
    let cols = Array(repeating: GridItem(.flexible()), count: 3)

    func call() {
        let digits = num.filter { "0123456789+".contains($0) }
        if digits.isEmpty { return }
        if let u = URL(string: "tel://" + digits) { UIApplication.shared.open(u) }
    }

    var body: some View {
        VStack(spacing: 18) {
            Spacer()
            Text(num.isEmpty ? " " : num)
                .font(.system(size: 36, weight: .light))
                .foregroundColor(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
            LazyVGrid(columns: cols, spacing: 14) {
                ForEach(keys, id: \.self) { k in
                    Button { num += k } label: {
                        Text(k)
                            .font(.system(size: 28))
                            .foregroundColor(.white)
                            .frame(width: 72, height: 72)
                            .background(Circle().fill(T.card))
                    }
                }
            }
            .padding(.horizontal, 30)
            HStack(spacing: 40) {
                Button { call() } label: {
                    Image(systemName: "phone.fill")
                        .foregroundColor(.white)
                        .frame(width: 72, height: 72)
                        .background(Circle().fill(Color.green))
                }
                Button { if !num.isEmpty { num.removeLast() } } label: {
                    Image(systemName: "delete.left.fill")
                        .foregroundColor(.white.opacity(0.8))
                        .frame(width: 72, height: 72)
                }
            }
            Spacer().frame(height: 10)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Messages (local chats, replies arrive as notifications)
struct MessagesApp: View {
    @EnvironmentObject var os: OS
    @State var chat: Contact? = nil

    var body: some View {
        inner.onAppear {
            os.backHandlers["msg"] = {
                if chat != nil { chat = nil; return true }
                return false
            }
        }
    }

    @ViewBuilder var inner: some View {
        if let c = chat {
            ChatView(contact: c) { chat = nil }
        } else {
            VStack(spacing: 0) {
                Title(text: "Messages")
                ScrollView {
                    ForEach(contacts) { c in
                        Button { chat = c } label: {
                            HStack(spacing: 14) {
                                Text(String(c.name.prefix(1)))
                                    .font(.system(size: 20, weight: .semibold))
                                    .foregroundColor(T.bg)
                                    .frame(width: 48, height: 48)
                                    .background(Circle().fill(c.color))
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(c.name).font(.system(size: 16, weight: .semibold)).foregroundColor(.white)
                                    Text(os.threads[c.id]?.last?.text ?? "")
                                        .font(.system(size: 14)).foregroundColor(.white.opacity(0.65)).lineLimit(1)
                                }
                                Spacer()
                            }
                            .padding(.horizontal, 20)
                            .padding(.vertical, 10)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }
}

struct ChatView: View {
    @EnvironmentObject var os: OS
    let contact: Contact
    let back: () -> Void
    @State var text = ""

    var msgs: [Msg] { os.threads[contact.id] ?? [] }

    func send() {
        let t = text.trimmingCharacters(in: .whitespaces)
        if t.isEmpty { return }
        os.threads[contact.id, default: []].append(Msg(text: t, mine: true))
        text = ""
        let cid = contact.id
        let name = contact.name
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) {
            let r = canned.randomElement() ?? "ok"
            os.threads[cid, default: []].append(Msg(text: r, mine: false))
            let watching = os.open?.id == "msg" && os.viewingChat == cid
            if !watching { os.post("msg", name, r) }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Button { back() } label: {
                    Image(systemName: "chevron.left").foregroundColor(.white).frame(width: 40, height: 40)
                }
                Text(String(contact.name.prefix(1)))
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(T.bg)
                    .frame(width: 36, height: 36)
                    .background(Circle().fill(contact.color))
                Text(contact.name).font(.system(size: 20)).foregroundColor(.white)
                Spacer()
            }
            .padding(.horizontal, 12)
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(spacing: 6) {
                        ForEach(msgs) { m in
                            HStack {
                                if m.mine { Spacer(minLength: 60) }
                                Text(m.text)
                                    .padding(.horizontal, 14).padding(.vertical, 10)
                                    .foregroundColor(m.mine ? T.onAccent : .white)
                                    .background(RoundedRectangle(cornerRadius: 22, style: .continuous)
                                        .fill(m.mine ? T.accent : T.card))
                                if !m.mine { Spacer(minLength: 60) }
                            }
                            .id(m.id)
                        }
                    }
                    .padding(.horizontal, 14)
                    .padding(.top, 10)
                }
                .onChange(of: msgs.count) { _ in
                    if let last = msgs.last { proxy.scrollTo(last.id, anchor: .bottom) }
                }
            }
            HStack(spacing: 10) {
                TextField("Message", text: $text)
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .frame(height: 48)
                    .background(Capsule().fill(T.card))
                    .submitLabel(.send)
                    .onSubmit { send() }
                Button { send() } label: {
                    Image(systemName: "arrow.up")
                        .foregroundColor(T.onAccent)
                        .frame(width: 48, height: 48)
                        .background(Circle().fill(T.accent))
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
        .onAppear { os.viewingChat = contact.id }
        .onDisappear { os.viewingChat = nil }
    }
}

// MARK: - Gallery storage (shared by Camera + Photos)
enum Gallery {
    static var dir: URL {
        let base = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let u = base.appendingPathComponent("Camera", isDirectory: true)
        try? FileManager.default.createDirectory(at: u, withIntermediateDirectories: true)
        return u
    }

    static func save(_ data: Data) {
        let name = "IMG_\(Int(Date().timeIntervalSince1970 * 1000)).jpg"
        try? data.write(to: dir.appendingPathComponent(name))
    }

    static func list() -> [URL] {
        let all = (try? FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil)) ?? []
        return all.filter { $0.pathExtension == "jpg" }.sorted { $0.lastPathComponent > $1.lastPathComponent }
    }

    static func thumb(_ url: URL, max: CGFloat) -> UIImage? {
        guard let src = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }
        let opts: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: max
        ]
        guard let cg = CGImageSourceCreateThumbnailAtIndex(src, 0, opts as CFDictionary) else { return nil }
        return UIImage(cgImage: cg)
    }
}

// MARK: - Camera (real AVFoundation)
final class CamModel: NSObject, ObservableObject, AVCapturePhotoCaptureDelegate {
    let session = AVCaptureSession()
    let output = AVCapturePhotoOutput()
    @Published var authorized = false
    @Published var back = true
    @Published var flashOn = false
    @Published var last: UIImage? = nil
    private var configured = false

    func start() {
        AVCaptureDevice.requestAccess(for: .video) { ok in
            DispatchQueue.main.async { self.authorized = ok }
            guard ok else { return }
            DispatchQueue.global(qos: .userInitiated).async {
                self.configure()
                if !self.session.isRunning { self.session.startRunning() }
            }
        }
        if let u = Gallery.list().first {
            DispatchQueue.global().async {
                let t = Gallery.thumb(u, max: 200)
                DispatchQueue.main.async { self.last = t }
            }
        }
    }

    private func configure() {
        if configured { return }
        session.beginConfiguration()
        session.sessionPreset = .photo
        if let dev = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
           let inp = try? AVCaptureDeviceInput(device: dev), session.canAddInput(inp) {
            session.addInput(inp)
        }
        if session.canAddOutput(output) { session.addOutput(output) }
        session.commitConfiguration()
        configured = true
    }

    func stop() {
        DispatchQueue.global().async {
            if self.session.isRunning { self.session.stopRunning() }
        }
    }

    func flip() {
        back.toggle()
        let pos: AVCaptureDevice.Position = back ? .back : .front
        DispatchQueue.global().async {
            self.session.beginConfiguration()
            for i in self.session.inputs { self.session.removeInput(i) }
            if let dev = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: pos),
               let inp = try? AVCaptureDeviceInput(device: dev), self.session.canAddInput(inp) {
                self.session.addInput(inp)
            }
            self.session.commitConfiguration()
        }
    }

    func shoot() {
        let s = AVCapturePhotoSettings()
        if flashOn && back && output.supportedFlashModes.contains(.on) { s.flashMode = .on }
        output.capturePhoto(with: s, delegate: self)
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }

    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        guard let data = photo.fileDataRepresentation(), let img = UIImage(data: data) else { return }
        Gallery.save(data)
        UIImageWriteToSavedPhotosAlbum(img, nil, nil, nil)
        DispatchQueue.main.async { self.last = img }
    }
}

final class PreviewView: UIView {
    override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
    var pl: AVCaptureVideoPreviewLayer { layer as! AVCaptureVideoPreviewLayer }
}

struct CamPreview: UIViewRepresentable {
    let session: AVCaptureSession
    func makeUIView(context: Context) -> PreviewView {
        let v = PreviewView()
        v.pl.session = session
        v.pl.videoGravity = .resizeAspectFill
        return v
    }
    func updateUIView(_ v: PreviewView, context: Context) {}
}

struct CameraApp: View {
    @EnvironmentObject var os: OS
    @StateObject var cam = CamModel()

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            VStack(spacing: 0) {
                HStack {
                    Button { cam.flashOn.toggle() } label: {
                        Image(systemName: cam.flashOn ? "bolt.fill" : "bolt.slash.fill")
                            .foregroundColor(cam.flashOn ? T.accent : .white)
                            .frame(width: 44, height: 44)
                    }
                    Spacer()
                    Text("Photo")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(T.onAccent)
                        .padding(.horizontal, 16).padding(.vertical, 7)
                        .background(Capsule().fill(T.accent))
                    Spacer()
                    Color.clear.frame(width: 44, height: 44)
                }
                .padding(.horizontal, 20)
                .padding(.top, os.padTop - 8)
                ZStack {
                    Color(white: 0.1)
                    if cam.authorized {
                        CamPreview(session: cam.session)
                    } else {
                        Text("Allow camera access in iOS Settings")
                            .foregroundColor(.white.opacity(0.7))
                            .multilineTextAlignment(.center)
                            .padding()
                    }
                }
                .aspectRatio(3.0 / 4.0, contentMode: .fit)
                .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
                .padding(.horizontal, 10)
                .padding(.top, 8)
                Spacer()
                HStack {
                    Button {
                        if let p = appFor("photos") { os.launch(p) }
                    } label: {
                        if let img = cam.last {
                            Image(uiImage: img).resizable().scaledToFill()
                                .frame(width: 54, height: 54).clipShape(Circle())
                        } else {
                            Circle().fill(T.card).frame(width: 54, height: 54)
                        }
                    }
                    Spacer()
                    Button { cam.shoot() } label: {
                        Circle().fill(Color.white).frame(width: 66, height: 66)
                            .padding(5)
                            .overlay(Circle().stroke(Color.white, lineWidth: 3))
                    }
                    Spacer()
                    Button { cam.flip() } label: {
                        Image(systemName: "arrow.triangle.2.circlepath.camera.fill")
                            .foregroundColor(.white)
                            .frame(width: 54, height: 54)
                            .background(Circle().fill(T.card))
                    }
                }
                .padding(.horizontal, 36)
                .padding(.bottom, 46)
            }
        }
        .onAppear { cam.start() }
        .onDisappear { cam.stop() }
    }
}

// MARK: - Photos
struct Thumb: View {
    let url: URL
    let maxSize: CGFloat
    var fill = true
    @State var img: UIImage? = nil

    var body: some View {
        Group {
            if let i = img {
                if fill {
                    Image(uiImage: i).resizable().scaledToFill()
                } else {
                    Image(uiImage: i).resizable().scaledToFit()
                }
            } else {
                T.card
            }
        }
        .onAppear {
            DispatchQueue.global().async {
                let t = Gallery.thumb(url, max: maxSize)
                DispatchQueue.main.async { img = t }
            }
        }
    }
}

struct PhotosApp: View {
    @EnvironmentObject var os: OS
    @State var files: [URL] = []
    @State var sel: URL? = nil
    let cols = Array(repeating: GridItem(.flexible(), spacing: 3), count: 3)

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                Title(text: "Photos")
                if files.isEmpty {
                    Spacer()
                    Text("No photos yet. Take one with the Camera.")
                        .foregroundColor(.white.opacity(0.6))
                    Spacer()
                } else {
                    ScrollView {
                        LazyVGrid(columns: cols, spacing: 3) {
                            ForEach(files, id: \.self) { u in
                                Button { sel = u } label: {
                                    Color.clear
                                        .aspectRatio(1, contentMode: .fit)
                                        .overlay(Thumb(url: u, maxSize: 300))
                                        .clipped()
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
            }
            if let s = sel {
                ZStack(alignment: .top) {
                    Color.black.ignoresSafeArea()
                    Thumb(url: s, maxSize: 1600, fill: false)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    HStack {
                        Button { sel = nil } label: {
                            Image(systemName: "chevron.left").foregroundColor(.white)
                                .frame(width: 44, height: 44)
                        }
                        Spacer()
                        Button {
                            try? FileManager.default.removeItem(at: s)
                            sel = nil
                            files = Gallery.list()
                        } label: {
                            Image(systemName: "trash").foregroundColor(.white)
                                .frame(width: 44, height: 44)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                }
            }
        }
        .onAppear {
            files = Gallery.list()
            os.backHandlers["photos"] = {
                if sel != nil { sel = nil; return true }
                return false
            }
        }
    }
}

// MARK: - Chrome (real browser on WKWebView)
final class WebModel: ObservableObject {
    let web: WKWebView
    @Published var url = ""
    @Published var progress = 0.0
    @Published var canBack = false
    @Published var canFwd = false
    @Published var loading = false
    private var obs: [NSKeyValueObservation] = []
    static let home = "https://www.google.com"

    init() {
        let cfg = WKWebViewConfiguration()
        cfg.allowsInlineMediaPlayback = true
        web = WKWebView(frame: .zero, configuration: cfg)
        web.allowsBackForwardNavigationGestures = false
        obs = [
            web.observe(\.estimatedProgress) { [weak self] w, _ in
                DispatchQueue.main.async { self?.progress = w.estimatedProgress }
            },
            web.observe(\.url) { [weak self] w, _ in
                DispatchQueue.main.async { self?.url = w.url?.absoluteString ?? "" }
            },
            web.observe(\.canGoBack) { [weak self] w, _ in
                DispatchQueue.main.async { self?.canBack = w.canGoBack }
            },
            web.observe(\.canGoForward) { [weak self] w, _ in
                DispatchQueue.main.async { self?.canFwd = w.canGoForward }
            },
            web.observe(\.isLoading) { [weak self] w, _ in
                DispatchQueue.main.async { self?.loading = w.isLoading }
            }
        ]
        go(WebModel.home)
    }

    func go(_ text: String) {
        var t = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if t.isEmpty { return }
        var target: URL?
        if t.contains(" ") || !t.contains(".") {
            let q = t.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? t
            target = URL(string: "https://www.google.com/search?q=" + q)
        } else {
            if !t.hasPrefix("http://") && !t.hasPrefix("https://") { t = "https://" + t }
            target = URL(string: t)
        }
        if let u = target { web.load(URLRequest(url: u)) }
    }
}

struct WebHost: UIViewRepresentable {
    let web: WKWebView
    func makeUIView(context: Context) -> WKWebView { web }
    func updateUIView(_ v: WKWebView, context: Context) {}
}

struct BrowserApp: View {
    @EnvironmentObject var os: OS
    var body: some View {
        BrowserBody(m: os.browser).onAppear {
            let m = os.browser
            os.backHandlers["web"] = {
                if m.canBack { m.web.goBack(); return true }
                return false
            }
        }
    }
}

struct BrowserBody: View {
    @ObservedObject var m: WebModel
    @State var text = ""
    @FocusState var focused: Bool

    func bar(_ icon: String, _ on: Bool, _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 19))
                .foregroundColor(on ? .white : .white.opacity(0.3))
                .frame(maxWidth: .infinity, minHeight: 44)
        }
        .disabled(!on)
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                Image(systemName: m.url.hasPrefix("https") ? "lock.fill" : "globe")
                    .font(.system(size: 13))
                    .foregroundColor(.white.opacity(0.7))
                TextField("Search or type URL", text: $text)
                    .focused($focused)
                    .textInputAutocapitalization(.never)
                    .disableAutocorrection(true)
                    .keyboardType(.webSearch)
                    .submitLabel(.go)
                    .foregroundColor(.white)
                    .onSubmit { m.go(text); focused = false }
                Button {
                    if m.loading { m.web.stopLoading() } else { m.web.reload() }
                } label: {
                    Image(systemName: m.loading ? "xmark" : "arrow.clockwise")
                        .foregroundColor(.white.opacity(0.8))
                }
            }
            .padding(.horizontal, 16)
            .frame(height: 46)
            .background(Capsule().fill(T.card))
            .padding(.horizontal, 12)
            .padding(.vertical, 6)

            ZStack(alignment: .top) {
                WebHost(web: m.web)
                if m.loading {
                    GeometryReader { g in
                        Rectangle().fill(T.accent)
                            .frame(width: g.size.width * CGFloat(m.progress), height: 3)
                    }
                    .frame(height: 3)
                }
            }

            HStack {
                bar("chevron.left", m.canBack) { m.web.goBack() }
                bar("chevron.right", m.canFwd) { m.web.goForward() }
                bar("house", true) { m.go(WebModel.home) }
                bar("square.and.arrow.up", !m.url.isEmpty) { share() }
            }
            .background(T.bg)
        }
        .onReceive(m.$url) { u in if !focused { text = u } }
        .onAppear { text = m.url }
    }

    func share() {
        guard let u = URL(string: m.url) else { return }
        let vc = UIActivityViewController(activityItems: [u], applicationActivities: nil)
        UIApplication.shared.connectedScenes
            .compactMap { ($0 as? UIWindowScene)?.keyWindow?.rootViewController }
            .first?.present(vc, animated: true)
    }
}
