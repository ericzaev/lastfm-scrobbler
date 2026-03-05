NAME = MusicLastFMPlugin
BUILD_DIR = .build/release
APP_NAME = $(NAME).app
CONTENTS_DIR = $(APP_NAME)/Contents
MACOS_DIR = $(CONTENTS_DIR)/MacOS
RESOURCES_DIR = $(CONTENTS_DIR)/Resources

all: build bundle

build:
	swift build -c release

bundle:
	mkdir -p $(MACOS_DIR)
	mkdir -p $(RESOURCES_DIR)
	cp $(BUILD_DIR)/$(NAME) $(MACOS_DIR)/
	cp Resources/Info.plist $(CONTENTS_DIR)/
	cp Resources/AppIcon.icns $(RESOURCES_DIR)/
	@echo "Built $(APP_NAME) successfully."

clean:
	rm -rf .build
	rm -rf $(APP_NAME)

.PHONY: all build bundle clean
