<h1 align="center">My KVM</h1>

<p align="center">English · <a href="README.ko.md">한국어</a></p>

A macOS menu bar app that makes a USB KVM switch also switch your monitor.
When the KVM hands the keyboard and mouse back to the Mac, My KVM wakes the
Mac's display and switches the monitor input to the Mac over DDC/CI.

Built for one desk: a Mac mini (HDMI 1) and a Windows PC (DisplayPort) sharing
a Philips 279M1RV, with a USB KVM in front of the peripherals. The device IDs
are constants in the source, so adapting it to another setup is a small edit.

- No special permissions (no Accessibility, no Screen Recording)
- Detects the KVM by watching one USB device behind it (a Shanling UA2 DAC)
- Verifies the switch by reading the input back, retrying up to 3 times
- Leaves the monitor alone when the KVM goes to Windows: if Windows is off,
  switching to its DP input makes the monitor start scanning inputs and blink

## Requirements

- Apple Silicon Mac, macOS 15 or later
- A monitor connection that passes DDC/CI (the M4 Mac mini's HDMI port does;
  the HDMI port on M1 and base M2 Macs does not)

## Install

```sh
make install   # builds, ad-hoc signs, copies to ~/Applications and launches
```

## Usage

- **Right-click** the menu bar icon to turn automatic switching on or off
  (the icon dims when off).
- **Left-click** for the menu:
  - **Wake Mac** — wake the display when the KVM switches to the Mac
  - **Switch input (HDMI 1)** — switch the monitor input when the KVM switches to the Mac
  - **Launch at login**
  - **Quit**

Events are logged to `~/Library/Logs/MyKVM.log`.

## Adapting to your setup

| What | Where | Value here |
| --- | --- | --- |
| USB device behind the KVM | `AppDelegate.watcher` | `0x20B1:0x303F` (Shanling UA2) |
| Monitor (EDID vendor/product) | `InputSwitcher.monitorVendor/Product` | `0x410C` / `0xC254` (Philips 279M1RV) |
| Input to select (VCP 0x60) | `InputSwitcher.hdmi1` | `0x11` (HDMI 1) |

Find a USB device's IDs with `system_profiler SPUSBHostDataType`.

## Notes

- DDC/CI on Apple Silicon goes through private IOKit functions
  (`IOAVServiceReadI2C` / `IOAVServiceWriteI2C`), the same approach
  m1ddc and similar tools use. A macOS update could break it.
- On the Windows side, a Group Policy logoff script that switches the monitor
  to HDMI 1 before shutdown keeps the monitor from blinking after Windows
  turns off.

## License

MIT
