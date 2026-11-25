# Environment: Termux on Android

You are running inside Termux on Android (aarch64).
Assume the rules below:

- Use `"$TMPDIR"` for temp files.
- Read system paths through `"$TERMUX__PREFIX"`, never through `"$PREFIX"` or `/usr`.

## Where software goes

Treat `"$TERMUX__PREFIX"` as read-only for new software, it belongs to the package manager, not to you.

1. If `pkg install <name>` provides the tool, use `pkg`. Do not build or vendor a copy.

2. Otherwise install user-local, under `~/.local` (XDG layout).

## Building Android apps

Available: JDK and `javac` on `PATH`; SDK at `$ANDROID_HOME`; native `aapt2`, `apksigner`, `android-tools`, `zip`, `keytool`, `clang`, `cmake`, `ninja` from pkg. Gradle is not on `PATH` — use the project's `./gradlew`.

Traps: the SDK's `aapt2`, `split-select` and the SDK's own CMake are x86-64 and cannot exec. Gradle needs `android.aapt2FromMavenOverride=$TERMUX__PREFIX/bin/aapt2` in `$GRADLE_USER_HOME/gradle.properties`.

Native builds: the NDK is a native aarch64 build from the termux-ndk releases (Lzhiyong/termux-ndk), symlinked into `$ANDROID_HOME/ndk/<rev>`. Point `android.ndkVersion` at that revision instead of setting `ndk.dir`; a project pinning another revision must be changed.

## Shizuku

Rish may be usable (Shizuku may be running); check with `RISH_APPLICATION_ID=com.termux timeout 10 rish -c id`. `uid=2000(shell)` means it works — use it for shell-uid work (`pm install`, `pm grant`, `settings put`, `appops`). If it errors or hangs, Shizuku is stopped: ask the user to start it. 

Rish cannot read Termux-private paths (`$TERMUX__PREFIX`, `/data/data/com.termux`)

## Installing APKs

### Interactive install

The OEM installer rejects APKs opened from Termux-private paths. Copy to `/storage/emulated/0` (symlinked as `~/android`), then `termux-open` it.

### Silent install with `pm install`

Stage under `/data/local/tmp`.

```bash
RISH_APPLICATION_ID=com.termux rish -c 'cp /sdcard/Download/app.apk /data/local/tmp/app.apk'
RISH_APPLICATION_ID=com.termux rish -c 'pm install -r /data/local/tmp/app.apk'
RISH_APPLICATION_ID=com.termux rish -c 'rm -f /data/local/tmp/app.apk'
```

