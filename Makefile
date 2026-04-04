.PHONY: all build-server test-server run-server build-ios test-ios clean deploy

# ============================================================
# boopsy — top-level convenience targets
# ============================================================

all: build-server build-ios

# ---- Server (Vapor / Swift Package) ------------------------

build-server:
	cd server && swift build -c release

test-server:
	cd server && swift test

run-server:
	cd server && swift run App serve --env development --hostname 0.0.0.0 --port 8080

run-server-watch:
	cd server && swift run App serve --env development --hostname 0.0.0.0 --port 8080 --auto-migrate

# ---- iOS (Xcode) -------------------------------------------

IOS_SIMULATOR ?= platform=iOS Simulator,name=iPhone 16
IOS_SCHEME    ?= Blip

build-ios:
	cd ios && xcodebuild \
		-project Blip.xcodeproj \
		-scheme $(IOS_SCHEME) \
		-sdk iphonesimulator \
		-destination '$(IOS_SIMULATOR)' \
		build

test-ios:
	cd ios && xcodebuild \
		-project Blip.xcodeproj \
		-scheme $(IOS_SCHEME) \
		-sdk iphonesimulator \
		-destination '$(IOS_SIMULATOR)' \
		test

regen-ios:
	cd ios && xcodegen generate

# ---- Docker / Fly.io ---------------------------------------

docker-build:
	cd server && docker build -t boopsy-server .

deploy:
	cd server && fly deploy

# ---- Housekeeping ------------------------------------------

clean:
	cd server && swift package clean
	cd ios && xcodebuild -project Blip.xcodeproj -scheme $(IOS_SCHEME) clean 2>/dev/null || true
