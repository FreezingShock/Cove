# Releasing Inlet

Inlet ships from `integration` to `main`. Feature PRs land on `integration`. A release
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
   integration → main merge ships whatever version `Inlet.xcodeproj` holds at that
   point (0.1 build 1, from PR #1). That release is created automatically.

## Each release

1. **Prepare.** Actions → **Prepare release** → Run workflow. Pick `minor` (the
   default, so 0.1 → 0.2), `patch`, or `major`. Type an exact version in `version` to
   override the bump. The workflow:
   - bumps `MARKETING_VERSION` and increments `CURRENT_PROJECT_VERSION` in
     `Inlet.xcodeproj/project.pbxproj`;
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
| `Inlet-<version>.dmg` | Drag-to-Applications disk image, versioned. |
| `Inlet.dmg` | Same DMG under a fixed name. The website's download link uses it: `https://github.com/FreezingShock/Inlet/releases/latest/download/Inlet.dmg`. |
| `Inlet-<version>.zip` | The app bundle, for Sparkle updates and manual downloads. |
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

Releases are signed with a self-signed certificate, which Apple does not trust, so macOS
blocks the first launch of a downloaded copy. Updates that Sparkle installs should not
be quarantined; confirm this on the first real update (see the Mac test checklist). Only a Developer ID build, which is optional, opens without these steps.

- **Finder:** open `Inlet.app`, or the DMG and then the app. macOS says it cannot verify
  the app. Click **Done**. Then open **System Settings → Privacy & Security**, scroll to
  the Security section, and click **Open Anyway** for Inlet. Confirm with your password.
  The button stays available only for a short time after the first attempt, so retry
  if it is gone.
- **Terminal:** `xattr -dr com.apple.quarantine /Applications/Inlet.app`, then open it
  normally.

Right-click → Open no longer bypasses this on recent macOS releases, so use one of the
two steps above.

## Checking a build without publishing

Actions → **Release** → Run workflow, on any branch, with `dry_run` checked. It builds
and packages the app and uploads the files as the `inlet-dry-run` artifact. It does not
tag or publish anything.

## Signing

Every release is signed with one self-signed code-signing certificate. It costs nothing,
and it is the same certificate on every release, so the identity macOS sees for Inlet
doesn't change. That keeps the privacy grants Inlet has. Inlet does not use a paid Apple
Developer account, so releases are not notarized.

Secrets go in **Settings → Secrets and variables → Actions → Repository secrets**. The names
must match exactly.

| Secret | What goes in it |
| --- | --- |
| `CODE_SIGN_P12` | The self-signed certificate and key, base64 encoded. The one-time setup below writes it. |
| `CODE_SIGN_P12_PASSWORD` | The password for that `.p12`. |

The workflow picks one of three modes from the secrets it finds:

| Mode | When | Result |
| --- | --- | --- |
| `self-signed` | `CODE_SIGN_P12` is set. This is the normal release. | Same identity every release. Gatekeeper still blocks the first download. |
| `developer-id` | The Apple secrets are set (optional, see below). | Developer ID signed and notarized. Opens without the Gatekeeper steps. |
| `ad-hoc` | No signing secrets. | A new identity every build. macOS asks for privacy access again. Gatekeeper blocks it. |

### Step by step: one-time setup (self-signed)

1. On your Mac, or any machine with `openssl`, run:
   ```sh
   scripts/release/make-signing-certificate.sh
   ```
   It writes `~/inlet-signing/` with the certificate, the base64 copy and the password.
   The script refuses to overwrite an existing certificate.
2. Add the two secrets with the commands the script prints (`gh secret set …`).
3. Delete the two plain copies it leaves in `~/inlet-signing/`.
4. Save `inlet-code-signing.p12` and its password in a password manager.

**Keep the `.p12` backed up.** It is the app's identity. If it is lost and a new certificate
is made, existing installs can't update to the new build, and macOS asks for privacy access
again. Replacing it is a one-time reset, not a routine step.

To sign local Xcode builds with the same identity, so they keep the same grants, import the
`.p12` into your login keychain and build with `CODE_SIGN_STYLE=Manual CODE_SIGN_IDENTITY="Inlet Release Signing"`.
The script prints the exact command.

### What the workflow does with the self-signed certificate

1. Imports the `.p12` into a temporary keychain on the runner, then deletes the `.p12` file.
2. Builds with `CODE_SIGN_STYLE=Manual`, that identity and hardened runtime off. Hardened
   runtime is only needed for notarization. Its library checks may reject the Sparkle
   framework in a self-signed build, so it stays off.
3. Packages the app into the zip and DMG.
4. Deletes the temporary keychain, even when an earlier step failed.

### Optional: Developer ID and notarization

Only needed if you ever join the paid Apple Developer Program. When the secrets below are set,
the workflow uses a Developer ID certificate, turns on hardened runtime with a secure
timestamp, submits the app to Apple's notary service, and staples the ticket. Nothing in the
normal release needs this.

| Secret | What goes in it |
| --- | --- |
| `MACOS_CERT_P12` | The exported Developer ID Application certificate, base64 encoded. |
| `MACOS_CERT_PASSWORD` | The password you set when you exported the `.p12`. |
| `APPLE_ID` | The Apple ID email for the developer account. |
| `APPLE_TEAM_ID` | The 10-character Team ID. |
| `APPLE_APP_PASSWORD` | An app-specific password for notarization. This is not your Apple ID password. |

If only some of these are set, the run fails on purpose, so a half-configured release never
looks notarized when it is not.

## Sparkle updates

Owned by the Sparkle thread. `release.yml` calls `scripts/release/update-appcast.sh
<version> <build> <zip> <out-dir>` if the script exists and is executable. It expects
`<out-dir>/appcast.xml` and reads the EdDSA key from the `SPARKLE_PRIVATE_KEY` secret.
The feed URL is `https://github.com/FreezingShock/Inlet/releases/latest/download/appcast.xml`.

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
