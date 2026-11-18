# Changelog

## 1.0.1 — 2026-11-18

- Security: no longer falls back to shared /tmp when `$XDG_RUNTIME_DIR` is
  unset. The daemon now refuses to run unless the runtime dir is a real
  directory owned by the user and not group/world-writable.
- Security: every file the daemon writes (status, pidfile, config, state) is
  replaced atomically through an exclusive `O_NOFOLLOW` temp file, so a
  symlink at one of those paths is replaced instead of written through.
- Regression tests for both.

## 1.0.0 — 2026-11-18

- First release: per-workspace muting, "hear everywhere" exceptions per app,
  global on/off, notification with a one-click exception, bar widget and panel.
- English and French.
