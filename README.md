# Sons Of The Forest Host Rotating Launcher Generator 🌲🔄

### "Want to continue the multiplayer game, but the Host is offline?" 
**This could be the solution.**

---

**SOTF-HRLG** is a specialized automation suite that liberates your group from the "Host Trap." It allows any player in your group to become the host at any time, while ensuring that everyone’s individual character inventory, stats, and gear stay perfectly in sync.

---

## 🛠 The Problem: The "Host Trap"
In *Sons of the Forest*, world data (buildings, trees, story progress) belongs to the **Host**. Character data (your backpack) is usually local. 
* If the Host is away, the world is locked. 
* If the Host sends you the save file, you often spawn as **their** character, losing your own hard-earned gear.

## ✅ The Solution: Rotating Hosting
This tool allows your group to rotate hosting duties freely:
1. **Shared World:** Syncs the latest world save to a shared Google Drive.
2. **Personal Identity:** It "snaps" your personal inventory out of the save before you upload it, and "injects" it back in when you download a friend's save to host.
3. **Total Automation:** A single `.bat` file handles the downloads, inventory injection, game launching, stability checks, and cloud uploads.

---



---

## ⚠️ Known Limitations

### ☁️ Google Drive Desktop Finalization
* **The Gap:** The script moves files to your local `G:\` drive instantly, but **Google Drive Desktop** handles the actual internet upload.
* **The Risk:** If you shut down your PC the second the script closes, the upload might be cut off.
* **Recommendation:** Wait until the Google Drive tray icon says *"Everything is up to date"* before turning off your PC.

### 📂 Full-Directory Sync
* **The Limitation:** It currently syncs the **entire** Multiplayer folder within the selected cloud path.
* **Impact:** If you have 20 different world saves, it will check all 20. Keep your shared cloud folder clean of "abandoned" worlds to keep sync speeds fast.

---

## ⚠️ Warning ⚠️
* This is just my personal playground project.
* I'm not responsible for any missing or corrupted save files.
* You might wanna backup all files in "\AppData\LocalLow\Endnight\SonsOfTheForest\Saves" before trying this.
* You are responsible to check if the powershell script is doing anything funny. (Please leverage AI to check the script if you have concerns)

---

## Last Tested Sons Of The Forest Release Is Oct 4, 2025

---

## Prerequesist
Download latest release [here](https://github.com/darrencrj/SOTF_HOST_ROTATE_LAUNCHER/tree/main/release)

---

## 🚀 Getting Started
1. **Initial Setup:** Run `Setup-SOTF-DriveSync-{version}.ps1`.
2. **Linking:** Point the generator to your shared Google Drive folder. (The script will automatically "warm up" the drive to find hidden ID paths).
3. **The Launcher:** The script generates `SOTF_Host_Launcher.bat`. Move this to your desktop.
4. **Playing:** Always launch the game via the `.bat` file when you are the one hosting.
5. **Stability Check:** After you exit the game, the launcher waits for **10 seconds of disk silence** to ensure the save is fully written before it touches your inventory or starts the cloud upload.

---

## 📝 Requirements
* **Google Drive for Desktop** (Must be logged in and running).
* **Sons of the Forest** (Steam Version).
* **Windows PowerShell 5.1+**.

