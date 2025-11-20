import Cocoa
import Foundation
import SystemConfiguration
import Darwin

// MARK: - Localization Manager
// Manages application strings and language selection
enum Language: String, CaseIterable {
    case system = "system"
    case english = "en"
    case chineseSimplified = "zh-Hans"
    case chineseTraditional = "zh-Hant"
    case japanese = "ja"
    
    var displayName: String {
        switch self {
        case .system: return "System Default (系统默认)"
        case .english: return "English"
        case .chineseSimplified: return "简体中文"
        case .chineseTraditional: return "繁體中文"
        case .japanese: return "日本語"
        }
    }
}

class LocalizationManager {
    static let shared = LocalizationManager()
    
    var currentLanguage: Language = .system
    
    // Dictionary holding translations
    private let strings: [String: [String: String]] = [
        "AppName": [
            "en": "NetSpeedMonitor Pro",
            "zh-Hans": "网速监控 Pro",
            "zh-Hant": "網速監控 Pro",
            "ja": "ネット速度モニター Pro"
        ],
        "UpdateInterval": [
            "en": "Update Interval",
            "zh-Hans": "刷新频率",
            "zh-Hant": "刷新頻率",
            "ja": "更新間隔"
        ],
        "Language": [
            "en": "Language",
            "zh-Hans": "语言",
            "zh-Hant": "語言",
            "ja": "言語"
        ],
        "OpenActivityMonitor": [
            "en": "Open Activity Monitor",
            "zh-Hans": "打开活动监视器",
            "zh-Hant": "打開活動監視器",
            "ja": "アクティビティモニタを開く"
        ],
        "Quit": [
            "en": "Quit",
            "zh-Hans": "退出",
            "zh-Hant": "退出",
            "ja": "終了"
        ]
    ]
    
    // Resolve the effective language code (handling System Default)
    private var effectiveLanguageCode: String {
        if currentLanguage == .system {
            // Detect system language
            let lang = Locale.preferredLanguages.first ?? "en"
            if lang.hasPrefix("zh-Hans") { return "zh-Hans" }
            if lang.hasPrefix("zh-Hant") { return "zh-Hant" }
            if lang.hasPrefix("ja") { return "ja" }
            return "en"
        }
        return currentLanguage.rawValue
    }
    
    func localized(_ key: String) -> String {
        let langCode = effectiveLanguageCode
        return strings[key]?[langCode] ?? strings[key]?["en"] ?? key
    }
}

// MARK: - 1. Global Network Monitor (Kernel-level Sysctl)
// Uses sysctl NET_RT_IFLIST2 for extremely low CPU usage (~0.1%)
class NetworkMonitor {
    private var lastUploadBytes: UInt64 = 0
    private var lastDownloadBytes: UInt64 = 0
    private var lastCheckTime: TimeInterval = 0
    
    // MIB array for sysctl
    private var mib: [Int32] = [CTL_NET, PF_ROUTE, 0, 0, NET_RT_IFLIST2, 0]
    private var buffer: UnsafeMutablePointer<Int8>
    private var bufferSize: Int
    
    init() {
        // Pre-allocate 32KB buffer to avoid frequent malloc calls
        bufferSize = 32 * 1024
        buffer = UnsafeMutablePointer<Int8>.allocate(capacity: bufferSize)
    }
    
    deinit {
        buffer.deallocate()
    }
    
