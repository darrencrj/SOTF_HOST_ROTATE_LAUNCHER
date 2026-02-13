# Setup-SOTF-DriveSync.ps1

function Check-DriveInstalled {
    # Check common install locations
    $checkPaths = @(
        "$Env:ProgramFiles\Google\Drive File Stream\*\GoogleDriveFS.exe",
        "$Env:ProgramFiles(x86)\Google\Drive File Stream\*\GoogleDriveFS.exe",
        "$Env:ProgramFiles\Google\Drive\*\GoogleDriveFS.exe",
        "$Env:LOCALAPPDATA\Google\DriveFS\*\GoogleDriveFS.exe" 
    )

    # Check if the process executable is registered in Windows
    if (Get-Command "GoogleDriveFS.exe" -ErrorAction SilentlyContinue) { return $true }

    # Check physical paths
    foreach ($path in $checkPaths) {
        if (Test-Path $path) { return $true }
    }
    
    return $false
}

function Wait-ForDriveInstall {
    while (-not (Check-DriveInstalled)) {
        Write-Host "Google Drive Desktop NOT detected." -ForegroundColor Yellow
        Write-Host "Please install it from: https://workspace.google.com/products/drive/#download"
		Write-Host "If installed, please ensure it is running first."
        Read-Host "Press Enter to retry..."
    }
    Write-Host "Google Drive Desktop detected." -ForegroundColor Green
}

function Check-DriveRunning {
    Write-Host "Checking if Google Drive is running..."
    while ($true) {
        # FIX: Check for BOTH possible process names
        $proc = Get-Process -Name "GoogleDrive", "GoogleDriveFS" -ErrorAction SilentlyContinue
        
        if ($proc) {
            Write-Host "Google Drive is running." -ForegroundColor Green
            break 
        }
        
        Write-Host "Google Drive process not found." -ForegroundColor Red
        Write-Host "Please open the Google Drive app from your Start Menu."
        Read-Host "Press Enter once it is running..."
    }
}

function Ask-DriveFolder {
    Write-Host "====================================================================================="
	Write-Host "If it is a shared folder and you are not the owner, follow the steps below" -ForegroundColor Yellow
    Write-Host "  1. Head over to [https://drive.google.com/drive/shared-with-me]" -ForegroundColor Yellow
    Write-Host "  2. Right click on the shared folder -> Organize -> Add shortcut" -ForegroundColor Yellow
    Write-Host "  3. Select All locations -> My Drive" -ForegroundColor Yellow
    Write-Host "  4. Click Add" -ForegroundColor Yellow
    Write-Host "  5. When the folder is sync to your computer, it will appear in G Drive[.shortcut-targets-by-id]. Dig through it to find your shared folder" -ForegroundColor Yellow
	Write-Host "====================================================================================="
	
	
	Write-Host "Opening folder picker..." -ForegroundColor Gray
    
    # We use the Shell COM object because it supports the "Scroll to" behavior
    $shell = New-Object -ComObject Shell.Application
    
    # Default starting point (Google Drive)
    $startingLocation = "G:\"
    if (-not (Test-Path $startingLocation)) { $startingLocation = 0 } # Fallback to Desktop

    # 1 = Only allow folders, 64 = Show 'New Folder' button, 16 = Include 'My Computer'
    $folder = $shell.BrowseForFolder(0, "Select the folder in Google Drive", 1 + 64 + 16, $startingLocation)

    if ($folder) {
        $global:driveFolder = $folder.Self.Path
        
        # Check if it's a shortcut ID path (common for shared folders)
        if ($global:driveFolder -like "*shortcut-targets-by-id*") {
            Write-Host "`n[OK] Linked to Shared Folder via ID." -ForegroundColor Green
        } else {
            Write-Host "`n[OK] Folder Selected: $($global:driveFolder)" -ForegroundColor Green
        }
    } else {
        Write-Host "`n[!] Setup cancelled. No folder selected." -ForegroundColor Red
        exit
    }
}

