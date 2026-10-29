import Foundation
import IOKit
import IOKit.usb

/// 특정 USB 장치가 붙거나 떨어지는 것을 감지한다. KVM 뒤의 장치를 지정하면 KVM 전환 감지가 된다.
/// KVM을 바꾸는 중에 장치가 잠깐 끊겼다 붙는 경우를 걸러내려고, 상태가 바뀐 뒤
/// 잠시 그대로 유지될 때만 onChange를 부른다.
final class USBWatcher {
    var onChange: ((Bool) -> Void)?
    private(set) var isPresent = false

    private let vendor: Int
    private let product: Int
    private var port: IONotificationPortRef?
    private var addedIterator: io_iterator_t = 0
    private var removedIterator: io_iterator_t = 0
    private var pending: DispatchWorkItem?

    init(vendor: Int, product: Int) {
        self.vendor = vendor
        self.product = product
    }

    func start() {
        let port = IONotificationPortCreate(kIOMainPortDefault)
        self.port = port
        CFRunLoopAddSource(CFRunLoopGetMain(), IONotificationPortGetRunLoopSource(port).takeUnretainedValue(), .defaultMode)

        let context = Unmanaged.passUnretained(self).toOpaque()
        IOServiceAddMatchingNotification(port, kIOFirstMatchNotification, matching(), { context, iterator in
            let watcher = Unmanaged<USBWatcher>.fromOpaque(context!).takeUnretainedValue()
            if USBWatcher.drain(iterator) > 0 { watcher.observed(present: true) }
        }, context, &addedIterator)
        IOServiceAddMatchingNotification(port, kIOTerminatedNotification, matching(), { context, iterator in
            let watcher = Unmanaged<USBWatcher>.fromOpaque(context!).takeUnretainedValue()
            if USBWatcher.drain(iterator) > 0 { watcher.observed(present: false) }
        }, context, &removedIterator)

        // 알림을 켜려면 이터레이터를 한 번 비워야 한다. 시작 시점의 기존 장치는 현재 상태로만 쓴다.
        isPresent = Self.drain(addedIterator) > 0
        _ = Self.drain(removedIterator)
    }

    private func observed(present: Bool) {
        pending?.cancel()
        let item = DispatchWorkItem { [weak self] in
            guard let self, self.isPresent != present else { return }
            self.isPresent = present
            self.onChange?(present)
        }
        pending = item
        DispatchQueue.main.asyncAfter(deadline: .now() + (present ? 0.3 : 1.5), execute: item)
    }

    private func matching() -> CFDictionary {
        let dictionary = IOServiceMatching("IOUSBHostDevice") as NSMutableDictionary
        dictionary[kUSBVendorID] = vendor
        dictionary[kUSBProductID] = product
        return dictionary
    }

    private static func drain(_ iterator: io_iterator_t) -> Int {
        var count = 0
        while case let object = IOIteratorNext(iterator), object != 0 {
            count += 1
            IOObjectRelease(object)
        }
        return count
    }
}