    func getNetworkSpeeds() -> (upload: String, download: String) {
        var len = bufferSize
        // System call: Fetch network interface list directly from kernel memory
        if sysctl(&mib, u_int(mib.count), buffer, &len, nil, 0) != 0 {
            if errno == ENOMEM {
                // Buffer too small, double the size and retry
                buffer.deallocate()
                bufferSize *= 2
                buffer = UnsafeMutablePointer<Int8>.allocate(capacity: bufferSize)
                return getNetworkSpeeds()
            }
            return ("0 KB/s", "0 KB/s")
        }
        
        var currentUploadBytes: UInt64 = 0
        var currentDownloadBytes: UInt64 = 0
        var ptr = buffer
        let end = buffer + len
        
        while ptr < end {
            let msg = ptr.withMemoryRebound(to: if_msghdr.self, capacity: 1) { $0.pointee }
            if msg.ifm_msglen == 0 { break }
            
            // RTM_IFINFO2 contains 64-bit counters
            if msg.ifm_type == RTM_IFINFO2 {
                let msg2 = ptr.withMemoryRebound(to: if_msghdr2.self, capacity: 1) { $0.pointee }
                let flags = msg2.ifm_flags
                
                // Filter: Must be UP (Active) AND NOT LOOPBACK (Ignore localhost/127.0.0.1)
                if (flags & Int32(IFF_UP)) != 0 && (flags & Int32(IFF_LOOPBACK)) == 0 {
                    let data = msg2.ifm_data
                    currentDownloadBytes += data.ifi_ibytes
                    currentUploadBytes += data.ifi_obytes
                }
            }
            ptr = ptr.advanced(by: Int(msg.ifm_msglen))
        }
        
        let currentTime = Date().timeIntervalSince1970
        var uploadSpeedStr = "0 KB/s"
        var downloadSpeedStr = "0 KB/s"
        
        if lastCheckTime != 0 {
            let timeDelta = currentTime - lastCheckTime
            // Avoid division by zero or extremely small deltas
            if timeDelta > 0.1 {
                let uploadDiff = currentUploadBytes > lastUploadBytes ? currentUploadBytes - lastUploadBytes : 0
                let downloadDiff = currentDownloadBytes > lastDownloadBytes ? currentDownloadBytes - lastDownloadBytes : 0
                
                uploadSpeedStr = FormatUtils.bytesToString(UInt64(Double(uploadDiff) / timeDelta))
                downloadSpeedStr = FormatUtils.bytesToString(UInt64(Double(downloadDiff) / timeDelta))
                
                lastUploadBytes = currentUploadBytes
                lastDownloadBytes = currentDownloadBytes
                lastCheckTime = currentTime
            }
        } else {
            lastUploadBytes = currentUploadBytes
            lastDownloadBytes = currentDownloadBytes
            lastCheckTime = currentTime
        }
        
        return (uploadSpeedStr, downloadSpeedStr)
    }
}

// MARK: - 2. Utilities
struct FormatUtils {
    static func bytesToString(_ bytes: UInt64) -> String {
        let speed = Double(bytes)
        if speed < 1024 {
            return "0 KB/s"
        } else if speed < 1024 * 1024 {
            return String(format: "%.0f KB/s", speed / 1024)
        } else {
            return String(format: "%.1f MB/s", speed / (1024 * 1024))
        }
    }
}

// MARK: - 3. High Performance Drawing View
// Uses Core Graphics to draw text directly, bypassing NSTextField overhead
class SpeedView: NSView {
    private var uploadText = "↑ 0 KB/s"
    private var downloadText = "↓ 0 KB/s"
    private let paragraphStyle: NSMutableParagraphStyle
    private let font = NSFont.monospacedDigitSystemFont(ofSize: 9, weight: .semibold)
    
    override init(frame: NSRect) {
        paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = .right
        paragraphStyle.lineBreakMode = .byTruncatingTail
        super.init(frame: frame)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func update(upload: String, download: String) {
        let newUpload = "↑ \(upload)"
        let newDownload = "↓ \(download)"
        
        // Only redraw if content changed
        if uploadText != newUpload || downloadText != newDownload {
            uploadText = newUpload
            downloadText = newDownload
            self.needsDisplay = true
        }
    }
    
    override func draw(_ dirtyRect: NSRect) {
        let attrs: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: NSColor.labelColor, // Adapts to Light/Dark mode automatically
            .paragraphStyle: paragraphStyle
        ]
        
        let w = bounds.width
        let h = bounds.height
        let halfH = h / 2
        
        // Hardcoded layout for pixel-perfect rendering
        let uploadRect = NSRect(x: -4, y: halfH - 1.5, width: w, height: halfH + 2)
        let downloadRect = NSRect(x: -4, y: -1.5, width: w, height: halfH + 2)
        
        (uploadText as NSString).draw(in: uploadRect, withAttributes: attrs)
        (downloadText as NSString).draw(in: downloadRect, withAttributes: attrs)
    }
}