function Detect-SOTF-SteamID {
    Write-Host "`n--- Step 2: Detect Game Saves ---" -ForegroundColor Cyan
    $saveRoot = "$Env:USERPROFILE\AppData\LocalLow\Endnight\SonsOfTheForest\Saves"

    if (-not (Test-Path $saveRoot)) { 
        Write-Host "Game saves not found at default location." -ForegroundColor Red
        exit 
    }
    
    $folders = Get-ChildItem $saveRoot | Where-Object { $_.PSIsContainer -and $_.Name -match '^\d{17}$' }
    
    if ($folders.Count -eq 0) { 
        Write-Host "No SteamID folder found. Launch the game at least once." -ForegroundColor Red
        exit 
    }
    
    $global:steamID = $folders[0].Name
    $global:multiplayerFolder = Join-Path $saveRoot "$($global:steamID)\Multiplayer"
    Write-Host "Steam ID found: $($global:steamID)" -ForegroundColor Green
}

$sotfLauncherName = "SOTF_Host_Launcher.bat"

function Create-Launcher {
    $launcherPath = Join-Path $PSScriptRoot $sotfLauncherName
    
    $psLogic = @'
    $Mode       = $env:SOTF_MODE
    $HostRoot   = $env:SOTF_HOST
    $ClientRoot = $env:SOTF_CLIENT
    
    Add-Type -AssemblyName System.IO.Compression.FileSystem

    $playerFiles = @(
        "PlayerArmourSystemSaveData.json", 
        "PlayerClothingSystemSaveData.json", 
        "PlayerInventorySaveData.json", 
        "PlayerRetrieveDroppedInventoryActionSaveData.json", 
        "PlayerStateSaveData.json", 
        "HotkeysSaveData.json"
    )

    function Get-GameId {
        param($zipPath)
        try {
            $zip = [System.IO.Compression.ZipFile]::OpenRead($zipPath)
            $entry = $zip.GetEntry("GameStateSaveData.json")
            if ($entry) {
                $reader = New-Object System.IO.StreamReader($entry.Open())
                $text = $reader.ReadToEnd()
                $reader.Close(); $zip.Dispose()
                if ($text -match 'GameId\\?":\\?"([a-f0-9-]{36})') {
                    return $matches[1]
                }
            }
            if ($zip) { $zip.Dispose() }
        } catch { }
        return $null
    }

    if (-not (Test-Path $HostRoot)) { exit }
    
    foreach ($hFolder in (Get-ChildItem $HostRoot -Directory)) {
        $hostZip = Join-Path $hFolder.FullName "SaveData.zip"
        if (-not (Test-Path $hostZip)) { continue }

        $targetGameId = Get-GameId -zipPath $hostZip
        if (-not $targetGameId) { continue }
        
        Write-Host "--- Processing: $($hFolder.Name) ---" -ForegroundColor Cyan

        $matchedClientZip = $null
        if (Test-Path $ClientRoot) {
            foreach ($cFolder in (Get-ChildItem $ClientRoot -Directory)) {
                $cZip = Join-Path $cFolder.FullName "SaveData.zip"
                if (Test-Path $cZip) {
                    if ((Get-GameId -zipPath $cZip) -eq $targetGameId) {
                        $matchedClientZip = $cZip
                        Write-Host " [OK] Character match found!" -ForegroundColor Green
                        break
                    }
                }
            }
        }

        if ($Mode -eq "Inject") {
            if ($matchedClientZip) {
                $hArchive = [System.IO.Compression.ZipFile]::Open($hostZip, "Update")
                $cArchive = [System.IO.Compression.ZipFile]::OpenRead($matchedClientZip)
                foreach ($file in $playerFiles) {
                    $sourceEntry = $cArchive.GetEntry($file)
                    if ($sourceEntry) {
                        $destEntry = $hArchive.GetEntry($file); if ($destEntry) { $destEntry.Delete() }
                        $newEntry = $hArchive.CreateEntry($file)
                        $sStream = $sourceEntry.Open(); $dStream = $newEntry.Open()
                        $sStream.CopyTo($dStream)
                        $sStream.Close(); $dStream.Close()
                    }
                }
                $cArchive.Dispose(); $hArchive.Dispose()
            }
        }
        elseif ($Mode -eq "Extract") {
            if (-not $matchedClientZip) {
                $newFolderPath = Join-Path $ClientRoot $hFolder.Name
                New-Item -Path $newFolderPath -ItemType Directory -Force | Out-Null
                $matchedClientZip = Join-Path $newFolderPath "SaveData.zip"
                [System.IO.Compression.ZipFile]::Open($matchedClientZip, "Create").Dispose()
            }
            $hArchive = [System.IO.Compression.ZipFile]::OpenRead($hostZip)
            $cArchive = [System.IO.Compression.ZipFile]::Open($matchedClientZip, "Update")
            foreach ($file in ($playerFiles + "GameStateSaveData.json")) {
                $sourceEntry = $hArchive.GetEntry($file)
                if ($sourceEntry) {
                    $destEntry = $cArchive.GetEntry($file); if ($destEntry) { $destEntry.Delete() }
                    $newEntry = $cArchive.CreateEntry($file)
                    $sStream = $sourceEntry.Open(); $dStream = $newEntry.Open()
                    $sStream.CopyTo($dStream)
                    $sStream.Close(); $dStream.Close()
                }
            }
            $hArchive.Dispose(); $cArchive.Dispose()
            Write-Host " [SAVED] Character progress backed up." -ForegroundColor Green
        }
    }
'@

    $encodedCommand = [Convert]::ToBase64String([System.Text.Encoding]::Unicode.GetBytes($psLogic))
    $clientFolder = $global:multiplayerFolder.Replace("Multiplayer", "MultiplayerClient")

    $batchLines = @(
        '@echo off',
		"mode con: cols=135 lines=35",
        'title SOTF Smart-Sync Launcher',
        "set ""LOCAL=$($global:multiplayerFolder)""",
        "set ""CLOUD=$($global:driveFolder)""",
        "set ""CLIENT_ROOT=$clientFolder""",
        'set "SOTF_HOST=%LOCAL%"',
        'set "SOTF_CLIENT=%CLIENT_ROOT%"',
        '',
        'echo STEP 1: DOWNLOADING WORLD',
        'robocopy "%CLOUD%" "%LOCAL%" /XO /Z /XF *backup* /LEV:1 /R:2 /W:2',
        'robocopy "%CLOUD%" "%LOCAL%" /S /XO /Z /XF *backup* /R:2 /W:2',
        '',
        'set "SOTF_MODE=Inject"',
        "powershell -NoProfile -EncodedCommand $encodedCommand",
        '',
        'echo Done! Launching game...',
        'start "" "steam://rungameid/1326470"',
        '',
        ':waitloop',
        'timeout /t 5 >nul',
        'tasklist | find /i "SonsOfTheForest.exe" >nul',
        'if not errorlevel 1 goto waitloop',
        '',
        'echo STEP 3: SAVING PROGRESS',
        'set "SOTF_MODE=Extract"',
        "powershell -NoProfile -EncodedCommand $encodedCommand",
        '',
        'echo STEP 4: UPLOADING TO CLOUD',
        'robocopy "%LOCAL%" "%CLOUD%" /XO /Z /XF *backup* /LEV:1 /R:2 /W:2',
        'robocopy "%LOCAL%" "%CLOUD%" /S /XO /Z /XF *backup* /R:2 /W:2',
        'echo Sync complete, closing window in 5 seconds...'
		'timeout /t 5 >nul',
		'exit'
    )

    $batchLines | Out-File -FilePath $launcherPath -Encoding ASCII
}

function Create-SOTF-Launcher {
	Clear-Host
    Write-Host "=== Sons of the Forest Google Drive Setup Assistant ===`n"
    
    Wait-ForDriveInstall
    Check-DriveRunning
    Ask-DriveFolder
    Detect-SOTF-SteamID
    Create-Launcher

    Write-Host "`nSetup complete! Run '$sotfLauncherName' to play." -ForegroundColor Cyan
}

# ----------------- Main Execution -----------------
try {
    Create-SOTF-Launcher
	Read-Host "Press Enter to exit"
} catch {
    Write-Host "`nERROR: $($_.Exception.Message)" -ForegroundColor Red
    Read-Host "Press Enter to exit"
}