# Yapper 0.2.0 release checks

Yapper 0.2.0 targets Apple silicon Macs running macOS 15 or later. This release
adds guided setup, model download progress, microphone startup errors, retry,
last-transcript copying, and cancellation that prevents late text insertion.
The recording indicator responds to microphone levels before words arrive.
Input selection and launch at login now apply the corresponding system settings.

The website has direct installer links, a sample dictation demo, setup instructions,
and first-launch help. Its demo uses prepared examples and does not access a microphone.

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

`smoke-bundle.sh` launches the packaged app twice and captures the setup and
settings windows. UI test mode suppresses model downloads and permission prompts.
Inspect `app/dist/welcome.png` and `app/dist/settings.png` after the script passes.

## Verify the site

Use Node 22 or later:

```bash
cd website
npm ci
npx tsc --noEmit
npm run build
python3 -m http.server 4177 --bind 127.0.0.1 --directory out
```

In another terminal, run from the repository root:

```bash
website/scripts/verify-browser.sh http://127.0.0.1:4177
```

The browser check needs Chromium and `agent-browser` through npm. It checks the
demo outputs, FAQ, responsive widths, and installer links.

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
that are not configured in this repository. The website explains macOS's
**Open Anyway** flow for this early build.

Production is hosted through Coolify. Pushing this branch does not change the
live site. Obtain explicit confirmation before merging into the production
branch or triggering a Coolify deployment, as required by the VPS working
agreements. After publication, rerun the browser and release checks against the
live download and feed.
