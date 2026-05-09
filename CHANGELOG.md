# Changelog

## 0.3.15

Fixing issues in flatpak & testing Sync.

### Fixed
- Reduced startup time when opening large libraries by deferring expensive cleanup work until after launch.
- MSIX packaging now excludes external update checks so Store validation passes.
- Steam Deck D-pad now works in the Flatpak sandbox (`--device=all` permission was missing, blocking SDL from seeing the controller).
- Browser-open during Google Drive Connect now works in both Game Mode (`flatpak-spawn --host`) and Desktop Mode (`QDesktopServices::openUrl`) by granting `org.freedesktop.Flatpak` and `org.freedesktop.portal.Desktop` D-Bus access.
- Google Drive OAuth now goes through the iptvXS gateway again — bundling `.secrets` into the Flatpak source so the gateway API key isn't lost when fetching from git, restoring authentication via the gateway instead of the deleted bundled client.
- "Backup now" no longer freezes the UI — compression and temp-file IO moved to a Qt worker thread.
- Sync error message rewrites Qt's terse "Host requires authentication" into "Google Drive sign-in expired — please log out and back in."
- D-pad on the last channel of Live TV / Movies / Series now wraps back to the category sidebar instead of being a no-op.
- Tone mapping performance fix — disabled mpv's per-frame `hdr-compute-peak` GPU readback that caused periodic micro-freezes during playback on the Steam Deck iGPU. Tone-mapping algorithm choice is unchanged; mpv now uses static peak metadata from the stream.
- mpv demuxer cache bumped from 50 MiB to 128 MiB to absorb network jitter on high-bitrate streams.
- Player HUD auto-hide now actually fires after 3 seconds of idle (was blocked by sub-pixel pointer jitter and a focused-control guard).
- Auto channel sync no longer loops every ~3 minutes when one server stalls — the watchdog now stamps the cycle as complete on timeout, so the next sync is one full interval (24h) away instead of 60 seconds.
- Sidebar reappears after exiting a full-screen video by any path (Escape, controller B, view switch, etc.) — the `videoFullscreen` flag is now reset centrally in the view-change observer instead of relying on every exit path to clean up.

### Added
- Configurable backup folder name in Settings (`iptvXS/backup` default).
- Nested Google Drive folder layout: `iptvXS/sync`, `iptvXS/backup`, `iptvXS/recordings`. Legacy flat folders auto-migrate on first run.
- Compressed database backups (`.db.qcz`).
- "Last backup" timestamp now persists across restarts; "Uploading…" status while a backup is in flight.
- Black text on accent buttons for the Forest, Sunset, and Nord themes (improved contrast).

## 0.2.1

Draft release for Steam Deck and Flatpak improvements.

### Added
- GitHub Action to build the Flatpak bundle.
- Draft release notes in the app metadata.

### Fixed
- Steam Deck game mode controller navigation in the sidebar and content views.
- EPG sync on Flatpak by normalizing XMLTV URLs before fetching.
- VOD poster loading by using the local cache and falling back cleanly to default art.
- Linux app data path handling so files no longer land in a doubled `iptvXS/iptvXS` directory.

### Changed
- Bumped the application version to `0.2.1`.
- Improved the VOD and episode list UI polish.

## 0.2.0

- Initial release with full IPTV viewer functionality.
