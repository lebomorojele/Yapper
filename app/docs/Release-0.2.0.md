# Yapper 0.2.0 release checks

Yapper 0.2.0 targets Apple silicon Macs running macOS 15 or later. This release
adds guided setup, model download progress, microphone startup errors, retry,
last-transcript copying, and cancellation that prevents late text insertion.
The recording indicator responds to microphone levels before words arrive.
Input selection and launch at login now apply the corresponding system settings.

## Verify the app on macOS

Run these commands from the repository root:

```bash
swift test --package-path app
YAPPER_RUN_STT_INTEGRATION=1 swift test --package-path app --filter RealTranscriptionTests
swift build -c release --package-path app
ALLOW_PLACEHOLDER_SPARKLE_KEY=1 app/scripts/package-dmg.sh
app/scripts/smoke-bundle.sh
```

The integration check downloads the production speech model and transcribes a
20-second recording through `ParakeetTranscriber`. It checks recognized phrases
near the end of the recording. It does not test microphone hardware, hotkey access,
or insertion into third-party apps. Run `app/docs/Hotkey-QA-Checklist.md` on a Mac
with microphone and accessibility permissions for those checks.

`smoke-bundle.sh` captures the setup and settings windows, then transcribes the
recording inside the actual app bundle with `.build` hidden. UI test mode suppresses
permission prompts. The speech check uses the production model cache.
Inspect `app/dist/welcome.png` and `app/dist/settings.png` after the script passes.

## Verify native UI behavior

Install XcodeGen, then generate the project and run the hosted UI tests:

```bash
brew install xcodegen
app/scripts/generate-project.sh
xcodebuild test -project app/Yapper.xcodeproj -scheme Yapper \
  -destination 'platform=macOS' -only-testing:YapperUITests CODE_SIGNING_ALLOWED=NO
```

The tests open setup, check its required permissions, and navigate the Audio,
Keyboard, and About panes. The generated project uses the resolved SwiftPM graph.

## Stage and verify the release

Download the `Yapper-macOS` artifact from the successful GitHub Actions run.
Its `dist/` directory contains the installer, checksum, native screenshots, and
speech verification log. Copy `dist/sparkle/appcast.xml` beside the installer
before running the release check:

```bash
python3 app/scripts/verify-release.py <staging-directory>
```

The check requires Python 3 and OpenSSL 1.1.1 or later. It verifies the appcast
version, build, download URL, disk image header, byte count, checksum, and
Ed25519 signature against the public key in `Info.plist`.

## Signing and production publication

The CI installer is ad-hoc signed. Sparkle updates use the existing Ed25519 key.
Apple notarization requires a Developer ID certificate and notary credentials
that are not configured in this repository. If macOS blocks the first launch, use **Open Anyway** in System Settings →
Privacy & Security after attempting to open the installed app.

The website remains at its original version. This release work is limited to the
macOS app. Obtain explicit confirmation before triggering a Coolify deployment,
as required by the VPS working agreements.

## Verified release

[Run 42713842237](https://github.com/lebomorojele/Yapper/actions/runs/42713842237)
passed all app checks:

- 47 unit tests, including cancellation of a real cleanup child process.
- Production Core ML recognition of the 20-second speech recording.
- Recognition inside the packaged app with the build directory hidden.
- Native setup and settings UI tests, including Audio, Keyboard, and About navigation.
- Release compilation, native window capture, and DMG packaging.

The installer is 15,913,564 bytes. SHA-256:

```text
743332b0b9179a754f386786f6ec48e8d3610eedd61b4b642b7abe28e6da0fcb
```

The appcast signature verifies against the public key embedded in the app's
source plist. The installed app sources match commit `d7d8d3b`. The website is
unchanged from `main`.

Pre-existing verification problems corrected during this release were the
Swift 6 XCTest setup, incomplete dependency lockfile, stale Xcode project,
UI-test host configuration, and settings selectors that queried the wrong
native accessibility attributes. No failures remain in the app CI run above.
