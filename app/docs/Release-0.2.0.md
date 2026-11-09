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
Copy its versioned DMG, checksum, and `sparkle/appcast.xml` to
`website/public/downloads/` and `website/public/appcast.xml` respectively. Copy the
same DMG to `website/public/downloads/Yapper-latest.dmg`.

Run this check with Python 3 and OpenSSL 1.1.1 or later:

```bash
python3 app/scripts/verify-release.py website/public
```

You can also pass a staging directory containing all four files. The script checks the
appcast version, build, expected download URL, image header, byte count, checksum,
and Ed25519 signature against the public key in `Info.plist`.

## Signing and production publication

The CI installer is ad-hoc signed. Sparkle updates use the existing Ed25519 key.
Apple notarization requires a Developer ID certificate and notary credentials
that are not configured in this repository. If macOS blocks the first launch, use **Open Anyway** in System Settings →
Privacy & Security after attempting to open the installed app.

The website remains at its original version. This release work is limited to the
macOS app. Obtain explicit confirmation before triggering a Coolify deployment,
as required by the VPS working agreements.

## Candidate evidence

The packaged candidate was built and verified in
[run 42708767424](https://github.com/lebomorojele/Yapper/actions/runs/42708767424).
Its macOS job passed unit tests, real model inference, isolated bundle inference,
native screen capture, and DMG packaging. The original native UI check in that run
failed because it queried a container identifier SwiftUI does not expose.
The corrected UI check uses visible windows and controls.

The installer is 15,921,003 bytes. SHA-256:

```text
81204fd91ced00f6fd20e837de577b919e43077d5ac2eb50876bfdab899937a1
```

The appcast signature verifies against the public key embedded in the app's
source plist. The installed app sources match commit `0c3949b`. The staged
lockfile records the complete dependency graph that the successful build used.
