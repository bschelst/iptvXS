<p align="center">
  <img src="images/iptvxs_tray.png" alt="iptvXS" width="256" />
</p>

<h1 align="center">iptvXS</h1>

<p align="center">
  <strong>Live TV, VOD & recordings — all in one</strong>
</p>

<p align="center">
  <img src="https://img.shields.io/badge/status-unstable%20%2F%20alpha-orange?style=for-the-badge" alt="Unstable" />
</p>

<p align="center">
  <img src="https://img.shields.io/badge/platform-Linux-blue?logo=linux&logoColor=white" alt="Linux" />
  <img src="https://img.shields.io/badge/platform-Steam%20Deck-1a9fff?logo=steam&logoColor=white" alt="Steam Deck" />
  <img src="https://img.shields.io/badge/platform-Windows-0078D4?logo=windows&logoColor=white" alt="Windows" />
  <img src="https://img.shields.io/badge/license-GPL--3.0-blue" alt="GPL-3.0 License" />
  <img src="https://img.shields.io/badge/Qt-6.5+-41cd52?logo=qt&logoColor=white" alt="Qt 6.5+" />
  <img src="https://img.shields.io/badge/C++-20-00599C?logo=c%2B%2B&logoColor=white" alt="C++20" />
</p>

> **Warning:** This project is in **early alpha** and under heavy active development. Expect breaking changes, incomplete features, and bugs. Not recommended for production use. I still need to do a lot, sorry.
---

## Features

### Live TV & VOD

- **Xtream Codes API** and **M3U playlist** support
- High-quality playback via **libmpv** with hardware-accelerated decoding
- Channel categories with search and filtering
- **Channel Groups** — create custom playlists, add channels via built-in search picker
- **Recently Added** filter — highlights channels added in the last 7 days
- VOD movie playback with automatic subtitle fetching
- Series support with season/episode picker
- **Audio track selection** for multi-language VOD content
- **Picture-in-Picture (PIP)** — video continues in a floating mini-player when navigating away
- Configurable grid layout (1–4 columns) for channel and VOD lists

### Electronic Programme Guide (EPG)

- XMLTV parser with automatic EPG updates
- Full TV Guide grid with programme details
- Schedule-based recording from the EPG

### Recording

- Live and scheduled recording via FFmpeg
- **In-player stream recording** — record directly from the video player
- **Schedule recordings** with custom start time (day, hour, minute picker)
- Recordings saved to `~/Videos/iptvxs/` (configurable)
- **Storage quota** with visual usage bar
- **Safe filenames** — channel names are sanitized with unique naming to prevent overwrites
- Delete recordings with confirmation and file cleanup
- **Google Drive upload** with resumable chunked uploads and cross-session resume
- **Retry failed uploads** directly from the Recordings view
- **Auto-delete** local files after successful Google Drive upload
- **Stale recording cleanup** — orphaned "recording" states are resolved on app restart

### Subtitles

- Automatic subtitle search via OpenSubtitles
- **Built-in subtitle track picker** for embedded subtitles
- Configurable subtitle language, size, text color, and background
- Subtitle timing adjustment in the player

### Video Enhancement & Player Tuning

- GPU-accelerated video processing presets (Off / Light / Medium / Strong)
- **Debanding** to remove color banding artifacts
- **High-quality scaling** via ewa_lanczossharp with sigmoid upscaling
- **Denoising** via hqdn3d filter for cleaner picture on noisy IPTV streams
- **Hardware decoding** modes (Auto Safe / Auto / Software)
- **Deinterlace** toggle for interlaced content

### Theming

- 7 built-in themes: Midnight, Ocean, Forest, Sunset, Nord, Light, **High Contrast**
- High Contrast theme with yellow accent on black for maximum readability
- Theme persists across sessions

### Play History

- Automatic tracking of watched channels, movies, and series
- Browse history sorted by most recent
- Remove individual entries or clear all history
- One-click replay from history

