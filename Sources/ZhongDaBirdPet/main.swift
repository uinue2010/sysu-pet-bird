import AppKit
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers

struct PetAsset: Equatable {
    let sourceURL: URL
    let displayURL: URL
    let name: String
    let typeIdentifier: String
}

final class AssetScanner {
    private let fileManager = FileManager.default
    private let sourceDirectories: [URL]
    private let normalizedDirectory: URL

    init(sourceDirectories: [URL]) {
        self.sourceDirectories = sourceDirectories
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        self.normalizedDirectory = appSupport.appendingPathComponent("ZhongDaBirdPet/Normalized", isDirectory: true)
    }

    func scan() -> [PetAsset] {
        var assets: [PetAsset] = []
        for directory in sourceDirectories where fileManager.fileExists(atPath: directory.path) {
            guard let enumerator = fileManager.enumerator(
                at: directory,
                includingPropertiesForKeys: [.isRegularFileKey, .contentModificationDateKey, .fileSizeKey],
                options: [.skipsHiddenFiles]
            ) else {
                continue
            }

            for case let url as URL in enumerator {
                guard isRegularFile(url) else { continue }
                guard let detected = detectImageType(url) else { continue }
                guard let displayURL = normalizedURLIfNeeded(for: url, typeIdentifier: detected) else { continue }
                assets.append(PetAsset(
                    sourceURL: url,
                    displayURL: displayURL,
                    name: url.deletingPathExtension().lastPathComponent,
                    typeIdentifier: detected
                ))
            }
        }

        return assets.sorted {
            $0.name.localizedStandardCompare($1.name) == .orderedAscending
        }
    }

    private func isRegularFile(_ url: URL) -> Bool {
        (try? url.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile) == true
    }

    private func detectImageType(_ url: URL) -> String? {
        guard let data = try? Data(contentsOf: url, options: [.mappedIfSafe]),
              let source = CGImageSourceCreateWithData(data as CFData, nil),
              let type = CGImageSourceGetType(source) as String? else {
            return nil
        }

        if UTType(type)?.conforms(to: .image) == true {
            return type
        }
        return nil
    }

    private func normalizedURLIfNeeded(for url: URL, typeIdentifier: String) -> URL? {
        guard let preferredExtension = UTType(typeIdentifier)?.preferredFilenameExtension else {
            return url
        }

        let currentExtension = url.pathExtension.lowercased()
        if currentExtension == preferredExtension.lowercased() {
            return url
        }

        do {
            try fileManager.createDirectory(at: normalizedDirectory, withIntermediateDirectories: true)
            let stableName = "\(url.deletingPathExtension().lastPathComponent)-\(fnv1a64(url.path)).\(preferredExtension)"
            let targetURL = normalizedDirectory.appendingPathComponent(stableName)
            if fileManager.fileExists(atPath: targetURL.path) {
                try fileManager.removeItem(at: targetURL)
            }
            try fileManager.copyItem(at: url, to: targetURL)
            return targetURL
        } catch {
            NSLog("ZhongDaBirdPet: failed to normalize \(url.path): \(error)")
            return nil
        }
    }

    private func fnv1a64(_ string: String) -> String {
        var hash: UInt64 = 0xcbf29ce484222325
        for byte in string.utf8 {
            hash ^= UInt64(byte)
            hash &*= 0x100000001b3
        }
        return String(hash, radix: 16)
    }
}

@MainActor
final class PetWindowController {
    private let baseSide: CGFloat = 96
    private let window: NSWindow
    private let imageView: NSImageView
    private var lastDragLocation: NSPoint?
    var contextMenuProvider: (() -> NSMenu?)?

    private(set) var currentAsset: PetAsset?
    private var scale: CGFloat = 1.0

