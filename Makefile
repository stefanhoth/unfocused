# One source of truth for local development and CI.
SWIFT_SOURCES := Package.swift Sources Tests
CONFIG ?= debug

# Build against the macOS 26 SDK, like CI. With only the Command Line Tools,
# newer SDKs need SwiftUI macro plugins that ship with full Xcode only.
SDK_26 := $(wildcard $(shell xcode-select -p 2>/dev/null)/SDKs/MacOSX26.sdk)
ifneq ($(SDK_26),)
export SDKROOT := $(SDK_26)
# With an overridden SDK the Swift Testing macro plugin isn't found on its own.
TESTING_PLUGINS := $(wildcard $(shell xcode-select -p)/usr/lib/swift/host/plugins/testing)
TEST_FLAGS := $(if $(TESTING_PLUGINS),-Xswiftc -plugin-path -Xswiftc $(TESTING_PLUGINS))
endif

.PHONY: setup lint format build test app run clean reasoner-examples demo site site-og

setup: ## Install the git pre-commit hook
	git config core.hooksPath .githooks

lint: ## Format check + build with warnings as errors
	swift format lint --strict --recursive $(SWIFT_SOURCES)
	swift build -Xswiftc -warnings-as-errors
	scripts/check-design.sh

format: ## Fix formatting in place
	swift format format --in-place --recursive $(SWIFT_SOURCES)

build: ## Build all targets
	swift build -c $(CONFIG) -Xswiftc -warnings-as-errors

test: ## Run all tests
	swift test -Xswiftc -warnings-as-errors $(TEST_FLAGS)

app: ## Assemble the app bundle: build/Unfocused Dev.app locally, build/Unfocused.app for releases
	scripts/build-app.sh

run: app ## Build and launch the app bundle
	open build/*.app

demo: app ## Launch the dev build on made-up data (SHOW=panel, FOCUSED=1), for screenshots
	scripts/demo-app.sh $(if $(FOCUSED),--focused) $(if $(SHOW),--show $(SHOW))

site: ## Serve the landing page (site/public) at http://127.0.0.1:8787
	python3 -m http.server 8787 --bind 127.0.0.1 --directory site/public

site-og: ## Render site/public/og.png, the social sharing image, from site/og/og.html
	"/Applications/Google Chrome.app/Contents/MacOS/Google Chrome" --headless=new --user-data-dir="$$(mktemp -d)" \
	  --hide-scrollbars --window-size=1200,630 --force-device-scale-factor=1 --virtual-time-budget=3000 \
	  --allow-file-access-from-files --screenshot="$(CURDIR)/site/public/og.png" "file://$(CURDIR)/site/og/og.html"

clean:
	rm -rf .build build

# Runs the Reasoner's example set against the real on-device model (needs Apple Intelligence).
reasoner-examples:
	swift run reasoner-examples
