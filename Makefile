# One source of truth for local development and CI.
SWIFT_SOURCES := Package.swift Sources Tests
CONFIG ?= debug

# Build against the macOS 26 SDK, like CI. With only the Command Line Tools,
# newer SDKs need SwiftUI macro plugins that ship with full Xcode only.
SDK_26 := $(wildcard $(shell xcode-select -p 2>/dev/null)/SDKs/MacOSX26.sdk)
ifneq ($(SDK_26),)
export SDKROOT := $(SDK_26)
endif

.PHONY: setup lint format build test app run clean

setup: ## Install the git pre-commit hook
	git config core.hooksPath .githooks

lint: ## Format check + build with warnings as errors
	swift format lint --strict --recursive $(SWIFT_SOURCES)
	swift build -Xswiftc -warnings-as-errors

format: ## Fix formatting in place
	swift format format --in-place --recursive $(SWIFT_SOURCES)

build: ## Build all targets
	swift build -c $(CONFIG) -Xswiftc -warnings-as-errors

test: ## Run all tests
	swift test -Xswiftc -warnings-as-errors

app: ## Assemble build/Unfocused.app (release, ad-hoc signed)
	scripts/build-app.sh

run: app ## Build and launch the app bundle
	open build/Unfocused.app

clean:
	rm -rf .build build
