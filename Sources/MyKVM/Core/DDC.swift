import Foundation
import IOKit

// Apple Silicon 외부 디스플레이의 I2C(DDC/CI) 통로. 공개 API가 없어 IOKit의 비공개 함수를 쓴다.
@_silgen_name("IOAVServiceCreateWithService")
private func IOAVServiceCreateWithService(_ allocator: CFAllocator?, _ service: io_service_t) -> Unmanaged<CFTypeRef>?
@_silgen_name("IOAVServiceReadI2C")
private func IOAVServiceReadI2C(_ service: CFTypeRef, _ chip: UInt32, _ offset: UInt32, _ buffer: UnsafeMutableRawPointer, _ length: UInt32) -> IOReturn
@_silgen_name("IOAVServiceWriteI2C")
private func IOAVServiceWriteI2C(_ service: CFTypeRef, _ chip: UInt32, _ address: UInt32, _ buffer: UnsafeMutableRawPointer, _ length: UInt32) -> IOReturn
@_silgen_name("IOAVServiceCopyEDID")
private func IOAVServiceCopyEDID(_ service: CFTypeRef, _ edid: UnsafeMutablePointer<Unmanaged<CFData>?>) -> IOReturn

/// MCCS VCP 읽기/쓰기. 호출이 수십~수백 ms 블로킹하므로 메인 스레드 밖에서 부른다.
enum DDC {
    private static let chip: UInt32 = 0x37
    private static let host: UInt32 = 0x51

    /// EDID의 제조사·제품 코드가 일치하는 외부 디스플레이를 찾는다.
    static func display(vendor: UInt16, product: UInt16) -> CFTypeRef? {
        var iterator: io_iterator_t = 0
        guard IOServiceGetMatchingServices(kIOMainPortDefault, IOServiceMatching("DCPAVServiceProxy"), &iterator) == KERN_SUCCESS else { return nil }
        defer { IOObjectRelease(iterator) }
        while case let service = IOIteratorNext(iterator), service != 0 {
            defer { IOObjectRelease(service) }
            guard let av = IOAVServiceCreateWithService(kCFAllocatorDefault, service)?.takeRetainedValue() else { continue }
            var edid: Unmanaged<CFData>?
            guard IOAVServiceCopyEDID(av, &edid) == KERN_SUCCESS,
                  let data = edid?.takeRetainedValue() as Data?, data.count > 12 else { continue }
            let edidVendor = UInt16(data[8]) << 8 | UInt16(data[9])
            let edidProduct = UInt16(data[11]) << 8 | UInt16(data[10])
            if edidVendor == vendor && edidProduct == product { return av }
        }
        return nil
    }

    static func read(_ display: CFTypeRef, _ code: UInt8) -> UInt16? {
        var request: [UInt8] = [0x82, 0x01, code, 0]
        request[3] = checksum(request[0..<3])
        // 일부 모니터는 첫 요청을 흘려서 두 번 보낸다
        for _ in 0..<2 {
            usleep(50_000)
            _ = IOAVServiceWriteI2C(display, chip, host, &request, UInt32(request.count))
        }
        usleep(50_000)
        var reply = [UInt8](repeating: 0, count: 12)
        guard IOAVServiceReadI2C(display, chip, host, &reply, UInt32(reply.count)) == KERN_SUCCESS,
              reply[2] == 0x02, reply[3] == 0, reply[4] == code else { return nil }
        return UInt16(reply[8]) << 8 | UInt16(reply[9])
    }

    static func write(_ display: CFTypeRef, _ code: UInt8, _ value: UInt16) -> Bool {
        var request: [UInt8] = [0x84, 0x03, code, UInt8(value >> 8), UInt8(value & 0xFF), 0]
        request[5] = checksum(request[0..<5])
        return IOAVServiceWriteI2C(display, chip, host, &request, UInt32(request.count)) == KERN_SUCCESS
    }

    private static func checksum(_ bytes: ArraySlice<UInt8>) -> UInt8 {
        bytes.reduce(0x6E ^ UInt8(host), ^)
    }
}
