.PHONY: build app run install

build:
	swift build

app:
	bash scripts/bundle.sh

run: app
	open "dist/My KVM.app"

# 실행 중인 앱을 종료하고 ~/Applications에 덮어쓴 뒤 다시 연다.
install: app
	-osascript -e 'quit app "My KVM"'
	ditto "dist/My KVM.app" "$(HOME)/Applications/My KVM.app"
	open "$(HOME)/Applications/My KVM.app"
