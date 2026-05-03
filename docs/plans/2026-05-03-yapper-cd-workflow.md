# Yapper CD: GitHub Actions Auto-Build & Deploy Plan

> **Goal:** Automate macOS DMG builds on every push to main — build, package, generate appcast, push release artifacts to the repo, then Coolify auto-deploys the website with new downloads.

**Architecture:** A single GitHub Actions workflow runs on macOS (Xcode + Swift + hdiutil). On push to `main`, it builds the Yapper Swift app, packages it into a signed/notarized DMG, generates the Sparkle appcast.xml, commits the artifacts to `website/public/`, and pushes back. The next Coolify deploy picks up the new files.

**Constraints:**
- No Apple Developer Program yet — uses `ALLOW_PLACEHOLDER_SPARKLE_KEY=1` for unsigned DMGs
- Must avoid infinite workflow loops (commit back with `[skip ci]`)
- Domain is `yapper.party`, not `yapper.app`
- Apps built for both Intel (x86_64) and Apple Silicon (arm64)

---

## Task 1: Create the GitHub Actions Workflow

**Objective:** Write `.github/workflows/build-release.yml` with the full macOS build + DMG packaging pipeline.

**Files:**
- Create: `.github/workflows/build-release.yml`

**Details:**

The workflow should:
1. Trigger on push to `main`
2. Run on `macos-latest` (GitHub's macOS runner with Xcode)
3. Steps:
   - Checkout repo with full git history and `persist-credentials: true`
   - Build Swift app in release mode
   - Package the DMG (unsigned, placeholder Sparkle key)
   - Generate Sparkle appcast with DOWNLOAD_URL_PREFIX=https://yapper.party/downloads
   - Verify build artifacts exist
   - Copy DMG + appcast to website/public/
   - Commit and push back (with `[skip ci]` to avoid loops)

**Key considerations:**
- Use `swift build -c release --package-path app` to build from the `app/` subdirectory
- `ALLOW_PLACEHOLDER_SPARKLE_KEY=1` is set for unsigned DMGs
- The commit message **must** contain `[skip ci]` to prevent re-triggering
- Use `GITHUB_TOKEN` for the push (default — no custom secret needed)
- Use `git config user.name "github-actions[bot]"` and `user.email` for the bot commit

## Task 2: Verify Workflow Syntax

**Objective:** Run a dry validation check on the workflow YAML.

**Files:**
- Validate: `.github/workflows/build-release.yml`

**Commands:**
```bash
cd /root/projects/Yapper
# GitHub's action-validator or just push and let GitHub validate
# We'll push the workflow file and check GitHub Actions tab
```

## Task 3: Push & Trigger First Build

**Objective:** Commit and push the workflow, verify it triggers on GitHub.

**Files:**
- Commit: `.github/workflows/build-release.yml`

**Commands:**
```bash
cd /root/projects/Yapper
git add .github/workflows/build-release.yml
git commit -m "ci: add automated macOS build + DMG release workflow"
git push
```

**Verification:**
- Check GitHub → Actions tab → Yapper repo
- A workflow run should appear for the push
- Wait for it to complete (approx. 3-5 minutes on macOS runner)
- Verify DMG and appcast.xml appear in `website/public/`

## Task 4: Test Download From Live Site

**Objective:** After Coolify deploys (auto), verify DMG downloads work.

**Verification:**
```bash
curl -IL https://yapper.party/downloads/Yapper-latest.dmg
```
Expected: 200 OK with Content-Length > 0

```bash
curl -fsSL https://yapper.party/appcast.xml | head
```
Expected: valid XML with DMG download URL

---

## Summary

After all tasks complete:
- Every push to `main` auto-builds a new DMG on GitHub's macOS runners
- The DMG + appcast land in `website/public/` and are committed back
- Coolify auto-deploys the updated website
- Users can download from `https://yapper.party/downloads/Yapper-latest.dmg`
- Sparkle updates work from `https://yapper.party/appcast.xml`
