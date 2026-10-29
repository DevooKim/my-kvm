import AppKit
import IOKit.pwr_mgt

/// 메뉴바 아이콘 하나로 동작한다. 우클릭은 자동 전환 켜기/끄기, 좌클릭은 메뉴.
/// KVM이 Mac으로 오면(KVM 뒤의 Shanling UA2가 붙으면) 설정에 따라 Mac 화면을 깨우고 279M1RV 입력을 HDMI 1로 바꾼다.
/// Windows로 갈 때는 건드리지 않는다 — Windows가 꺼져 있으면 DP에 신호가 없어 모니터가 입력 탐색(깜박임)을 시작한다.
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private static let enabledKey = "autoSwitchEnabled"
    private static let wakeMacKey = "wakeMac"
    private static let switchInputKey = "switchInput"

    private var statusItem: NSStatusItem!
    private let watcher = USBWatcher(vendor: 0x20B1, product: 0x303F)  // Shanling UA2
    private let ddcQueue = DispatchQueue(label: "io.devookim.MyKVM.ddc")
    private var lastResult = "아직 없음"

    private var isEnabled: Bool {
        get { UserDefaults.standard.object(forKey: Self.enabledKey) as? Bool ?? true }
        set {
            UserDefaults.standard.set(newValue, forKey: Self.enabledKey)
            updateIcon()
        }
    }

    private var wakesMac: Bool {
        get { UserDefaults.standard.object(forKey: Self.wakeMacKey) as? Bool ?? true }
        set { UserDefaults.standard.set(newValue, forKey: Self.wakeMacKey) }
    }

    private var switchesInput: Bool {
        get { UserDefaults.standard.object(forKey: Self.switchInputKey) as? Bool ?? true }
        set { UserDefaults.standard.set(newValue, forKey: Self.switchInputKey) }
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = statusItem.button {
            button.target = self
            button.action = #selector(statusItemClicked)
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }
        updateIcon()

        watcher.onChange = { [weak self] present in self?.kvmChanged(toMac: present) }
        watcher.start()
        Log.write("시작: KVM=\(watcher.isPresent ? "Mac" : "Windows"), 자동 전환 \(isEnabled ? "켜짐" : "꺼짐"), Mac 깨우기 \(wakesMac ? "켜짐" : "꺼짐"), 입력 전환 \(switchesInput ? "켜짐" : "꺼짐")")
    }

    @objc private func statusItemClicked() {
        if NSApp.currentEvent?.type == .rightMouseUp {
            isEnabled.toggle()
            Log.write("자동 전환 \(isEnabled ? "켜짐" : "꺼짐")")
        } else {
            showMenu()
        }
    }

    private func kvmChanged(toMac: Bool) {
        guard toMac else {
            Log.write("KVM → Windows")
            return
        }
        guard isEnabled else {
            Log.write("KVM → Mac (자동 전환 꺼짐)")
            return
        }
        if wakesMac {
            // 화면이 꺼져 있으면 깨워서 Mac이 HDMI로 신호를 내보내게 한다
            var assertion: IOPMAssertionID = 0
            IOPMAssertionDeclareUserActivity("My KVM" as CFString, kIOPMUserActiveLocal, &assertion)
            Log.write("KVM → Mac: Mac 깨우기")
        }
        guard switchesInput else {
            lastResult = "\(Self.timeFormatter.string(from: Date())) \(wakesMac ? "Mac 깨우기만" : "할 일 없음")"
            return
        }
        Log.write("KVM → Mac: HDMI 1로 전환 시작")
        ddcQueue.async { [weak self] in
            let outcome = InputSwitcher.switchToHDMI1()
            Log.write("KVM → Mac: \(outcome.summary)")
            Task { @MainActor in
                self?.lastResult = "\(Self.timeFormatter.string(from: Date())) \(outcome.summary)"
            }
        }
    }

    // MARK: 메뉴바

    private func updateIcon() {
        guard let button = statusItem?.button else { return }
        button.image = NSImage(systemSymbolName: "display", accessibilityDescription: "My KVM")
        button.image?.isTemplate = true
        button.appearsDisabled = !isEnabled
        button.toolTip = "My KVM: 자동 전환 \(isEnabled ? "켜짐" : "꺼짐") (우클릭으로 전환)"
    }

    /// 좌클릭: 메뉴를 잠깐 붙여 띄운다. menu를 계속 물려두면 우클릭도 메뉴가 열려 버린다.
    private func showMenu() {
        let menu = NSMenu()
        menu.autoenablesItems = false
        menu.addItem(infoItem("자동 전환 \(isEnabled ? "켜짐" : "꺼짐") — 우클릭으로 \(isEnabled ? "끄기" : "켜기")"))
        menu.addItem(infoItem("KVM: \(watcher.isPresent ? "Mac" : "Windows")"))
        menu.addItem(infoItem("마지막 동작: \(lastResult)"))
        menu.addItem(.separator())

        menu.addItem(toggleItem("Mac 깨우기", isOn: wakesMac, action: #selector(toggleWakeMac)))
        menu.addItem(toggleItem("입력 전환 (HDMI 1)", isOn: switchesInput, action: #selector(toggleSwitchInput)))
        menu.addItem(.separator())

        let login = NSMenuItem(title: "로그인 시 자동 실행", action: #selector(toggleLoginItem), keyEquivalent: "")
        login.target = self
        login.state = LoginItemManager.isEnabled ? .on : .off
        menu.addItem(login)
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "종료", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))

        statusItem.menu = menu
        statusItem.button?.performClick(nil)
        statusItem.menu = nil
    }

    private func infoItem(_ title: String) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        item.isEnabled = false
        return item
    }

    private func toggleItem(_ title: String, isOn: Bool, action: Selector) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: "")
        item.target = self
        item.state = isOn ? .on : .off
        return item
    }

    @objc private func toggleWakeMac() {
        wakesMac.toggle()
        Log.write("Mac 깨우기 \(wakesMac ? "켜짐" : "꺼짐")")
    }

    @objc private func toggleSwitchInput() {
        switchesInput.toggle()
        Log.write("입력 전환 \(switchesInput ? "켜짐" : "꺼짐")")
    }

    @objc private func toggleLoginItem() {
        let enable = !LoginItemManager.isEnabled
        do {
            try LoginItemManager.setEnabled(enable)
        } catch {
            let alert = NSAlert()
            alert.messageText = "로그인 항목을 \(enable ? "등록" : "해제")하지 못했습니다"
            alert.informativeText = error.localizedDescription
            alert.runModal()
        }
    }

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter
    }()
}
