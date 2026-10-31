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

.PHONY: setup lint format build test app run clean reasoner-examples

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

clean:
	rm -rf .build build

# Runs the Reasoner's example set against the real on-device model (needs Apple Intelligence).
reasoner-examples:
	swift run reasoner-examples
