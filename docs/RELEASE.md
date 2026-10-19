# Build and release Suwar

Source repository: [HamzaMPSY/suwar](https://github.com/HamzaMPSY/suwar). This document covers local artifacts and the checked-in [Android APK workflow](../.github/workflows/android-apk.yml). Hosted execution is verified through its actual Actions run; adding the workflow alone does not establish a successful hosted build. Web hosting and Play Store publishing are separate.

## Toolchain and checks

The project was developed with Flutter 3.38.5 and Dart 3.10.4. Use a compatible Flutter installation, Android SDK and **JDK 17**. Check that Flutter/Gradle resolve the intended JDK; an inherited Java 11 installation is insufficient for the current Android build. Inspect the environment with:

```sh
flutter --version
flutter doctor -v
flutter pub get
flutter analyze
flutter test
```

Commit `pubspec.lock` with application source so dependency resolution is reproducible. Use the project’s SDK constraints; upgrading Flutter, Dart or dependencies requires fresh verification.

## Build the web app

```sh
flutter build web --release --no-web-resources-cdn --no-wasm-dry-run
python3 -m http.server 7357 --bind 127.0.0.1 --directory build/web
```

Open `http://127.0.0.1:7357`. The output is `build/web/`; deploy that directory’s contents, not the Flutter source tree.

The build includes local Quran text, fonts and renderer resources. Serving those assets successfully on the first load is still necessary. Browser storage belongs to its origin/profile, and changing a hosting domain does not migrate existing local progress. Audio streaming still contacts the recitation provider.

### When the hosting destination is known

1. Choose the actual repository, hosting provider and URL with the owner.
2. For a site at a subpath, build with its exact leading/trailing-slash base path: `flutter build web --release --base-href /chosen-path/ --no-web-resources-cdn --no-wasm-dry-run`.
3. Configure static asset serving and navigation fallback to `index.html` where required by the host.
4. Check the deployed URL for fonts, Quran text, audio connectivity, responsive layout, RTL navigation and browser persistence.
5. Test an upgrade with the host’s cache behavior. During investigation, distinguish an old service-worker/cache response from the new build.
6. After the owner provides the destination, configure the remote, verify the resulting build and publish within the authorized scope.

The supplied GitHub repository hosts the source and Android build workflow. No web deployment target is configured by the APK workflow.

## Build an Android APK

For a connected device matching the current development target:

```sh
flutter build apk --release --target-platform android-arm64
```

Output: `build/app/outputs/flutter-apk/app-release.apk`.

For separate architecture-specific APKs:

```sh
flutter build apk --release --split-per-abi
```

Use an APK matching the device architecture. ARM64 alone does not cover every Android device.

### GitHub Actions APK download

[Android APK](https://github.com/HamzaMPSY/suwar/actions/workflows/android-apk.yml) runs on pushes to `main`, pull requests targeting `main`, and manual **Run workflow** requests. It uses hosted Ubuntu 24.04, Flutter 3.38.5, JDK 17 and `flutter pub get --enforce-lockfile`, then analyzes, tests and builds the release ARM64 APK. Superseded runs are cancelled; the build has a 30-minute timeout and publication has a 10-minute timeout.

The workflow pins its action versions to verified commit SHAs. The build retains `contents: read`; only the separate publisher receives `contents: write`. Checkout does not persist credentials, and publication uses the job token without new secrets or signing keys. Workflow-scoped Gradle options cap its heap at 3 GiB, Kotlin daemon heap at 1 GiB and workers at 2; the larger local-development Gradle configuration stays unchanged. The optional native JVM regression script depends on locally populated compiler caches and is not part of this clean-runner workflow; the Dart regression suite runs in full.

Successful pushes to `main` and manual runs of `main` in `HamzaMPSY/suwar` publish a [GitHub Release](https://github.com/HamzaMPSY/suwar/releases/latest). Pull requests and manual runs on other branches only build artifacts. Download the [latest APK directly](https://github.com/HamzaMPSY/suwar/releases/latest/download/suwar-pixel-arm64-development-signed.apk); public release assets do not require an Actions artifact ZIP or GitHub sign-in. Each release also includes `SHA256SUMS` and `BUILD_INFO.json`.

The publisher downloads the exact successful build artifact by ID, verifies its checksum, size, source commit, repository and workflow run, then uploads all three files to a draft before publishing it as **Latest**. Tags combine the app version with workflow run number and publication attempt, for example `v0.6.1-build.2.1`; the title retains the complete app version, such as `0.6.1+7`. The tag targets the exact built commit. Existing tags and release assets are never overwritten or moved. Rerunning a failed publisher uses a new attempt tag and can reuse the original successful build artifact. Interrupted uploads may leave an unpublished draft for the repository owner to inspect or delete. Published release assets remain available until the owner removes them; Actions artifact retention is separate.

For PR builds, other branches, or the original build artifact:

1. Open **Actions → Android APK** and select a successful run, or choose **Run workflow** for a manual build.
2. Under **Artifacts**, download `suwar-pixel-arm64-development-signed-<run>-<attempt>` and extract the ZIP. Artifact downloads require signing in to GitHub with an account that has access to the repository, including for public repositories.
3. The ZIP contains `suwar-pixel-arm64-development-signed.apk`, `SHA256SUMS` and `BUILD_INFO.json`. Metadata records the source commit, app/toolchain versions, APK size, signing status and SHA256. Artifacts are retained for 14 days.
4. Verify from the extracted directory with `sha256sum -c SHA256SUMS` on Linux, or `shasum -a 256 suwar-pixel-arm64-development-signed.apk` on macOS and compare the recorded digest.
5. Install only on an ARM64 Android device, subject to the signing compatibility below. A workflow run builds an artifact; physical-device behavior still needs its own verification.

**This is a development-signed APK.** GitHub's fresh runner creates its own debug certificate, which generally differs from the certificate used on the developer's Pixel. The same package name and version do not make those signatures interchangeable. `adb install -r` succeeds only when Android accepts the signing identity and version; otherwise preserve the installed app and its data. Do not uninstall or clear storage to bypass a signature mismatch. A durable shared signing identity is a separate owner-controlled decision; no private key or keystore is uploaded with the artifact.

### Signing status

**The current release build uses the development/debug signing configuration** in [android/app/build.gradle.kts](../android/app/build.gradle.kts). Release mode optimizes the application; it does not make this configuration a production-signed release.

Before production distribution, establish the application identity, owner-controlled signing key and secure signing configuration. Keep keystores, passwords and local signing properties outside version control. Preserve the signing identity for updates. Rebuilding with a different debug key or switching to a new production certificate can prevent replacement of an existing installation; plan migration and backup before changing certificates.

Do not treat a locally built development-signed APK as a store-ready artifact. iOS signing and distribution have not been validated.

### Verify the actual APK

```sh
adb devices
adb install -r build/app/outputs/flutter-apk/app-release.apk
```

`-r` requests an update preserving application data when package identity and signing are compatible. Do not uninstall or clear storage to bypass an update failure on a device containing personal progress.

Check the installed version and exercise the actual release on an available device:

- Read and search Quran text; reopen a saved reading position.
- Create, rename, memorize and opt in a passage; verify edits and overlaps.
- Confirm the chosen clock policy, current prayer, date rollover and reminder coverage.
- Grant/deny notification access; test a reminder and its currently eligible targets.
- Download one surah, restart, and play the cache without network access.
- Export a backup; validate preview/cancel without replacing live personal data.
- Check large text, the on-screen keyboard, RTL actions and accessibility navigation.

Record which checks were actually executed. Successful compilation or installation alone does not verify these behaviors.

## Source-control and publication hygiene

Keep source, `pubspec.lock`, tests, curated documentation, content provenance and intended design sources. Review staged files before the first commit or publication.

Exclude generated builds/caches, local SDK paths, device logs, temporary browser output, personal backup JSON, downloaded audio, signing credentials and unrelated screenshots. Large design/evidence archives should be deliberate repository content, with sensitive/local-machine details reviewed before publication.

Do not commit user progress or an exported personal backup as a fixture. Use explicitly synthetic data for examples.

## Release record

For each release, record the version/build number, source revision, Flutter version, checks run, artifact SHA256, signing status and known limitations. Update `pubspec.yaml` version deliberately before distribution.

### 0.6.1+7 — October 19, 2026

Western digits throughout app-owned presentation, correctly ordered ranges in Arabic text, and Morocco's timestamp-aware UTC correction. Primary sources and future maintenance are documented in [time-zone handling](TIME_ZONES.md).

| Check | Result |
| --- | --- |
| Flutter tests | 131 passed; includes all 6,214 source verse-marker checks |
| Static analysis | Clean |
| Native widget clock regression | JVM cutoff, history, future dates and Western digits passed |
| Browser review | Actual Home, passages, reader and prayer screens inspected; no page errors |
| Web / Android ARM64 builds | Passed with Flutter 3.38.5 and JDK 17 |
| APK identity | `com.suwar.suwar`, version `0.6.1`, code `7`, minimum SDK 24 |
| APK size | 21,705,963 bytes |
| Signing | Development/debug certificate; not store signing |

APK SHA256:

```text
b417e94cee1e760b5ae153df5c3869387ba84e5effa79b8e77d77b24d13a2ff0
```

The compiled APK is generated under `build/app/outputs/flutter-apk/app-release.apk` and excluded from Git. Fresh physical-device interaction and notification delivery checks for this patch are pending. Browser screenshots use illustrative local data, and the native JVM check does not substitute for device testing.

To repeat the native clock check after an Android build has populated the Gradle compiler cache, use `python3 test/native/check_widget_clock.py` with Python 3 and JDK 17 (`JAVA_HOME` set on non-macOS systems).


Licensing decisions remain with the owner. Preserve [Quran provenance](../assets/quran/warsh-README.md), [audio attribution](../assets/audio/PROVENANCE.md) and [font notices](../assets/fonts/Amiri-OFL.txt); do not add a blanket application license that overrides third-party terms.
