.PHONY: build copy clean build-arm32 copy-arm32 build-both verify diagnose info bump-patch bump-minor bump-major

build:
	@./scripts/build-apk.sh --arm64

copy:
	@./scripts/build-apk.sh --arm64 --copy-only

build-arm32:
	@./scripts/build-apk.sh --arm32

copy-arm32:
	@./scripts/build-apk.sh --arm32 --copy-only

build-both:
	@./scripts/build-apk.sh --both

verify:
	@./scripts/verify-env.sh

diagnose:
	@./scripts/diagnose.sh

info:
	@./scripts/apk-info.sh

bump-patch:
	@./scripts/bump-version.sh patch

bump-minor:
	@./scripts/bump-version.sh minor

bump-major:
	@./scripts/bump-version.sh major

clean:
	flutter clean
