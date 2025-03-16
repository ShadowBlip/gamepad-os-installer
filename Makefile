BUILD_TYPE ?= release
GODOT ?= /usr/bin/godot
GODOT_VERSION ?= $(shell $(GODOT) --version | grep -o '[0-9].*[0-9]\.' | sed 's/.$$//')
GODOT_RELEASE ?= $(shell $(GODOT) --version | grep -oP '^[0-9].*?[a-z]\.' | grep -oP '[a-z]+')
GODOT_REVISION := $(GODOT_VERSION).$(GODOT_RELEASE)
EXPORT_TEMPLATE ?= $(HOME)/.local/share/godot/export_templates/$(GODOT_REVISION)/linux_$(BUILD_TYPE).x86_64
EXPORT_TEMPLATE_URL ?= https://github.com/godotengine/godot/releases/download/$(GODOT_VERSION)-$(GODOT_RELEASE)/Godot_v$(GODOT_VERSION)-$(GODOT_RELEASE)_export_templates.tpz

PREFIX ?= $(HOME)/.local
CACHE_DIR ?= .cache
IMPORT_DIR := .godot
ROOTFS ?= $(CACHE_DIR)/rootfs

ALL_EXTENSIONS := ./addons/core/bin/libopengamepadui-core.linux.template_$(BUILD_TYPE).x86_64.so
ALL_EXTENSION_FILES := $(shell find ./extensions/ -regex  '.*\(\.rs|\.toml\|\.lock\)$$')
ALL_GDSCRIPT := $(shell find ./ -name '*.gd')
ALL_SCENES := $(shell find ./ -name '*.tscn')
ALL_RESOURCES := $(shell find ./ -regex  '.*\(tres\|svg\|png\)$$')
PROJECT_FILES := $(ALL_GDSCRIPT) $(ALL_SCENES) $(ALL_RESOURCES)


##@ General

# The help target prints out all targets with their descriptions organized
# beneath their categories. The categories are represented by '##@' and the
# target descriptions by '##'. The awk commands is responsible for reading the
# entire set of makefiles included in this invocation, looking for lines of the
# file as xyz: ## something, and then pretty-format the target and help. Then,
# if there's a line with ##@ something, that gets pretty-printed as a category.
# More info on the usage of ANSI control characters for terminal formatting:
# https://en.wikipedia.org/wiki/ANSI_escape_code#SGR_parameters
# More info on the awk command:
# http://linuxcommand.org/lc3_adv_awk.php

.PHONY: help
help: ## Display this help.
	@awk 'BEGIN {FS = ":.*##"; printf "\nUsage:\n  make \033[36m<target>\033[0m\n"} /^[a-zA-Z_0-9-]+:.*?##/ { printf "  \033[36m%-15s\033[0m %s\n", $$1, $$2 } /^##@/ { printf "\n\033[1m%s\033[0m\n", substr($$0, 5) } ' $(MAKEFILE_LIST)


.PHONY: install
install: rootfs ## Install project (default: ~/.local)
	cd $(ROOTFS) && make install PREFIX=$(PREFIX)


.PHONY: uninstall
uninstall: ## Uninstall project
	cd $(ROOTFS) && make uninstall PREFIX=$(PREFIX)


##@ Development

.PHONY: edit
edit: $(IMPORT_DIR) ## Open the project in the Godot editor
	$(GODOT) --editor .


.PHONY: extensions
extensions: $(ALL_EXTENSIONS) ## Build engine extensions
$(ALL_EXTENSIONS) &: $(ALL_EXTENSION_FILES)
	@echo "Building engine extensions..."
	cd ./extensions && $(MAKE) build


.PHONY: import
import: .godot ## Import project assets
.godot: $(ALL_EXTENSIONS)
	@echo "Importing project assets. This will take some time..."
	command -v $(GODOT) > /dev/null 2>&1
	$(GODOT) --headless --import > /dev/null 2>&1 || echo "Finished"
	touch .godot


.PHONY: build
build: build/gamepad-os-installer.x86_64 ## Build and export the project
build/gamepad-os-installer.x86_64: $(IMPORT_DIR) $(PROJECT_FILES) $(EXPORT_TEMPLATE)
	mkdir -p build
	$(GODOT) --headless --export-$(BUILD_TYPE) "Linux"


.PHONY: clean
clean: ## Remove build artifacts
	rm -rf .cache
	rm -rf .godot
	rm -rf build
	rm -rf dist


.PHONY: purge 
purge: clean ## Remove all build artifacts including engine extensions
	rm -rf $(ROOTFS)
	cd ./extensions && $(MAKE) clean


##@ Distribution

.PHONY: rootfs
rootfs: build/gamepad-os-installer.x86_64
	rm -rf $(ROOTFS)
	mkdir -p $(ROOTFS)
	cp -r rootfs/* $(ROOTFS)
	mkdir -p $(ROOTFS)/usr/share/gamepad-os-installer
	cp -r build/*.so $(ROOTFS)/usr/share/gamepad-os-installer
	cp -r build/gamepad-os-installer.x86_64 $(ROOTFS)/usr/share/gamepad-os-installer
	cp -r build/gamepad-os-installer.pck $(ROOTFS)/usr/share/gamepad-os-installer
	touch $(ROOTFS)/.gdignore


$(EXPORT_TEMPLATE):
	@echo "$(EXPORT_TEMPLATE)"
	mkdir -p $(HOME)/.local/share/godot/export_templates
	@echo "Downloading export templates"
	wget $(EXPORT_TEMPLATE_URL) -O $(HOME)/.local/share/godot/export_templates/templates.zip
	@echo "Extracting export templates"
	unzip $(HOME)/.local/share/godot/export_templates/templates.zip -d $(HOME)/.local/share/godot/export_templates/
	rm $(HOME)/.local/share/godot/export_templates/templates.zip
	mv $(HOME)/.local/share/godot/export_templates/templates $(@D)
