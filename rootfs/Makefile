PREFIX ?= $(HOME)/.local
INSTALL_PREFIX ?= $(PREFIX)

##@ General

.PHONY: help
help: ## Display this help.
	@awk 'BEGIN {FS = ":.*##"; printf "\nUsage:\n  make \033[36m<target>\033[0m\n"} /^[a-zA-Z_0-9-]+:.*?##/ { printf "  \033[36m%-15s\033[0m %s\n", $$1, $$2 } /^##@/ { printf "\n\033[1m%s\033[0m\n", substr($$0, 5) } ' $(MAKEFILE_LIST)


.PHONY: install
install: ## Install project (default: ~/.local)
	@echo "Using prefix: $(PREFIX)"
	mkdir -p $(PREFIX)/bin
	install -Dm755 usr/bin/gamepad-os-installer \
		$(PREFIX)/bin/gamepad-os-installer
	mkdir -p $(PREFIX)/share/gamepad-os-installer
	install -Dm644 usr/share/gamepad-os-installer/*.so \
		$(PREFIX)/share/gamepad-os-installer/
	install -Dm755 usr/share/gamepad-os-installer/gamepad-os-installer.x86_64 \
		$(PREFIX)/share/gamepad-os-installer/gamepad-os-installer.x86_64
	install -Dm644 usr/share/gamepad-os-installer/gamepad-os-installer.pck \
		$(PREFIX)/share/gamepad-os-installer/gamepad-os-installer.pck
	@echo "Installation complete"


.PHONY: uninstall
uninstall: ## Uninstall project
	rm -rf $(PREFIX)/bin/gamepad-os-installer
	rm -rf $(PREFIX)/share/gamepad-os-installer/gamepad-os-installer.x86_64
	rm -rf $(PREFIX)/share/gamepad-os-installer/gamepad-os-installer.pck
	rm -rf $(PREFIX)/share/gamepad-os-installer/*.so
	rm -rf $(PREFIX)/share/gamepad-os-installer
	@echo "Uninstall complete"

