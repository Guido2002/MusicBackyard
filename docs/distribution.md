# Release channels and automatic updates

The source repository is public at <https://github.com/Guido2002/MusicBackyard>. Direct Android releases use GitHub Releases and two independent public feeds:

- Stable: <https://raw.githubusercontent.com/Guido2002/MusicBackyard/update-channels/stable.json>
- Beta: <https://raw.githubusercontent.com/Guido2002/MusicBackyard/update-channels/beta.json>

The feeds live on the `update-channels` branch. They contain public release metadata, never credentials. App builds have these endpoints configured by default; no server or app login is required.

GitHub's raw-file CDN can briefly retain the preceding feed or a cached 404 after a channel's first publication. Allow several minutes for propagation, then retry the check. The workflow advances the Git reference only after the signed release assets are published.

## User flow

Open **Meer → Profiel → App-updates** to select **Stabiel** or **Bèta**, manually check, or change automatic wifi downloads. Release builds check at startup, on resume and while open, with a six-hour successful-check interval. Manual checks bypass the interval. Downloads are automatic on wifi by default in production, configurable in the app, and off by default in debug builds. Android always requires system confirmation before installation; nothing installs silently.

Switching channels never downgrades an installed version. After switching from a newer beta to stable, the next stable build with a higher Android build number will be offered. Cancellation prevents automatically retrying that same build; manual download remains available. Validated downloads and cached channel metadata survive restarting the app. Background execution while the OS terminates/suspends the process is not promised; checks resume when the app returns.

Initial installation: use the signed APK from GitHub Releases. Earlier debug APKs used a different certificate and cannot be overwritten by this production key. Back up music through **Meer → Back-up opslaan** before replacing such an installation; restore the backup after installing the production APK. Do not delete a debug installation until its backup is safely saved. Future production releases retain the same application ID and certificate and update in place.

## Automatic stable releases

Every push to `main` that changes app source, Android/iOS configuration, assets, dependencies, release tooling or the release workflow runs the Android releases pipeline. Documentation and review artifacts alone do not trigger it. One push produces one stable release containing its completed feature/fix commits.

The version is derived from the highest stable `vX.Y.Z` tag, ignoring beta tags:

- `fix(scope): description` and ordinary app commits increment the patch number.
- `feat(scope): description` increments the minor version and resets the patch number.
- `feat!:` / `fix!:` or a `BREAKING CHANGE:` footer increments the major version.
- When a push contains multiple commits, the highest required increment is applied once.

Release notes come from `docs/releases/<version>.txt` when present; otherwise feature/fix commit descriptions provide them automatically. The release build uses the computed version directly, without creating a version-bump commit on `main`. Android build numbers continue to share the same sequence across automatic/manual/beta runs.

The workflow checks formatting, analyzes, tests, signs, verifies the actual APK, publishes the GitHub Release and Git tag, and then advances the stable feed. No separate tag push or manual dispatch is needed for a feature/fix. Failed checks stop publication. Completed releases are immutable; deliberately rerunning an already published automatic run chooses the next stable version.

