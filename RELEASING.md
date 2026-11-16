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

Releases built without the signing secrets are ad-hoc signed, so macOS blocks the first
launch. Releases built with the secrets are notarized and open without these steps.

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

## Signing and notarization

The release workflow signs Inlet with a Developer ID Application certificate, sends it to
Apple for notarization, and staples the ticket to the app before the app is zipped and put
in the DMG. This turns on by itself once the five secrets below exist. Until then, the
release builds ad-hoc signed and the signing steps skip. If only some of the secrets are
set, the run fails on purpose, so a half-configured release never looks signed.

Secrets go in **Settings → Secrets and variables → Actions → Repository secrets**. The names
must match exactly.

| Secret | What goes in it |
| --- | --- |
| `MACOS_CERT_P12` | The exported Developer ID Application certificate, base64 encoded (step 5 below). |
| `MACOS_CERT_PASSWORD` | The password you set when you exported the `.p12`. |
| `APPLE_ID` | The Apple ID email for the developer account. |
| `APPLE_TEAM_ID` | The 10-character Team ID. |
| `APPLE_APP_PASSWORD` | An app-specific password for notarization (step 6 below). This is not your Apple ID password. |

### Step by step: one-time setup

You need the Apple Developer Program ($99/yr). The steps below are the ones to follow.

1. **Enroll.** Go to `developer.apple.com/programs`, choose **Enroll**, and sign in with the
   Apple ID you want to use. Pick **Individual**, then pay the $99 fee. Apple can take a day
   or two to approve the account. You can do steps 2 to 4 once it is approved.
2. **Find your Team ID.** On `developer.apple.com`, open **Account → Membership details**.
   Copy the 10-character Team ID into `APPLE_TEAM_ID`.
3. **Create the certificate.** The easiest route is Xcode: **Settings → Accounts**, select
   your Apple ID, click **Manage Certificates**, then **+** and **Developer ID Application**.
   Xcode puts the certificate and its private key in your login keychain. Only the account
   holder can create this certificate type, which is you for an individual account.
4. **Export it.** Open **Keychain Access**, go to **My Certificates**, and find
   **Developer ID Application: Your Name (TEAMID)**. Click the arrow beside it so the private
   key shows under the certificate. Select both rows, right-click, choose **Export 2 items…**,
   and save it as `DeveloperID.p12`. Set a strong password when asked. That password is
   `MACOS_CERT_PASSWORD`. If you export only the certificate and leave out the key, signing
   fails in CI.
5. **Encode it for GitHub.** In Terminal, run
   `base64 -i ~/Desktop/DeveloperID.p12 | pbcopy`. Paste the clipboard into `MACOS_CERT_P12`.
   Then delete `DeveloperID.p12` from the Desktop and empty the Trash. Keep the password in a
   password manager.
6. **Make an app-specific password.** Go to `appleid.apple.com`, open **Sign-In and Security
   → App-Specific Passwords**, click **+**, and name it `Inlet notarization`. Copy the password
   into `APPLE_APP_PASSWORD`. You can only see it once.
7. **Set `APPLE_ID`** to the Apple ID email you used in step 1.
8. **Add all five secrets** under the repository's **Actions** secrets. Repository secrets
   survive the repo rename from Cove to Inlet, so you do not need to add them again.
9. **Test it without publishing.** Once the Release workflow is on `main` (after the first
   deploy), go to **Actions → Release → Run workflow**, pick `main`, and tick `dry_run`. The
   run signs and notarizes the app and uploads `inlet-dry-run`. Download it, open the DMG, drag
   Inlet to Applications, and launch it. You should see no Gatekeeper warning. You can also run
   `spctl --assess --type execute -vv /Applications/Inlet.app`. It should report
   `source=Notarized Developer ID`.

If notarization fails with a message about an agreement, sign in at `developer.apple.com`
and accept the updated agreement. Then re-run the workflow.

### Renewing

A Developer ID certificate lasts five years. When it expires, create and export a new one,
then replace `MACOS_CERT_P12` and `MACOS_CERT_PASSWORD`. Nothing else changes.

### What the workflow does with the secrets

1. Imports the `.p12` into a temporary keychain on the runner and deletes the `.p12` file.
2. Builds with `CODE_SIGN_STYLE=Manual`, the Developer ID identity, hardened runtime and a
   secure timestamp.
3. Checks that the app is signed with a Developer ID Application certificate.
4. Zips the app and submits it to Apple with `notarytool --wait`. If Apple does not return
   `Accepted`, the run fails and prints the notarization log.
5. Staples the ticket to the `.app` and checks it with `stapler validate` and `spctl`.
6. Packages the stapled app into the zip and DMG, as before.
7. Deletes the temporary keychain, even when an earlier step failed.

Notarizing the DMG itself is not needed. The app inside is stapled, so Gatekeeper accepts it.

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
