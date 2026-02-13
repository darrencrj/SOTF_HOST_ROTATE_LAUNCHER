# Changelog 📜

All notable changes to the **Sons Of The Forest Host Rotating Launcher Generator** will be documented in this file.

---

## [V2] - Stability & Identity Fixes
*Refining the host-rotation logic and ensuring Google Drive reliability.*

### ✨ Enhancements
* **Identity Preservation:** Improved the initialization logic to preserve the original host's character data within the `MultiplayerClient` folder. This ensures that even the person who started the world can participate in the rotating host cycle without risking their inventory.
* **Drive Warm-up Logic:** Enhanced the pre-scan routine to "poke" Google Drive shortcuts. This fixes issues where shared folders were not "warm loaded" and appeared as broken or missing paths to the launcher.

### 🐛 Bug Fixes
* **Character Data Replacement:** Fixed a critical bug where character data was not being correctly injected/extracted. This was previously causing players who took over a save to unintentionally use the original host's character (backpack, stats, and gear) instead of their own.
* **Path Resolution:** Improved handling of `.shortcut-targets-by-id` to ensure reliable folder picking during the setup phase.

---

## [V1] - Initial Release
*The birth of the SOTF-HRLG suite.*

### 🎉 Features
* **Initial Script Creation:** Base PowerShell generator for creating the `.bat` launcher.
* **Automated Sync:** Basic `robocopy` integration for moving saves between local directories and Google Drive.
* **Process Monitoring:** Initial implementation of the loop to wait for the game process to exit.