<p align="center">
  <img src="images/iptvxs_logo.png" alt="iptvXS" width="128" />
</p>

<h1 align="center">iptvXS</h1>

<p align="center">
  <strong>A modern, cross-platform IPTV viewer built with Qt6 and libmpv</strong>
</p>

<p align="center">
  <img src="https://img.shields.io/badge/platform-Linux-blue?logo=linux&logoColor=white" alt="Linux" />
  <img src="https://img.shields.io/badge/platform-Steam%20Deck-1a9fff?logo=steam&logoColor=white" alt="Steam Deck" />
  <img src="https://img.shields.io/badge/license-MIT-green" alt="MIT License" />
  <img src="https://img.shields.io/badge/Qt-6.5+-41cd52?logo=qt&logoColor=white" alt="Qt 6.5+" />
  <img src="https://img.shields.io/badge/C++-20-00599C?logo=c%2B%2B&logoColor=white" alt="C++20" />
</p>

---

## Features

### Live TV & VOD

- **Xtream Codes API** and **M3U playlist** support
- High-quality playback via **libmpv** with hardware-accelerated decoding
- Channel categories with search and filtering
- VOD movie playback with automatic subtitle fetching
- Series support with season/episode picker

### Electronic Programme Guide (EPG)

- XMLTV parser with automatic EPG updates
- Full TV Guide grid with programme details
- Schedule-based recording from the EPG

### Recording

- Live and scheduled recording via FFmpeg
- Recordings saved to `~/Videos/iptvxs/` (configurable)
- Upload recordings directly to **Google Drive**

### Subtitles

- Automatic subtitle search via OpenSubtitles
- Configurable subtitle language, size, text color, and background
- Subtitle timing adjustment in the player

### Theming

- 6 built-in themes: Midnight, Ocean, Forest, Sunset, Nord, Light
- Theme persists across sessions

### Steam Deck & Controller Support

- Full **D-pad/controller navigation** throughout the entire UI
- Optimized for Steam Deck's display and input
- Available as a **Flatpak** for easy installation
- Works in both Desktop Mode and Game Mode

### Other Features

- Favorites system for quick access to preferred channels
- Stream speed testing
- System tray integration
- Per-server channel synchronization
- Configurable stream buffer time

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

- Qt 6.5+ (Core, Quick, QuickControls2, Sql, Network, Concurrent, OpenGL, Widgets)
- libmpv
- FFmpeg
- CMake 3.22+
- C++20 compiler

#### Build

```bash
git clone https://github.com/bschelst/iptvxs.git
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
│   ├── db/                 # SQLite repositories
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

[MIT](LICENSE)

---

## Contributing

Contributions are welcome! Please open an issue or submit a pull request.
