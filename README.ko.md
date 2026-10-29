<h1 align="center">My KVM</h1>

<p align="center"><a href="README.md">English</a> · 한국어</p>

USB KVM 스위치를 바꿀 때 모니터 입력까지 같이 바꿔 주는 macOS 메뉴바 앱.
KVM이 키보드·마우스를 Mac으로 돌려주면, Mac 화면을 깨우고 DDC/CI로
모니터 입력을 Mac 쪽으로 바꿉니다.

Mac mini(HDMI 1)와 Windows PC(DisplayPort)가 Philips 279M1RV 한 대를 같이 쓰고,
주변기기 앞에 USB KVM이 있는 책상 하나를 위해 만들었습니다. 장치 ID는 소스의
상수라서 다른 구성에 맞추려면 몇 줄만 고치면 됩니다.

- 특수 권한 불필요 (손쉬운 사용·화면 기록 모두 필요 없음)
- KVM 뒤에 있는 USB 장치 하나(Shanling UA2 DAC)가 붙고 떨어지는 것으로 KVM 전환을 감지
- 전환 후 입력값을 다시 읽어 확인하고, 안 바뀌었으면 최대 3번 재시도
- KVM이 Windows로 갈 때는 모니터를 건드리지 않음: Windows가 꺼져 있을 때 DP로
  바꾸면 모니터가 입력을 찾아다니며 깜박이기 때문

## 요구 사항

- Apple Silicon Mac, macOS 15 이상
- DDC/CI가 통하는 모니터 연결 (M4 Mac mini의 HDMI는 되고, M1·기본 M2의 HDMI는 안 됨)

## 설치

```sh
make install   # 빌드, ad-hoc 서명, ~/Applications에 복사 후 실행
```

## 사용법

- 메뉴바 아이콘 **우클릭**: 자동 전환 켜기/끄기 (꺼지면 아이콘이 흐려짐)
- **좌클릭**: 메뉴
  - **Mac 깨우기**: KVM이 Mac으로 오면 화면을 깨움
  - **입력 전환 (HDMI 1)**: KVM이 Mac으로 오면 모니터 입력을 바꿈
  - **로그인 시 자동 실행**
  - **종료**

동작 기록은 `~/Library/Logs/MyKVM.log`에 남습니다.

## 다른 구성에 맞추기

| 항목 | 위치 | 이 구성의 값 |
| --- | --- | --- |
| KVM 뒤의 USB 장치 | `AppDelegate.watcher` | `0x20B1:0x303F` (Shanling UA2) |
| 모니터 (EDID 제조사/제품) | `InputSwitcher.monitorVendor/Product` | `0x410C` / `0xC254` (Philips 279M1RV) |
| 고를 입력 (VCP 0x60) | `InputSwitcher.hdmi1` | `0x11` (HDMI 1) |

USB 장치 ID는 `system_profiler SPUSBHostDataType`으로 확인할 수 있습니다.

## 참고

- Apple Silicon의 DDC/CI는 IOKit 비공개 함수(`IOAVServiceReadI2C` / `IOAVServiceWriteI2C`)를
  씁니다. m1ddc 같은 도구와 같은 방식이고, macOS 업데이트로 막힐 수 있습니다.
- Windows 쪽에서는 그룹 정책 로그오프 스크립트로 종료 전에 모니터를 HDMI 1로 바꿔 두면,
  Windows가 꺼진 뒤 모니터가 깜박이지 않습니다.

## 라이선스

MIT
