# Auto-updates (Sparkle)

Cove updates itself with [Sparkle 2](https://sparkle-project.org/documentation/). This page covers the one-time setup, the release contract, and how to test.

## How it fits together

| Piece | Where | What it does |
| --- | --- | --- |
| Sparkle package | `Cove.xcodeproj` (SPM, `2.10.1` or newer in 2.x) | The framework |
| `AppUpdater` | `Cove/Updates/AppUpdater.swift` | Starts the updater and exposes "check now" and the auto-check setting |
| Menu item | `Cove/CoveApp.swift` (Cove menu, after About) | "Check for Updates…" |
| Settings block | `Cove/Updates/UpdatesSettingsSection.swift` | Toggle, version, last checked, check button. Drop into a `Form` |
| Feed settings | `Config/Info.plist` | `SUFeedURL`, `SUPublicEDKey`, automatic-check settings |
| Feed builder | `scripts/release/update-appcast.sh` | Makes `appcast.xml` for each release, signed with the EdDSA key |

The feed URL is `https://github.com/FreezingShock/Cove/releases/latest/download/appcast.xml`. Each release attaches its own `appcast.xml`, and the download links point at that release's `Cove-<version>.zip`.

## One-time setup (on your Mac)

Do this once. You need Xcode and the Sparkle package, which Xcode downloads when you open the project.

1. **Open the project** in Xcode and let it resolve the Sparkle package (File › Packages, or just build once).
2. **Find Sparkle's tools.** In the Project navigator, right-click the Sparkle package and choose *Show in Finder*. Go up one folder from `checkouts`. The tools are in `../artifacts/sparkle/Sparkle/bin/`. You can also download `Sparkle-2.10.1.tar.xz` from the [Sparkle releases page](https://github.com/sparkle-project/Sparkle/releases) and use its `bin/` folder.
3. **Generate the key pair** (run once, in the `bin/` folder):
   ```sh
   ./generate_keys
   ```
   The private key goes into your login Keychain. The command prints the public key, which looks like `pfIShU4d…=`.
4. **Put the public key in the app.** Replace `REPLACE_WITH_SPARKLE_PUBLIC_KEY` in `Config/Info.plist` with the printed value and commit it. The public key is safe to commit.
5. **Export the private key for CI**, outside the repo:
   ```sh
   ./generate_keys -x ~/Desktop/sparkle_private_key
   ```
   Then store it as the GitHub Actions secret `SPARKLE_PRIVATE_KEY`:
   ```sh
   gh secret set SPARKLE_PRIVATE_KEY --repo FreezingShock/Cove < ~/Desktop/sparkle_private_key
   ```
   Or paste the file's contents under **Settings › Secrets and variables › Actions**. Then delete the local file: `rm ~/Desktop/sparkle_private_key`.
6. **Back up the private key** in a password manager. If you lose it, existing users can't install updates signed by a new key without a key rotation. See the [Sparkle docs on rotating keys](https://sparkle-project.org/documentation/#rotating-signing-keys).

Never commit the private key. `.gitignore` blocks the common filenames, but check `git status` before every commit.

## Release contract

The release workflow (owned by the release-flow thread) does this on every push to `main`:

1. Builds Release and packages `Cove-<version>.zip` and `Cove-<version>.dmg`.
2. Runs `scripts/release/update-appcast.sh <version> <build> <zip-path> <out-dir>`, with `SPARKLE_PRIVATE_KEY` in the environment.
3. Attaches `appcast.xml` and both archives to the GitHub Release tagged `v<version>`.

Before each release, bump the version in Xcode (`MARKETING_VERSION` for `<version>`, `CURRENT_PROJECT_VERSION` for `<build>`). Sparkle compares the build number, so it must go up on every release. The script stops if the zip's `CFBundleVersion` doesn't match `<build>`.

To check the feed format by hand, run `generate_appcast -h` from the Sparkle `bin/` folder. The script depends on two of its options: `--ed-key-file` and `--download-url-prefix`. If a Sparkle upgrade renames either one, the script will fail loudly, not publish a bad feed.

## Testing an update

1. Build an old version, for example `CURRENT_PROJECT_VERSION = 1`, and run it.
2. Publish a newer build with a higher build number to a test feed, or temporarily lower the old build's number.
3. Quit and relaunch the old build. Sparkle asks for permission only on the second launch by default, but Cove sets `SUEnableAutomaticChecks` to true, so it checks in the background once a day.
4. To force a check now, use **Cove › Check for Updates…**. To reset the daily timer, run `defaults delete com.freezingshock.Cove SULastCheckTime` before launching.
5. Watch **Console.app** and filter for `Sparkle` if something goes wrong.

## Notes

- Cove is not sandboxed, so Sparkle's XPC helpers run as normal processes. The app is also not hardened-runtime, which is fine for the current ad-hoc signed builds. A Developer ID build needs hardened runtime and notarization, which the signing thread will handle.
- Keep Sparkle's `.dSYM` files for crash symbolication.
