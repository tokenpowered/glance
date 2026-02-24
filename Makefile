SCHEME = Glance
CONFIG = Release
BUILD_DIR = $(CURDIR)/.build
DERIVED_DATA = $(BUILD_DIR)/DerivedData
APP_PATH = $(DERIVED_DATA)/Build/Products/$(CONFIG)/Glance.app

.PHONY: build install clean rebuild

build:
	xcodebuild -scheme $(SCHEME) -configuration $(CONFIG) \
		-derivedDataPath $(DERIVED_DATA) \
		build

install: build
	@echo "Installing Glance.app to /Applications..."
	@rm -rf /Applications/Glance.app
	cp -R "$(APP_PATH)" /Applications/
	qlmanage -r
	@echo "Installed. Run 'open /Applications/Glance.app' on first install to register the extension."

clean:
	xcodebuild -scheme $(SCHEME) -configuration $(CONFIG) \
		-derivedDataPath $(DERIVED_DATA) \
		clean 2>/dev/null || true
	rm -rf $(BUILD_DIR)

rebuild: clean build
