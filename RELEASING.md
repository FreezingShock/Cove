# Releasing Cove

Cove ships from `integration` to `main`. Feature PRs land on `integration`. A release
is one bump-and-changelog PR into `integration`, then one merge from `integration`
into `main`. The `main` push builds the app and publishes a GitHub Release.

```
feature PRs ──▶ integration ──[Prepare release]──▶ "Release X" PR ──▶ integration
                    │
                    └──[nate: PR integration → main, merge commit]──▶ main
                                                                        │
                                                    [Release workflow] ◀┘
                                                    build, zip, DMG, tag vX,
                                                    GitHub Release (+ appcast)
```

## One-time setup

1. **Merge commits only for integration → main.** In the PR, use **Create a merge
   commit**. Never squash or rebase it. A squash makes `main` diverge from
   `integration`, and the next release PR conflicts.
2. **Allow auto-merge** in repo settings (Settings → General → Allow auto-merge).
3. **Add a `RELEASE_TOKEN` secret.** It is a fine-grained PAT or GitHub App token with
   contents and pull-requests write access. A PR opened with the default
   `GITHUB_TOKEN` does not start CI, so auto-merge would wait forever. Without the
   secret, the release PR still opens, and nate merges it by hand after checking it.
4. **The release workflows appear after the first deploy.** GitHub only offers
   `workflow_dispatch` for workflows on the default branch (`main`). The first
   integration → main merge ships whatever version `Cove.xcodeproj` holds at that
   point (0.1 build 1, from PR #1). That release is created automatically.

## Each release

1. **Prepare.** Actions → **Prepare release** → Run workflow. Pick `minor` (the
   default, so 0.1 → 0.2), `patch`, or `major`. Type an exact version in `version` to
   override the bump. The workflow:
   - bumps `MARKETING_VERSION` and increments `CURRENT_PROJECT_VERSION` in
     `Cove.xcodeproj/project.pbxproj`;
   - adds a `## [X.Y] - date` section to `CHANGELOG.md`, built from PR titles of commits
     on `integration` that are not on `main`;
   - opens **Release X.Y** into `integration` and turns on auto-merge.
2. **Review and merge the Release PR into `integration`.** Auto-merge does this once
   the `build` check passes. If a PR title reads badly in the changelog, edit that
   section in the Release PR before it merges.
3. **Deploy.** Open a PR from `integration` into `main` and choose **Create a merge
   commit**. Nate does this, and only nate merges into `main`.
4. **Release.** The push to `main` runs **Release**. It skips if `vX.Y` already has a
   release. Otherwise it builds Release on `macos-26`, checks that the built app reports
   the expected version, packages it, and publishes `v<version>` as the latest release.

### What a release contains

| Asset | Use |
| --- | --- |
| `Cove-<version>.dmg` | Drag-to-Applications disk image, versioned. |
| `Cove.dmg` | Same DMG under a fixed name. The website's download link uses it: `https://github.com/FreezingShock/Cove/releases/latest/download/Cove.dmg`. |
| `Cove-<version>.zip` | The app bundle, for Sparkle updates and manual downloads. |
| `SHA256SUMS.txt` | Checksums for the files above. |
| `appcast.xml` | Sparkle feed, when `scripts/release/update-appcast.sh` exists. |

The release notes are the changelog section for that version.

## Versioning

- `MARKETING_VERSION` is the version people see (0.1, 0.2, ... 1.0).
- `CURRENT_PROJECT_VERSION` is the build number. It goes up by one on every bump, and
  Sparkle compares it when deciding whether an update is newer.
- Stay on `0.x` until v1.0 is ready. Bump `minor` for feature releases and `patch` for
  fixes.

## Installing an unsigned build (Gatekeeper)

Releases are ad-hoc signed, not notarized, so macOS blocks the first launch.

- **Finder:** open `Cove.app`, or the DMG and then the app. macOS says it cannot verify
  the app. Click **Done**. Then open **System Settings → Privacy & Security**, scroll to
  the Security section, and click **Open Anyway** for Cove. Confirm with your password.
  The button stays available only for a short time after the first attempt, so retry
  if it is gone.
- **Terminal:** `xattr -dr com.apple.quarantine /Applications/Cove.app`, then open it
  normally.

Right-click → Open no longer bypasses this on recent macOS releases, so use one of the
two steps above.

## Checking a build without publishing

Actions → **Release** → Run workflow, on any branch, with `dry_run` checked. It builds
and packages the app and uploads the files as the `cove-dry-run` artifact. It does not
tag or publish anything.

## SIGNING HOOK

Developer ID signing and notarization are not turned on. Turning them on needs an
Apple Developer account ($99/yr) and these changes:

1. Store a Developer ID Application certificate as a secret. In `release.yml`, add a
   step that imports it into a temporary keychain.
2. Set `CODE_SIGN_IDENTITY` in the job's `env` to `Developer ID Application: <name>
   (<TEAMID>)`. Pass `CODE_SIGN_STYLE=Manual`, `ENABLE_HARDENED_RUNTIME=YES` and
   `OTHER_CODE_SIGN_FLAGS=--timestamp` to `xcodebuild`, and drop
   `CODE_SIGNING_REQUIRED=NO`.
3. After the build and before packaging, notarize the app. Zip it, then run
   `xcrun notarytool submit <zip> --apple-id … --team-id … --password … --wait`.
   Staple the `.app` with `xcrun stapler staple`, so the packaged DMG and zip carry the
   ticket.

`scripts/release/package.sh` already verifies the signature with `codesign --verify`,
so it keeps working once the signing is real.

## Sparkle updates

Owned by the Sparkle thread. `release.yml` calls `scripts/release/update-appcast.sh
<version> <build> <zip> <out-dir>` if the script exists and is executable. It expects
`<out-dir>/appcast.xml` and reads the EdDSA key from the `SPARKLE_PRIVATE_KEY` secret.
The feed URL is `https://github.com/FreezingShock/Cove/releases/latest/download/appcast.xml`.

## Troubleshooting

- **"Nothing to release"** from Prepare: `integration` has no commits beyond `main`.
  Merge feature PRs first.
- **"already released"** from Release: the version was not bumped. Run Prepare release
  again, which takes the next version.
- **Release PR never goes green:** `RELEASE_TOKEN` is missing or lacks write access.
  Without it, CI does not run on the Release PR.
- **"Built app reports …"**: the target's Info.plist does not use `$(MARKETING_VERSION)`
  and `$(CURRENT_PROJECT_VERSION)`. Fix the project settings. Do not change the workflow.
- **Branch `release/vX.Y` already exists:** a previous Prepare run stopped partway.
  Delete the branch and its PR, then run Prepare again.
