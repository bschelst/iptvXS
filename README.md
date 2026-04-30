<p align="center">
  <img src="images/iptvxs_tray.png" alt="iptvXS" width="256" />
</p>

<h1 align="center">iptvXS</h1>

<p align="center">
  <strong>Live TV, VOD & recordings — all in one</strong>
</p>

<p align="center">
  <em>This project is under active development. Expect bugs, incomplete features, and rough edges. I'm still fully testing, and there are a lot of outstanding actions — use at your own risk.</em>
</p>
<p>
I created this app because I was a bit disappointed in the IPTV clients on Linux, SteamOS, and Android TV. Despite there being some good clients available, there are always some kind of issues with them, or you need to pay for basic functionality. On the other hand, managing a large number of channels was also problematic. Hence my attempt to create something better. Of course, at the end it's worse, but I tried :)
  This has been made with a lot of open source software, e.g: QT, mpv, ffmpeg, etc. All credits to all those projects.
</p>

<p align="center">
  <a href="https://github.com/bschelst/iptvXS/releases/latest"><img src="https://img.shields.io/github/v/release/bschelst/iptvXS?style=for-the-badge&color=blue" alt="Latest Release" /></a>
</p>

<p align="center">
  <img src="https://img.shields.io/badge/platform-Linux-blue?logo=linux&logoColor=white" alt="Linux" />
  <img src="https://img.shields.io/badge/platform-Steam%20Deck-1a9fff?logo=steam&logoColor=white" alt="Steam Deck" />
  <img src="https://img.shields.io/badge/platform-Windows-0078D4?logo=windows&logoColor=white" alt="Windows" />
  <img src="https://img.shields.io/badge/license-GPL--3.0-blue" alt="GPL-3.0 License" />
  <img src="https://img.shields.io/badge/Qt-6.5+-41cd52?logo=qt&logoColor=white" alt="Qt 6.5+" />
  <img src="https://img.shields.io/badge/C++-20-00599C?logo=c%2B%2B&logoColor=white" alt="C++20" />
</p>

<p align="center">
  <strong>Author:</strong> Schelstraete Bart &nbsp;|&nbsp;
  <a href="https://iptvxs.schelstraete.org">www.schelstraete.org</a>
</p>

---

## Features

### Live TV & VOD

- **Xtream Codes API** and **M3U playlist** support
- High-quality playback via **libmpv** with hardware-accelerated decoding
- Channel categories with search and filtering
- **Channel Groups** — create custom playlists, add channels via built-in search picker
- **Recently Added** filter — highlights channels added in the last 7 days
- VOD Movies and VOD Series as separate sidebar entries
- Netflix-style horizontal poster rows with category browsing
- Series support with season/episode picker
- **Audio track selection** for multi-language VOD content
- **Picture-in-Picture (PIP)** — draggable floating mini-player for live TV when navigating away
- **Favourites-first sorting** — favourite channels always appear at the top
- Configurable grid layout (1–3 columns) for channel and VOD lists
- Rounded card corners with accent hover borders

### Electronic Programme Guide (EPG)

- XMLTV parser with automatic EPG updates (configurable interval, default 6h)
- Full TV Guide grid with programme details popup
- **Record from EPG** — one-click recording with confirmation dialog
- **EPG recording padding** — configurable start-early / end-late (0–5 minutes)
- Now/Next programme display in the player for live TV
- Vertical scrollbar and keyboard/controller navigation
- Channel search within the guide

### Recording

- Live and scheduled recording via FFmpeg
- **In-player stream recording** — record directly from the video player
- **Record from EPG** with programme title capture
- **Schedule recordings** with custom start time (day, hour, minute picker)
- **EPG padding** — start recording early, end late (configurable in Settings)
- Recordings saved to `~/Videos/iptvXS/` (configurable)
- **Storage quota** (default 2 GB) with visual usage bar
- **Safe filenames** — channel names are sanitized with unique naming
- Delete recordings with confirmation dialog
- **Google Drive upload** with resumable chunked uploads and cross-session resume
- **Retry failed uploads** directly from the Recordings view
- **Auto-delete** local files after successful Google Drive upload
- FFmpeg user-agent header for provider compatibility

### Subtitles

- Automatic subtitle search via OpenSubtitles
- **Built-in subtitle track picker** for embedded subtitles
- Configurable subtitle language (primary + secondary), size, text color, and background
- Subtitle timing adjustment in the player

### Video Enhancement & Player Tuning

- GPU-accelerated video processing presets (Off / Light / Medium / Strong)
- **Debanding** to remove color banding artifacts
- **High-quality scaling** via ewa_lanczossharp with sigmoid upscaling
- **Denoising** via hqdn3d filter for cleaner picture
- **Hardware decoding** modes (Auto Safe / Auto / Software)
- **Deinterlace** toggle for interlaced content
- Pulsing logo animation during stream loading

### Theming

