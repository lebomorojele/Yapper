# Yapper Distribution

Yapper ships as a self-hosted, Developer ID signed, notarized DMG. Sparkle handles updates from the same hosted release artifacts.

## One-time setup

1. Join the Apple Developer Program.
2. Install a `Developer ID Application` certificate.
3. Create a notarytool keychain profile:

   ```bash
   xcrun notarytool store-credentials "yapper-notary" \
     --apple-id "you@example.com" \
     --team-id "TEAMID" \
     --password "app-specific-password"
   ```

4. Generate Sparkle keys:

   ```bash
   app/scripts/generate-sparkle-key.sh
   ```

5. Copy the printed public key into `SPARKLE_PUBLIC_ED_KEY` for release builds. Keep the private key safe.

## Build a local smoke-test DMG

```bash
ALLOW_PLACEHOLDER_SPARKLE_KEY=1 app/scripts/package-dmg.sh
```

This produces:

- `app/dist/Yapper.app`
- `app/dist/Yapper-<version>.dmg`
- `app/dist/Yapper-<version>.dmg.sha256`

## Build a launch DMG

```bash
export SPARKLE_PUBLIC_ED_KEY="..."
export DEVELOPER_ID_APPLICATION="Developer ID Application: Your Name (TEAMID)"
export NOTARY_PROFILE="yapper-notary"
app/scripts/package-dmg.sh
```

The script signs the bundled helper binaries, signs Sparkle, signs the app with hardened runtime, creates the DMG, submits it to Apple notarization, staples the result, and writes a SHA-256 checksum.

## Generate Sparkle appcast

```bash
export DOWNLOAD_URL_PREFIX="https://yapper.app/downloads"
app/scripts/generate-appcast.sh
```

Upload the generated DMG files from `app/dist/sparkle/` to the hosted downloads directory. `appcast.xml` must be available at:

```text
https://yapper.app/appcast.xml
```

If the appcast is hosted somewhere else, update `SUFeedURL` in `app/Yapper/Support/Info.plist` before packaging.

For the full Hetzner/Coolify deployment flow, see `DEPLOYMENT.md` at the repo root.