    init() {
        let size = NSSize(width: baseSide, height: baseSide)
        window = NSWindow(
            contentRect: NSRect(origin: .zero, size: size),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        imageView = NSImageView(frame: NSRect(origin: .zero, size: size))
        superInitWindow(size: size)
    }

    private func superInitWindow(size: NSSize) {
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = false
        window.level = .floating
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        window.ignoresMouseEvents = false
        window.isMovableByWindowBackground = true

        imageView.imageScaling = .scaleProportionallyUpOrDown
        imageView.animates = true
        imageView.wantsLayer = true
        imageView.layer?.backgroundColor = NSColor.clear.cgColor

        let dragView = DragView(frame: NSRect(origin: .zero, size: size))
        dragView.autoresizingMask = [.width, .height]
        dragView.onDrag = { [weak self] event in
            self?.drag(with: event)
        }
        dragView.menuProvider = { [weak self] in
            self?.contextMenuProvider?()
        }
        dragView.addSubview(imageView)
        imageView.autoresizingMask = [.width, .height]
        window.contentView = dragView

        if let screenFrame = NSScreen.main?.visibleFrame {
            let origin = NSPoint(
                x: screenFrame.maxX - size.width - 64,
                y: screenFrame.minY + 96
            )
            window.setFrameOrigin(origin)
        }
        window.orderFrontRegardless()
    }

    func show(asset: PetAsset) {
        guard currentAsset != asset else { return }
        currentAsset = asset

        if let image = NSImage(contentsOf: asset.displayURL) {
            imageView.image = image
            imageView.animates = true
        } else {
            NSLog("ZhongDaBirdPet: failed to load image \(asset.displayURL.path)")
        }
    }

    func setScale(_ newScale: CGFloat) {
        scale = newScale
        let side = max(64, min(220, baseSide * scale))
        var frame = window.frame
        frame.size = NSSize(width: side, height: side)
        window.setFrame(frame, display: true, animate: true)
    }

    func setOpacity(_ opacity: CGFloat) {
        window.alphaValue = max(0.25, min(1.0, opacity))
    }

    func setAlwaysOnTop(_ enabled: Bool) {
        window.level = enabled ? .floating : .normal
    }

    private func drag(with event: NSEvent) {
        switch event.type {
        case .leftMouseDown:
            lastDragLocation = NSEvent.mouseLocation
        case .leftMouseDragged:
            let currentLocation = NSEvent.mouseLocation
            guard let previous = lastDragLocation else {
                lastDragLocation = currentLocation
                return
            }
            let delta = NSPoint(x: currentLocation.x - previous.x, y: currentLocation.y - previous.y)
            var frame = window.frame
            frame.origin.x += delta.x
            frame.origin.y += delta.y
            window.setFrameOrigin(frame.origin)
            lastDragLocation = currentLocation
        case .leftMouseUp:
            lastDragLocation = nil
        default:
            break
        }
    }
}

final class DragView: NSView {
    var onDrag: ((NSEvent) -> Void)?
    var menuProvider: (() -> NSMenu?)?

    override func mouseDown(with event: NSEvent) {
        onDrag?(event)
    }

    override func mouseDragged(with event: NSEvent) {
        onDrag?(event)
    }

    override func mouseUp(with event: NSEvent) {
        onDrag?(event)
    }

    override func rightMouseDown(with event: NSEvent) {
        guard let menu = menuProvider?() else { return }
        NSMenu.popUpContextMenu(menu, with: event, for: self)
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let assetDirectory = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent("Documents/中大鸟", isDirectory: true)
    private lazy var scanner = AssetScanner(sourceDirectories: [
        assetDirectory,
        bundledAssetDirectory()
    ])
    private let petWindow = PetWindowController()
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private var assets: [PetAsset] = []
    private var autoSwitchEnabled = true
    private var alwaysOnTop = true
    private var lastRuleKey: String?
    private var ruleTimer: Timer?
    private var lastRandomSwitchAt = Date.distantPast
    private var randomQueue: [PetAsset] = []

    private func bundledAssetDirectory() -> URL {
        if let resourceURL = Bundle.main.resourceURL {
            return resourceURL.appendingPathComponent("ZhongDaBird", isDirectory: true)
        }
        return URL(fileURLWithPath: "")
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        configureStatusItem()
        petWindow.contextMenuProvider = { [weak self] in
            self?.buildMenu()
        }
        rescanAssets()
        rebuildMenu()

        ruleTimer = Timer.scheduledTimer(withTimeInterval: 15, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.applyAutomaticRule()
            }
        }
        applyAutomaticRule()
    }

    func applicationWillTerminate(_ notification: Notification) {
        ruleTimer?.invalidate()
    }

