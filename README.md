# IXAK

A small offline macOS utility: hardware diagnostics, battery health and safe cache cleanup.

Built by [Ihor SYVASH](https://cv-syvash.vercel.app). A personal tool, shared as a portfolio piece.

## What it does

- **This Mac** - model and year, chip and CPU/GPU cores, memory and memory pressure, storage and S.M.A.R.T., displays, SIP/FileVault/Gatekeeper/firewall status, uptime; the serial number is hidden by default; a "Copy report" button
- **Diagnostics** - CPU stress test (all cores), RAM test (write + verify), disk speed test
- **Battery** - wear, charge cycles, temperature, read directly from IOKit system services
- **Cleanup** - scans app caches, logs, DerivedData, iOS DeviceSupport; deletes only to the Trash, with confirmation
- **Storage** - finds files and bundles over 200 MB in your home folder; `.app`/`.framework` and similar are shown as one item without digging inside; Photos/Music/TV/iMovie libraries are visible but cannot be selected for deletion
- **Uninstall** - removes an app completely together with its leftovers in `~/Library`, plus a separate search for orphaned files (leftovers of apps already removed)
- **Autostart** - list of LaunchAgents/LaunchDaemons, with the option to disable and remove user entries
- **Maintenance** - one-off maintenance commands: Spotlight reindex, DNS flush, memory purge, font cache rebuild
- **About** - version, build commit, manual update check and install (on a button press, never in the background)

The whole interface is bilingual: an EN/RU switch in the top right corner of the window (`@AppStorage`, kept between launches).

Works fully offline: the network is used only when you press "Check for Updates" / "Install Update".

To delete orphaned files inside other apps' sandbox containers (`~/Library/Containers/...`), IXAK needs Full Disk Access:
System Settings → Privacy & Security → Full Disk Access. Without it those files simply will not be deleted.
Cleanup/Storage/Autostart only touch items the process can already access; this limit applies only to Uninstall → Orphaned files.

## Updates

Every push to `main` (except README edits) automatically builds a `.pkg` and publishes it to GitHub Releases,
see `.github/workflows/release.yml`. The "Check for Updates" button compares the commit of its own build with
the latest release; if a newer one exists, "Install Update" downloads the `.pkg` and opens it in the standard
macOS Installer (the system itself asks for the admin password), then IXAK quits; open it again after installing.
Works on any Mac where IXAK is already installed, with no Xcode or Terminal. Local builds with uncommitted
changes (`-dirty`) do not offer updates.

## Privacy

- Operator: Ihor SYVASH, private individual, Ukrainian citizen. Contact: sb.vost@gmail.com.
- The app works offline. No personal data or information about your Mac is sent anywhere.
- The network is used only by the "Check for Updates" and "Install Update" buttons: a request to the GitHub API and a `.pkg` download from GitHub Releases. No other data is sent.
- No telemetry, analytics, accounts or ads.
- The only thing stored locally is the selected interface language (`@AppStorage`).
- To find orphaned files, the app reads only what the process can access. Full Disk Access is granted by you manually and can be revoked in macOS settings.
- Files are deleted to the Trash with confirmation. The app never deletes anything permanently.

## Install

Build it yourself (Xcode required):

```bash
git clone https://github.com/ihorsyv/ixak.git
cd ixak/ixak-mac-utility
./Scripts/build_app.sh release --universal
open build/IXAK.app
```

Or build a ready installer to move to another Mac:

```bash
./Scripts/build_installer.sh
```

This produces `build/IXAK Installer.pkg`, a regular `.pkg` that opens in the standard macOS installer ("Continue" → "Install" → password), puts `IXAK.app` in `/Applications` and adds a shortcut to the desktop. It is a single file (not a folder), so it can be sent over Telegram/AirDrop as is, without zipping; a messenger has no execute bits to lose, which used to happen with the old `.app` installer.

The package is not signed with an Apple Developer certificate (ad-hoc only), so on first open macOS shows the Gatekeeper warning "Apple cannot verify...". The recipient only needs to do this once: right-click the file → "Open" → "Open", then the standard installer runs, no Terminal needed.

All technical fixes (quarantine removal, restoring the execute bit, ad-hoc re-signing of `IXAK.app`) are built into the package `postinstall` script (`Scripts/pkg-scripts/postinstall`) and run automatically during installation with admin rights.

## Requirements

macOS 13+, Intel or Apple Silicon (built as a universal binary).