- 7 built-in themes: Midnight, Ocean, Forest, Sunset, Nord, Light, **High Contrast**
- High Contrast theme with `textOnAccent` token for maximum readability
- Consistent accent-aware text across all buttons, badges, and dropdowns
- Theme persists across sessions

### Play History

- Automatic tracking of watched channels, movies, and series
- Browse history sorted by most recent, grouped by type
- Remove individual entries or clear all history
- One-click replay from history

### Steam Deck & Controller Support

- Full **D-pad/controller navigation** throughout the entire UI
- **External controller support** — USB and Bluetooth gamepads via SDL2 HIDAPI
- **D-pad debounce** (120ms) prevents cursor double-jumping
- **GameScope Google Drive auth** — Steam overlay browser integration with hint dialog
- Optimized for Steam Deck's display and input
- **Screensaver inhibition** during video playback
- Available as a **Flatpak** for easy installation
- Works in both Desktop Mode and Game Mode

### Settings & Management

- **Version check** — automatic check for updates via gateway API
- **About section** with current/latest version, author, GitHub link
- **Database statistics** — server, channel, movie, series, recording counts
- **Logo cache management** — auto-prune (30 days), configurable max size (100 MB – 2 GB), clear button
- **Database reset** with full reconnection of all repositories
- **Auto-sync** channels and EPG (configurable interval, default 6 hours)
- Configurable stream buffer time
- Close-to-tray option
- **Application log** with auto-refresh, level filtering, and search

### UI Polish

- **TopBar clock** with blinking colon separator
- Styled hamburger menu icon (not emoji)
- Sidebar separator lines properly isolated
- Card hover borders visible over poster images
- Scroll buttons hidden when content fits
- Copyright headers on all source files

---

## Screenshots

> *Coming soon*

---

## Installation

### Flatpak (Recommended for Linux & Steam Deck)

```bash
# Download from GitHub Releases
wget https://github.com/bschelst/iptvXS/releases/latest/download/iptvxs.flatpak

# Install
flatpak install --user iptvxs.flatpak
```

### Windows

Download `iptvXS-windows-x64.zip` or `iptvXS-setup-x64.exe` from [GitHub Releases](https://github.com/bschelst/iptvXS/releases/latest).

### Build from Source

#### Dependencies

- Qt 6.5+ (Core, Quick, QuickControls2, Sql, Network, Concurrent, OpenGL, Widgets, DBus)
- Qt5Compat.GraphicalEffects (for rounded corner clipping)
- libmpv
- FFmpeg
- SDL2 (Linux only, for controller support)
- CMake 3.22+
- C++20 compiler

#### Build

```bash
git clone https://github.com/bschelst/iptvXS.git
cd iptvXS
cmake -S . -B build -DCMAKE_BUILD_TYPE=Release
cmake --build build --parallel $(nproc)
```

#### Run

```bash
./build/app/iptvXS
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
4. Optionally add an EPG URL (XMLTV format)
5. Sync the server to fetch channels, VOD, and series

---

## Keyboard Shortcuts

| Key | Action |
|-----|--------|
| Space | Play / Pause |
| F / F11 | Toggle fullscreen |
| Escape | Exit player / Exit fullscreen |
| Left / Right | Seek ±10 seconds |
| Up / Down | Volume up / down |
| M | Mute / Unmute |
| PgUp / PgDown | Previous / Next sidebar section |

---

## Architecture

```
iptvXS/
├── app/                    # Qt/QML application
│   ├── qml/               # QML UI files
│   │   ├── views/          # Main views (Channels, VOD, Player, EPG, etc.)
│   │   ├── components/     # Reusable components (Sidebar, TopBar, Dialogs)
│   │   └── themes/         # Theme definitions (7 themes)
│   ├── viewmodels/         # C++ ViewModels (MVVM pattern)
│   └── controller_input_bridge.*  # SDL2 gamepad input (Linux/Steam Deck)
├── core/                   # Core library (no UI dependency)
│   ├── api/                # Xtream Codes & OpenSubtitles clients
│   ├── cache/              # Logo cache manager with auto-prune
│   ├── db/                 # SQLite repositories (14 tables, migrations)
│   ├── gdrive/             # Google Drive OAuth & resumable upload
│   ├── models/             # Data models
│   ├── net/                # HTTP client & speed test runner
│   ├── parser/             # M3U & XMLTV parsers
│   ├── player/             # libmpv wrapper
│   └── recording/          # FFmpeg recording manager
├── tests/                  # Unit tests (GoogleTest)
├── packaging/
│   ├── flatpak/            # Flatpak manifest
│   ├── linux/              # AppStream metainfo, desktop file
│   └── windows/            # Inno Setup installer
└── .github/workflows/      # CI: Flatpak + Windows builds
```

---

## License

[GPL-3.0](LICENSE)

---

## Author

**Schelstraete Bart** — [www.schelstraete.org](https://www.schelstraete.org) — [GitHub](https://github.com/bschelst/iptvXS)

---

## Contributing

Contributions are welcome! Please open an issue or submit a pull request.
