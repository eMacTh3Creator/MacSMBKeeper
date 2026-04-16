# Mac SMB Keeper

Native macOS menu bar app that keeps your SMB network shares connected. Designed for headless Macs and always-on setups where dropped SMB mounts cause problems.

![macOS 15+](https://img.shields.io/badge/macOS-15%2B-blue)
![Swift 6](https://img.shields.io/badge/Swift-6-orange)
![License: MIT](https://img.shields.io/badge/License-MIT-green)

## Features

- **Auto-reconnect** — monitors configured SMB shares every 30 seconds and reconnects if dropped
- **Startup mount** — automatically connects all enabled shares when the app launches
- **Menu bar interface** — lives in the menu bar with per-share status indicators (green/red/orange)
- **Keychain credentials** — passwords stored securely in the macOS Keychain
- **Native mounting** — uses the NetFS framework for proper macOS SMB mounts (same as Finder)
- **Share management** — add, edit, and remove shares from a clean SwiftUI interface
- **Per-share control** — enable/disable auto-connect, connect/disconnect individually

## Screenshot

The main window provides a sidebar with all configured shares and their connection status, with a detail view for managing each share. The menu bar icon shows overall status at a glance.

## Installation

### Download

Grab the latest `.zip` from [Releases](https://github.com/eMacTh3Creator/MacSMBKeeper/releases), unzip, and drag **Mac SMB Keeper.app** to `/Applications`.

### Build from source

Requires Xcode 16+ and [xcodegen](https://github.com/yonaskolb/XcodeGen).

```bash
brew install xcodegen
./script/run.sh
```

The built app will be at `/tmp/MacSMBKeeper-build/Build/Products/Release/Mac SMB Keeper.app`.

## Usage

1. Launch Mac SMB Keeper — it appears in the menu bar
2. Click the menu bar icon and select **Open Mac SMB Keeper...**
3. Click **+** to add an SMB share:
   - **Host**: IP address or hostname (e.g. `192.168.1.100` or `nas.local`)
   - **Share Name**: the SMB share name (e.g. `Media`)
   - **Mount Point**: where to mount (default `/Volumes`)
   - **Username/Password**: leave empty for guest access
   - **Auto-connect**: toggle whether this share reconnects automatically
4. The app monitors connections and reconnects dropped shares automatically

## Headless Mac Setup

For a headless Mac, add Mac SMB Keeper to your **Login Items** (System Settings > General > Login Items) so it launches at boot and keeps your shares connected without manual intervention.

## Architecture

| Component | Description |
|-----------|-------------|
| `SMBMountService` | NetFS-based mount/unmount and mount detection via `statfs` |
| `SMBMonitorService` | 30-second polling loop with auto-reconnect |
| `KeychainService` | Secure credential storage via Security framework |
| `ShareStore` | JSON persistence in `~/Library/Application Support/MacSMBKeeper/` |

## Requirements

- macOS 15.0 (Sequoia) or later
- SMB shares accessible on the network

## License

MIT
