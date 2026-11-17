# Contributing to Inlet

Inlet uses a two-branch flow:

- `integration` is where all work lands. Every feature PR targets it.
- `main` is the release branch. Only nate merges `integration` into `main`, when he deploys. Never open a PR into `main`.

## Workflow

1. Branch from the latest `integration`:
   ```sh
   git fetch origin
   git switch -c my-feature origin/integration
   ```
2. Make one focused change per branch.
3. Open a PR with **base `integration`**.
4. Enable **auto-merge** on the PR. It merges into `integration` once the `build` check passes.
5. Delete your branch after it merges.

## PR size

- Keep PRs small. Aim for under about 400 changed lines, not counting generated files.
- If a feature is bigger, split it into stacked PRs. Each PR must build on its own.
- For a stacked PR, base it on the previous PR's branch. Once the previous PR lands, change this PR's base to `integration` **before** deleting the old branch. Deleting a base branch closes the PR.

## Versions and changelog

- Don't bump `MARKETING_VERSION` or `CURRENT_PROJECT_VERSION`, and don't edit `CHANGELOG.md`, in a feature PR. The **Prepare release** workflow does both in its own PR. See [RELEASING.md](RELEASING.md).
- Write PR titles as you want them to read in the changelog. The title becomes the changelog entry.

## Conflicts

- Keep your branch current by merging `integration` into it (`git merge origin/integration`).
- Rebase only a branch nobody else has pulled. Never force-push over someone else's work.
- Resolve conflicts on your own branch. Never edit `integration` directly.
- Don't reformat files you aren't otherwise changing. Formatting-only diffs cause conflicts for everyone.
- If your change touches an area another open PR is changing (check the PR's files list), leave a comment on that PR before you push.

## CI

The `build` check runs on every PR into `integration`, on every push to it, and on every merge queue run. It runs `xcodebuild build` with Xcode 26.6 on the `macos-26` runner, plus tests once a unit-test target exists. It must pass before a PR merges.

- **Every PR runs the full build,** including docs and website PRs. Don't rely on a skipped check to pass. A job-level skip did not let docs PRs merge, so the build now runs on every PR.
- **Superseded runs are cancelled.** A new push to a PR cancels that PR's run in progress. A newer push to `integration` cancels the older one.
- **The `changes` job is informational.** It reports which paths changed, and it doesn't gate the build.

Before you push app changes, build locally. Use the same flags CI uses so the local run matches:

```sh
xcodebuild build -project Inlet.xcodeproj -scheme Inlet -configuration Debug -destination 'platform=macOS' COMPILER_INDEX_STORE_ENABLE=NO CODE_SIGNING_ALLOWED=NO
```
