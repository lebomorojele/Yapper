# Yapper Deployment Guide

This guide is for the agent deploying Yapper to a Hetzner VPS with Coolify.

The repo has two production surfaces:

- `app/`: macOS app source, release scripts, DMG packaging, Sparkle appcast generation.
- `website/`: public launch site, exported as a static Next.js site for Coolify.

## What Needs To Be Hosted

The public website should serve:

- `/`: the launch site.
- `/downloads/Yapper-latest.dmg`: the current macOS installer.
- `/downloads/Yapper-<version>.dmg`: the versioned macOS installer.
- `/appcast.xml`: Sparkle update feed. This must match `SUFeedURL` in `app/Yapper/Support/Info.plist`.

The app itself downloads the optional GGUF cleanup model from Hugging Face at runtime. Do not host the GGUF model on the VPS for launch.

## One-Time Apple And Sparkle Setup

These steps require macOS with Xcode command line tools.

### 1. Developer ID Application Certificate

Get this from the Apple Developer account:

1. Open Apple Developer Certificates, Identifiers & Profiles.
2. Create a `Developer ID Application` certificate.
3. Install it into the macOS login keychain.
4. Confirm the exact signing identity:

   ```bash
   security find-identity -v -p codesigning
   ```

The value needed by the release script looks like:

```bash
export DEVELOPER_ID_APPLICATION="Developer ID Application: Name or Company (TEAMID)"
```

### 2. Notary Profile

Create an app-specific password for the Apple ID, then store a notarytool profile:

```bash
xcrun notarytool store-credentials "yapper-notary" \
  --apple-id "apple-id@example.com" \
  --team-id "TEAMID" \
  --password "app-specific-password"
```

The release script expects:

```bash
export NOTARY_PROFILE="yapper-notary"
```

### 3. Sparkle Signing Key

Generate the Sparkle EdDSA key on the Mac:

```bash
app/scripts/generate-sparkle-key.sh
```

Save the public key printed by the tool:

```bash
export SPARKLE_PUBLIC_ED_KEY="PUBLIC_KEY_PRINTED_BY_SPARKLE"
```

Keep the private key secure. Sparkle stores it in the macOS keychain by default. If CI or another machine needs to generate appcasts, export/import the private key with Sparkle’s `generate_keys` tool and use `SPARKLE_PRIVATE_KEY` or `SPARKLE_PRIVATE_KEY_FILE` with `app/scripts/generate-appcast.sh`.

## Build The Release Artifacts On macOS

Run from the repo root on the Mac:

```bash
export SPARKLE_PUBLIC_ED_KEY="..."
export DEVELOPER_ID_APPLICATION="Developer ID Application: Name or Company (TEAMID)"
export NOTARY_PROFILE="yapper-notary"

app/scripts/package-dmg.sh
```

Expected output:

- `app/dist/Yapper.app`
- `app/dist/Yapper-0.1.0.dmg`
- `app/dist/Yapper-0.1.0.dmg.sha256`

Then generate the Sparkle feed:

```bash
export DOWNLOAD_URL_PREFIX="https://yapper.app/downloads"
app/scripts/generate-appcast.sh
```

Expected output:

- `app/dist/sparkle/appcast.xml`
- `app/dist/sparkle/Yapper-0.1.0.dmg`

Prepare the website public files:

```bash
mkdir -p website/public/downloads
cp app/dist/Yapper-0.1.0.dmg website/public/downloads/Yapper-0.1.0.dmg
cp app/dist/Yapper-0.1.0.dmg website/public/downloads/Yapper-latest.dmg
cp app/dist/sparkle/appcast.xml website/public/appcast.xml
```

Commit and push those release files for the launch deploy, or copy the already-built `website/out` directory to the VPS if using a manual static deploy.

## Verify Locally Before VPS Deploy

Use Node 20.9+.

```bash
cd website
npm ci
npm run build
```

Expected output directory:

```text
website/out
```

Check these files exist:

```bash
test -f website/out/index.html
test -f website/out/appcast.xml
test -f website/out/downloads/Yapper-latest.dmg
```

## Coolify Deployment

Recommended Coolify setup: Nixpacks static site.

1. In Coolify, create a new Application.
2. Connect the Git repo.
3. Set branch to the launch branch, likely `main`.
4. Set `Base Directory` to:

   ```text
   /website
   ```

5. Set build pack to `Nixpacks`.
6. Enable `Is it a static site?`.
7. Set `Publish Directory` / `Output Directory` to:

   ```text
   /out
   ```

8. Set install command:

   ```bash
   npm ci
   ```

9. Set build command:

   ```bash
   npm run build
   ```

10. Set domain:

   ```text
   yapper.app,www.yapper.app
   ```

11. Enable HTTPS / Let’s Encrypt in Coolify.
12. Deploy.

Coolify’s own docs for Next.js static deployment specify Nixpacks, static-site mode, and output directory `out`.

## DNS

Point DNS to the Hetzner VPS:

```text
A     yapper.app       <VPS IPv4>
A     www.yapper.app   <VPS IPv4>
AAAA  yapper.app       <VPS IPv6, if configured>
AAAA  www.yapper.app   <VPS IPv6, if configured>
```

If using Cloudflare, start with DNS-only while validating downloads and Sparkle. Turn proxying on later if desired.

## Post-Deploy Verification

Run from any machine:

```bash
curl -I https://yapper.app/
curl -I https://yapper.app/downloads/Yapper-latest.dmg
curl -I https://yapper.app/appcast.xml
curl -fsSL https://yapper.app/appcast.xml | head
```

Expected:

- Website returns `200`.
- DMG returns `200` with a nonzero content length.
- Appcast returns XML.
- The appcast contains `https://yapper.app/downloads/Yapper-0.1.0.dmg`.

On macOS, download and verify:

```bash
curl -L -o /tmp/Yapper.dmg https://yapper.app/downloads/Yapper-latest.dmg
spctl --assess --type open --context context:primary-signature --verbose /tmp/Yapper.dmg
hdiutil attach /tmp/Yapper.dmg
```

After installing `Yapper.app`, open the app menu and choose `Check for Updates...`. Sparkle should read:

```text
https://yapper.app/appcast.xml
```

## Release Update Flow

For each new release:

1. Bump `CFBundleShortVersionString` and `CFBundleVersion` in `app/Yapper/Support/Info.plist`.
2. Run `app/scripts/package-dmg.sh` on macOS with real signing/notary env vars.
3. Run `app/scripts/generate-appcast.sh`.
4. Copy the new DMG to `website/public/downloads/`.
5. Replace `website/public/downloads/Yapper-latest.dmg`.
6. Replace `website/public/appcast.xml`.
7. Commit, push, and redeploy in Coolify.

## Important Notes

- Do not build or notarize the macOS app on the Linux VPS. Apple signing and notarization tooling should happen on macOS.
- Do not use the placeholder Sparkle key for production.
- Do not ship `app/dist/` directly from Git unless deliberately committing release artifacts. The public files Coolify needs are under `website/public/`.
- Keep `https://yapper.app/appcast.xml` stable. Changing it requires shipping an app update with a new `SUFeedURL`.
