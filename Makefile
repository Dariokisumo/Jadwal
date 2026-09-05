.PHONY: build copy clean build-arm32 copy-arm32

JAVA_HOME := /home/node/.gradle/jdks/eclipse_adoptium-17-amd64-linux.2
VERSION := $(shell grep '^version:' pubspec.yaml | awk '{print $$2}' | tr '+' '-')
APK_SRC := build/app/outputs/flutter-apk/app-release.apk
APK_DST := Apk files/jadwal-v$(VERSION)-release.apk
APK_DST32 := Apk files/apk32/jadwal-v$(VERSION)-release.apk

build:
	JAVA_HOME=$(JAVA_HOME) flutter build apk --release --target-platform android-arm64 --android-skip-build-dependency-validation --no-tree-shake-icons --no-pub --no-shrink
	cp $(APK_SRC) "$(APK_DST)"
	@echo "Built: jadwal-v$(VERSION)-release.apk (arm64-v8a)"

copy:
	cp $(APK_SRC) "$(APK_DST)"
	@echo "Copied: jadwal-v$(VERSION)-release.apk (arm64-v8a)"

build-arm32:
	sed -i 's/abiFilters "arm64-v8a"/abiFilters "armeabi-v7a"/' android/app/build.gradle
	sed -i "s|exclude 'lib/armeabi-v7a/\*\*|exclude 'lib/arm64-v8a/**|g" android/app/build.gradle
	JAVA_HOME=$(JAVA_HOME) flutter build apk --release --target-platform android-arm --android-skip-build-dependency-validation --no-tree-shake-icons --no-pub --no-shrink
	cp $(APK_SRC) "$(APK_DST32)"
	@echo "Built: jadwal-v$(VERSION)-release.apk (armeabi-v7a) -> Apk files/apk32/"
	sed -i 's/abiFilters "armeabi-v7a"/abiFilters "arm64-v8a"/' android/app/build.gradle
	sed -i "s|exclude 'lib/arm64-v8a/\*\*|exclude 'lib/armeabi-v7a/**|g" android/app/build.gradle

copy-arm32:
	cp $(APK_SRC) "$(APK_DST32)"
	@echo "Copied: jadwal-v$(VERSION)-release.apk (armeabi-v7a) -> Apk files/apk32/"

clean:
	flutter clean
