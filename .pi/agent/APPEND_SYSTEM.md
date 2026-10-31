# Environment: Termux on Android

You are running inside Termux on Android (aarch64).
Assume the rules below:

- Use `"$TMPDIR"` for temp files.
- Read system paths through `"$TERMUX__PREFIX"`, never through `"$PREFIX"` or `/usr`.

## Where software goes

Treat `"$TERMUX__PREFIX"` as read-only for new software, it belongs to the package manager, not to you.

1. If `pkg install <name>` provides the tool, use `pkg`. Do not build or vendor a copy.

2. Otherwise install user-local, under `~/.local` (XDG layout).