Concurrent releases wait in order using `queue: max`, rather than replacing an older pending feature/fix run. GitHub supports up to 100 pending runs per concurrency group. See [GitHub concurrency documentation](https://docs.github.com/en/actions/how-tos/write-workflows/choose-when-workflows-run/control-workflow-concurrency). Every completed feature/fix should be validated, committed and pushed; the repository's `AGENTS.md` records this working agreement.

## Manual/beta releases

Use **Actions → Android releases → Run workflow** on `main`:

1. Add Dutch release notes at `docs/releases/<version>.txt` and push the reviewed code to `main`.
2. Choose a unique semantic version, e.g. `1.1.3` for stable or `1.1.3-beta.1` for beta.
3. Choose the matching track. Stable versions must not have a prerelease suffix; beta versions must have one.
4. Run the workflow. It analyzes/tests, signs a direct APK and a Play bundle, verifies actual APK identity/version/certificate/SHA-256, stages assets in a draft release, publishes, and advances only the selected feed atomically.

Alternatively push a version tag on a commit reachable from `main`:

```sh
git tag v1.1.3-beta.1
git push origin v1.1.3-beta.1
```

Tag suffixes determine the track. Android build numbers are `100000 + GITHUB_RUN_NUMBER` for this single release workflow, so stable and beta share a sequence independent of version names. Existing published builds cannot be replaced with changed content. Feeds refuse lower build numbers and use fast-forward updates rather than forced pushes. Concurrent release jobs are serialized.

The direct APK and manifest appear in GitHub Releases. Signed Play AABs are retained as workflow artifacts for 30 days and can be uploaded to the appropriate Google Play test/production track. There is no automatic Play Store publication without a configured Play Console account/service identity. The app uses the official Play in-app update API for Play-owned installs and never replaces them through the APK flow.

## Signing and recovery

Production key material is deliberately excluded from Git:

- Workspace: `.release/signing/`
- Private backup: `~/Library/Application Support/MusicBackyard/Release Signing/`
- Local Gradle properties: `android/key.properties` (ignored)

The four GitHub Actions secrets are `ANDROID_KEYSTORE_BASE64`, `ANDROID_STORE_PASSWORD`, `ANDROID_KEY_ALIAS`, and `ANDROID_KEY_PASSWORD`. They were encrypted using the repository's Actions public key. No personal access token is stored in the app or the repository; publication uses the job-scoped `GITHUB_TOKEN` with repository contents permission.

Keep an independent private backup of the signing directory. GitHub will not reveal decrypted secret values later. The public certificate fingerprint is recorded in `config/android-release-certificate.sha256`; the verifier refuses a debug-signed or differently signed APK. The direct updater currently requires the exact same signer set; key rotation needs a separately tested migration.

For a fresh development machine, restore the private signing backup and point `storeFile` in `android/key.properties` at its `.p12`. The helper `python3 tool/setup_release_signing.py` creates a key only when none exists; it never overwrites existing material. `tool/configure_github_signing.py` requires PyNaCl and uses an existing git credential helper or `GH_TOKEN` to encrypt/upload secrets without printing them. Do not regenerate the key for an existing production app.

## Download and installation security

Initial APK URLs are restricted to this repository's GitHub release path. TLS certificate validation remains enabled. GitHub's necessary release-asset redirect is followed only to the exact HTTPS host `release-assets.githubusercontent.com`, with a bounded hop count and no credentials/nonstandard port. Other custom HTTPS download hosts retain the no-redirect policy. Every redirect is checked before making the next request.

The app validates platform, distribution, selected track, semantic version, positive Android build, size (maximum 500 MiB), release notes and SHA-256 before offering an update. It streams to private cache, enforces size while receiving and removes failed downloads. Before handoff, Dart checks size/hash again; native Android rechecks hash, cryptographic APK signatures, application ID, actual version and installed signer. FileProvider exposes only the private update-cache directory. Android owns permission, confirmation, cancellation and final installation.

## Verify live feeds

```sh
dart run tool/check_update_channel.dart stable --download
dart run tool/check_update_channel.dart beta --download
```

This exercises the same HTTPS/redirect policy and hash validation as the app. Release automation tests also cover rollback rejection and preserving the other channel during publication.

## Build overrides and other platforms

`UPDATE_REPOSITORY`, `UPDATE_ENDPOINT`, `UPDATE_BETA_ENDPOINT`, `UPDATE_DOWNLOAD_HOSTS`, `UPDATE_INTERVAL_HOURS`, `RELEASE_TRACK` and `UPDATE_AUTO_DOWNLOAD_WIFI` can be supplied using `--dart-define`. Custom endpoints must be HTTPS and trusted download hosts must be explicit.

For iOS configure `APP_STORE_URL` with the real `https://apps.apple.com/...` listing. The app opens that listing and never installs arbitrary IPA files. Apple account/signing and an App Store record were not supplied; iOS release publication and automatic App Store version lookup are outside this configured Android release pipeline.

Primary references: [GitHub release assets](https://docs.github.com/en/rest/releases/assets), [GitHub workflow syntax](https://docs.github.com/en/actions/writing-workflows/workflow-syntax-for-github-actions), [Android FileProvider](https://developer.android.com/reference/androidx/core/content/FileProvider), [Google Play in-app updates](https://developer.android.com/guide/playcore/in-app-updates).