### Steam Deck & Controller Support

- Full **D-pad/controller navigation** throughout the entire UI
- Optimized for Steam Deck's display and input
- **Screensaver inhibition** during video playback
- Available as a **Flatpak** for easy installation
- Works in both Desktop Mode and Game Mode

### Channel Logo Caching

- Automatic background download and local caching of channel logos
- SHA1-based filenames with concurrent downloads (4 parallel)
- Reduces bandwidth and improves UI responsiveness

### Other Features

- Favorites system with easy add/remove
- Stream speed testing
- System tray integration with minimize-to-tray option
- **Close confirmation** when recordings or uploads are active
- Per-server channel synchronization with **auto-sync watchdog** (recovers from stalled syncs)
- Configurable stream buffer time
- Automatic stream reconnection on network drops
- **Application logging** with in-app log viewer

---

## Screenshots

> *Coming soon*

---

## Installation

### Flatpak (Recommended)

```bash
# Install from a local bundle
flatpak install --user iptvxs.flatpak
```

### Build from Source

#### Dependencies

- Qt 6.5+ (Core, Quick, QuickControls2, Sql, Network, Concurrent, OpenGL, Widgets, DBus)
- libmpv
- FFmpeg
- CMake 3.22+
- C++20 compiler

#### Build

```bash
git clone https://github.com/bschelst/iptvXS.git
cd iptvxs
cmake -S . -B build -DCMAKE_BUILD_TYPE=Release
cmake --build build --parallel $(nproc)
```

#### Run

```bash
./build/app/iptvXS
```

### AppImage

```bash
cd packaging/linux
./build-appimage.sh
```

---

## Steam Deck Setup

1. Install the Flatpak in Desktop Mode
2. Add **iptvXS** as a non-Steam game in Steam
3. Configure Steam Input (recommended layout):

| Controller | Action |
|-----------|--------|
| D-pad | Navigate lists and grids |
| A button | Select / Play |
| B button | Go back |
| L1 / R1 | Previous / Next section |
| Left stick | Scroll |

---

## Adding a Server

1. Go to **Servers** in the sidebar
2. Click **Add Server**
3. Enter your Xtream Codes credentials (server URL, username, password) or M3U playlist URL
4. Sync the server to fetch channels, VOD, and series

---

## Keyboard Shortcuts

| Key | Action |
|-----|--------|
| Space | Play / Pause |
| F | Toggle fullscreen |
| F11 | Toggle fullscreen |
| Escape | Exit player / Exit fullscreen |
| Left / Right | Seek ±10 seconds |
| Up / Down | Volume up / down |
| M | Mute / Unmute |
| PgUp / PgDown | Previous / Next sidebar section |

---

## Architecture

```
iptvxs/
├── app/                    # Qt/QML application
│   ├── qml/               # QML UI files
│   │   ├── views/          # Main views (Channels, VOD, Player, EPG, etc.)
│   │   ├── components/     # Reusable components (Sidebar, Dialogs)
│   │   └── themes/         # Theme definitions
│   └── viewmodels/         # C++ ViewModels (MVVM pattern)
├── core/                   # Core library (no UI dependency)
│   ├── api/                # Xtream Codes & OpenSubtitles clients
│   ├── cache/              # Logo cache manager
│   ├── db/                 # SQLite repositories
│   ├── gdrive/             # Google Drive OAuth & resumable upload
│   ├── models/             # Data models
│   ├── net/                # HTTP client & speed test
│   ├── parser/             # M3U & XMLTV parsers
│   ├── player/             # libmpv wrapper
│   └── recording/          # FFmpeg recording manager
├── tests/                  # Unit tests (GoogleTest)
└── packaging/              # Flatpak, AppImage, desktop files
```

---

## License

[GPL-3.0](LICENSE)

---

## Contributing

Contributions are welcome! Please open an issue or submit a pull request.
