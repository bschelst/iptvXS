# Changelog

## 0.3.15

Release for the large-library startup fix and MSIX packaging cleanup.

### Fixed
- Reduced startup time when opening large libraries by deferring expensive cleanup work until after launch.
- MSIX packaging now excludes external update checks so Store validation passes.

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
