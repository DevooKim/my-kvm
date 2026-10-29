import Foundation

/// Philips 279M1RV의 입력을 Mac이 꽂힌 HDMI 1로 바꾼다.
/// VCP 0x60 값의 하위 바이트가 주 화면 입력이고 상위 바이트는 PIP 보조 입력이다.
enum InputSwitcher {
    static let monitorVendor: UInt16 = 0x410C   // "PHL"
    static let monitorProduct: UInt16 = 0xC254  // 279M1RV
    static let hdmi1: UInt16 = 0x11

    enum Outcome {
        case alreadySet
        case switched
        case failed(String)

        var summary: String {
            switch self {
            case .alreadySet: return "이미 HDMI 1"
            case .switched: return "HDMI 1로 전환"
            case .failed(let reason): return "실패: \(reason)"
            }
        }
    }

    /// 블로킹 호출. 쓰고 2초 뒤 다시 읽어 확인하며 최대 3번 시도한다.
    static func switchToHDMI1() -> Outcome {
        var wrote = false
        for _ in 1...3 {
            guard let display = DDC.display(vendor: monitorVendor, product: monitorProduct) else {
                sleep(2)
                continue
            }
            if let current = DDC.read(display, 0x60), current & 0xFF == hdmi1 {
                return wrote ? .switched : .alreadySet
            }
            wrote = DDC.write(display, 0x60, hdmi1) || wrote
            sleep(2)
        }
        guard let display = DDC.display(vendor: monitorVendor, product: monitorProduct) else {
            return .failed("모니터를 찾지 못함")
        }
        guard let current = DDC.read(display, 0x60) else { return .failed("입력값을 읽지 못함") }
        return current & 0xFF == hdmi1 ? .switched : .failed(String(format: "입력값 0x%02X", current & 0xFF))
    }
}