// MARK: - 4. App Delegate & Menu Logic
class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem!
    let monitor = NetworkMonitor()
    var speedView: SpeedView!
    var timer: DispatchSourceTimer?
    
    let itemWidth: CGFloat = 72
    var currentInterval: TimeInterval = 2.0
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        // 1. Load Update Interval
        if let savedInterval = UserDefaults.standard.value(forKey: "UpdateInterval") as? Double {
            currentInterval = savedInterval
        }
        
        // 2. Load Language Setting
        if let savedLangString = UserDefaults.standard.string(forKey: "Language"),
           let savedLang = Language(rawValue: savedLangString) {
            LocalizationManager.shared.currentLanguage = savedLang
        }
        
        // Setup Status Item
        statusItem = NSStatusBar.system.statusItem(withLength: itemWidth)
        
        if let button = statusItem.button {
            button.title = ""
            button.image = nil
            
            let frame = NSRect(x: 0, y: 0, width: itemWidth, height: 22)
            speedView = SpeedView(frame: frame)
            // Disable autoresizing to prevent system compression
            speedView.autoresizingMask = [] 
            button.addSubview(speedView)
        }
        
        setupMenu()
        startMonitoring()
    }
    
    // Rebuilds the menu based on current localization
    func setupMenu() {
        let menu = NSMenu()
        let loc = LocalizationManager.shared
        
        // 1. App Title (Disabled)
        let titleItem = NSMenuItem(title: loc.localized("AppName"), action: nil, keyEquivalent: "")
        titleItem.isEnabled = false
        menu.addItem(titleItem)
        menu.addItem(NSMenuItem.separator())
        
        // 2. Update Interval Section Header
        let intervalHeader = NSMenuItem(title: loc.localized("UpdateInterval"), action: nil, keyEquivalent: "")
        intervalHeader.isEnabled = false
        menu.addItem(intervalHeader)
        
        // 3. Interval Options (Flat list)
        let intervals: [TimeInterval] = [1, 2, 5, 10, 30]
        for interval in intervals {
            let title = "\(Int(interval))s"
            let item = NSMenuItem(title: title, action: #selector(changeInterval(_:)), keyEquivalent: "")
            item.tag = Int(interval)
            item.target = self
            menu.addItem(item)
        }
        
        menu.addItem(NSMenuItem.separator())
        
        // 4. Language Section
        let langHeader = NSMenuItem(title: loc.localized("Language"), action: nil, keyEquivalent: "")
        langHeader.isEnabled = false
        menu.addItem(langHeader)
        
        // Language Options
        for lang in Language.allCases {
            let item = NSMenuItem(title: lang.displayName, action: #selector(changeLanguage(_:)), keyEquivalent: "")
            // We use a simple mapping to identify languages, as tag is integer only
            item.representedObject = lang.rawValue
            item.target = self
            menu.addItem(item)
        }
        
        menu.addItem(NSMenuItem.separator())
        
        // 5. Tools
        let activityItem = NSMenuItem(title: loc.localized("OpenActivityMonitor"), action: #selector(openActivityMonitor), keyEquivalent: "")
        activityItem.target = self
        menu.addItem(activityItem)
        
        menu.addItem(NSMenuItem.separator())
        
        // 6. Quit
        let quitItem = NSMenuItem(title: loc.localized("Quit"), action: #selector(quitApp), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)
        
        statusItem.menu = menu
        
        // Update checkboxes
        updateMenuState()
    }
    
    // Updates the visual state (checkmarks) of menu items
    func updateMenuState() {
        guard let menu = statusItem.menu else { return }
        for item in menu.items {
            // Update Interval Checks
            if item.action == #selector(changeInterval(_:)) {
                item.state = (Double(item.tag) == currentInterval) ? .on : .off
            }
            // Language Checks
            if item.action == #selector(changeLanguage(_:)) {
                if let rawVal = item.representedObject as? String,
                   rawVal == LocalizationManager.shared.currentLanguage.rawValue {
                    item.state = .on
                } else {
                    item.state = .off
                }
            }
        }
    }
    
    @objc func changeInterval(_ sender: NSMenuItem) {
        let newInterval = TimeInterval(sender.tag)
        if newInterval == currentInterval { return }
        
        currentInterval = newInterval
        UserDefaults.standard.set(currentInterval, forKey: "UpdateInterval")
        
        updateMenuState()
        startMonitoring()
    }
    
    @objc func changeLanguage(_ sender: NSMenuItem) {
        guard let rawVal = sender.representedObject as? String,
              let newLang = Language(rawValue: rawVal) else { return }
        
        if newLang == LocalizationManager.shared.currentLanguage { return }
        
        // Save and update
        LocalizationManager.shared.currentLanguage = newLang
        UserDefaults.standard.set(rawVal, forKey: "Language")
        
        // Rebuild the entire menu to reflect new language
        setupMenu()
    }
    
    @objc func openActivityMonitor() {
        if let url = URL(string: "file:///System/Applications/Utilities/Activity%20Monitor.app") {
            NSWorkspace.shared.open(url)
        }
    }
    
    func startMonitoring() {
        timer?.cancel()
        timer = nil
        
        let queue = DispatchQueue.global(qos: .utility)
        timer = DispatchSource.makeTimerSource(queue: queue)
        
        timer?.schedule(deadline: .now(), repeating: currentInterval, leeway: .milliseconds(100))
        
        timer?.setEventHandler { [weak self] in
            guard let self = self else { return }
            let speeds = self.monitor.getNetworkSpeeds()
            DispatchQueue.main.async {
                self.speedView.update(upload: speeds.upload, download: speeds.download)
            }
        }
        timer?.resume()
    }
    
    @objc func quitApp() {
        NSApplication.shared.terminate(nil)
    }
}

// MARK: - Entry Point
let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()