    private func configureStatusItem() {
        statusItem.length = NSStatusItem.squareLength
        statusItem.button?.toolTip = "中大鸟桌宠"
        if let image = NSImage(systemSymbolName: "face.smiling", accessibilityDescription: "中大鸟桌宠") {
            image.isTemplate = true
            statusItem.button?.image = image
        } else {
            statusItem.button?.title = "鸟"
        }
    }

    private func rescanAssets() {
        assets = scanner.scan()
        randomQueue.removeAll()
        if let current = petWindow.currentAsset,
           assets.contains(where: { $0.displayURL == current.displayURL }) {
            return
        }

        if let firstAsset = pickAsset(preferredNames: ["hi", "在吗", "休息一下"]) ?? assets.first {
            petWindow.show(asset: firstAsset)
        }
    }

    private func rebuildMenu() {
        statusItem.menu = buildMenu()
    }

    private func buildMenu() -> NSMenu {
        let menu = NSMenu()
        let visibleAssets = deduplicatedAssets()

        let currentName = petWindow.currentAsset?.name ?? "未加载"
        let currentItem = NSMenuItem(title: "当前：\(currentName)", action: nil, keyEquivalent: "")
        currentItem.isEnabled = false
        menu.addItem(currentItem)

        let expressionMenu = NSMenu()
        for asset in visibleAssets {
            let item = NSMenuItem(title: asset.name, action: #selector(selectExpression(_:)), keyEquivalent: "")
            item.representedObject = asset.displayURL.path
            item.target = self
            expressionMenu.addItem(item)
        }
        let expressionItem = NSMenuItem(title: "切换表情", action: nil, keyEquivalent: "")
        expressionItem.submenu = expressionMenu
        menu.addItem(expressionItem)

        menu.addItem(.separator())

        let autoTitle = autoSwitchEnabled ? "暂停自动切换" : "恢复自动切换"
        menu.addItem(menuItem(autoTitle, action: #selector(toggleAutoSwitch)))
        menu.addItem(menuItem("重新扫描素材", action: #selector(rescanFromMenu)))

        let scaleMenu = NSMenu()
        for (title, value) in [("小", 0.75), ("标准", 1.0), ("大", 1.25), ("特大", 1.55)] {
            let item = NSMenuItem(title: title, action: #selector(setScaleFromMenu(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = value
            scaleMenu.addItem(item)
        }
        let scaleItem = NSMenuItem(title: "大小", action: nil, keyEquivalent: "")
        scaleItem.submenu = scaleMenu
        menu.addItem(scaleItem)

        let opacityMenu = NSMenu()
        for (title, value) in [("40%", 0.4), ("70%", 0.7), ("100%", 1.0)] {
            let item = NSMenuItem(title: title, action: #selector(setOpacityFromMenu(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = value
            opacityMenu.addItem(item)
        }
        let opacityItem = NSMenuItem(title: "透明度", action: nil, keyEquivalent: "")
        opacityItem.submenu = opacityMenu
        menu.addItem(opacityItem)

        let topItem = menuItem(alwaysOnTop ? "取消置顶" : "置顶显示", action: #selector(toggleAlwaysOnTop))
        menu.addItem(topItem)

        menu.addItem(.separator())
        menu.addItem(menuItem("退出", action: #selector(quit)))

        return menu
    }

    private func deduplicatedAssets() -> [PetAsset] {
        var chosenByName: [String: PetAsset] = [:]
        for asset in assets {
            let key = normalizedDisplayName(asset.name)
            guard let current = chosenByName[key] else {
                chosenByName[key] = asset
                continue
            }
            if assetRank(asset) < assetRank(current) {
                chosenByName[key] = asset
            }
        }

        return chosenByName.values.sorted {
            $0.name.localizedStandardCompare($1.name) == .orderedAscending
        }
    }

    private func normalizedDisplayName(_ name: String) -> String {
        name
            .replacingOccurrences(of: "_png序列", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func assetRank(_ asset: PetAsset) -> Int {
        if asset.typeIdentifier == UTType.gif.identifier { return 0 }
        if asset.typeIdentifier == UTType.png.identifier { return 1 }
        if asset.typeIdentifier == UTType.webP.identifier { return 2 }
        return 3
    }

    private func menuItem(_ title: String, action: Selector) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: "")
        item.target = self
        return item
    }

    @objc private func selectExpression(_ sender: NSMenuItem) {
        guard let path = sender.representedObject as? String,
              let asset = assets.first(where: { $0.displayURL.path == path }) else {
            return
        }
        lastRuleKey = nil
        randomQueue.removeAll { $0.displayURL == asset.displayURL }
        petWindow.show(asset: asset)
        rebuildMenu()
    }

    @objc private func toggleAutoSwitch() {
        autoSwitchEnabled.toggle()
        rebuildMenu()
    }

    @objc private func rescanFromMenu() {
        rescanAssets()
        rebuildMenu()
        applyAutomaticRule(forceRefresh: true)
    }

    @objc private func setScaleFromMenu(_ sender: NSMenuItem) {
        if let value = sender.representedObject as? Double {
            petWindow.setScale(CGFloat(value))
        }
    }

    @objc private func setOpacityFromMenu(_ sender: NSMenuItem) {
        if let value = sender.representedObject as? Double {
            petWindow.setOpacity(CGFloat(value))
        }
    }

    @objc private func toggleAlwaysOnTop() {
        alwaysOnTop.toggle()
        petWindow.setAlwaysOnTop(alwaysOnTop)
        rebuildMenu()
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }

    private func applyAutomaticRule(forceRefresh: Bool = false) {
        guard autoSwitchEnabled, !assets.isEmpty else { return }

        let now = Date()
        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: now)
        let minute = calendar.component(.minute, from: now)
        let minutesAfterMidnight = hour * 60 + minute

        if minutesAfterMidnight >= 21 * 60 + 30 {
            showFixedMood(ruleKey: "night", preferredNames: ["晚安"], forceRefresh: forceRefresh)
        } else if (11 * 60 + 30...12 * 60 + 30).contains(minutesAfterMidnight)
            || (17 * 60...18 * 60).contains(minutesAfterMidnight) {
            showFixedMood(ruleKey: "hungry", preferredNames: ["饿了"], forceRefresh: forceRefresh)
        } else if forceRefresh || now.timeIntervalSince(lastRandomSwitchAt) >= 120, let asset = randomAsset() {
            lastRuleKey = "random"
            lastRandomSwitchAt = now
            petWindow.show(asset: asset)
            rebuildMenu()
        }
    }

    private func showFixedMood(ruleKey: String, preferredNames: [String], forceRefresh: Bool) {
        guard forceRefresh || ruleKey != lastRuleKey else { return }
        if let asset = pickAsset(preferredNames: preferredNames) ?? randomAsset() {
            lastRuleKey = ruleKey
            petWindow.show(asset: asset)
            rebuildMenu()
        }
    }

    private func randomAsset() -> PetAsset? {
        let specialNames = ["晚安", "饿了"]
        let candidates = deduplicatedAssets().filter { asset in
            !specialNames.contains { specialName in
                normalizedDisplayName(asset.name).localizedCaseInsensitiveContains(specialName)
            }
        }
        let pool = candidates.isEmpty ? deduplicatedAssets() : candidates
        guard !pool.isEmpty else { return nil }

        let currentURL = petWindow.currentAsset?.displayURL
        let poolURLs = Set(pool.map(\.displayURL))
        randomQueue.removeAll { !poolURLs.contains($0.displayURL) }

        if randomQueue.isEmpty {
            randomQueue = pool.shuffled()
        }

        if randomQueue.first?.displayURL == currentURL, randomQueue.count > 1 {
            randomQueue.append(randomQueue.removeFirst())
        }

        return randomQueue.removeFirst()
    }

    private func pickAsset(preferredNames: [String]) -> PetAsset? {
        for preferredName in preferredNames {
            if let exact = assets.first(where: { $0.name == preferredName }) {
                return exact
            }
            if let fuzzy = assets.first(where: { $0.name.localizedCaseInsensitiveContains(preferredName) }) {
                return fuzzy
            }
        }
        return nil
    }

}

@main
@MainActor
struct ZhongDaBirdPetApp {
    private static var delegate: AppDelegate?

    static func main() {
        let app = NSApplication.shared
        let appDelegate = AppDelegate()
        delegate = appDelegate
        app.delegate = appDelegate
        app.run()
    }
}
