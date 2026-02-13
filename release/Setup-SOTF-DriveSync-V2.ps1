# Setup-SOTF-DriveSync.ps1
$sotfLauncherName = "SOTF_Host_Launcher.bat"
$global:multiplayerFolder = ""
$global:driveFolder = ""

function Check-DriveInstalled {
    if (Get-Command "GoogleDriveFS.exe" -ErrorAction SilentlyContinue) { return $true }
    $checkPaths = @("$Env:ProgramFiles\Google\Drive File Stream\*\GoogleDriveFS.exe","$Env:ProgramFiles\Google\Drive\*\GoogleDriveFS.exe")
    foreach ($path in $checkPaths) { if (Test-Path $path) { return $true } }
    return $false
}

function Wait-ForDriveInstall {
    while (-not (Check-DriveInstalled)) {
        Write-Host "Google Drive Desktop NOT detected." -ForegroundColor Yellow
        Read-Host "Press Enter to retry..."
    }
}

function Check-DriveRunning {
    while (-not (Get-Process "GoogleDriveFS" -ErrorAction SilentlyContinue)) {
        Write-Host "Google Drive is not running. Please start it." -ForegroundColor Yellow
        Read-Host "Press Enter to retry..."
    }
}

function Resolve-GooglePath {
    param([string]$Path)
    if ([string]::IsNullOrWhiteSpace($Path)) { return $null }
    $cleanPath = $Path.Trim('"').Trim()
    $wsh = New-Object -ComObject WScript.Shell
    if (Test-Path $cleanPath -PathType Container) {
        Get-ChildItem $cleanPath -ErrorAction SilentlyContinue | Out-Null
        return $cleanPath
    }
    $shortcutFile = if ($cleanPath.EndsWith(".lnk")) { $cleanPath } else { "$cleanPath.lnk" }
    if (Test-Path $shortcutFile) {
        try {
            $target = $wsh.CreateShortcut($shortcutFile).TargetPath
            if (Test-Path $target) {
                Get-ChildItem $target -ErrorAction SilentlyContinue | Out-Null
                return $target
            }
        } catch { }
    }
    return $null
}

function Ask-DriveFolder {
    $myDrive = "G:\My Drive"
    if (Test-Path $myDrive) {
        Write-Host "Waking up Google Drive..." -ForegroundColor Gray
        Get-ChildItem $myDrive -Filter "*.lnk" | ForEach-Object { Resolve-GooglePath -Path $_.FullName | Out-Null }
    }
    Write-Host "`nOpening folder selection..." -ForegroundColor Gray
    $shell = New-Object -ComObject Shell.Application
    $picker = $shell.BrowseForFolder(0, "Select SOTF Cloud Folder", 1+64+16, "G:\")
    $selectedPath = if ($picker) { $picker.Self.Path } else { $null }
    if (-not $selectedPath) {
        $userInput = Read-Host "Paste full path manually (or Enter to cancel)"
        if ([string]::IsNullOrWhiteSpace($userInput)) { exit }
        $selectedPath = Resolve-GooglePath -Path $userInput
        if (-not $selectedPath) {
            if ((Read-Host "Path unverified. Type 'force' to use anyway") -eq "force") { $selectedPath = $userInput.Trim('"').Trim() } else { exit }
        }
    }
    $global:driveFolder = $selectedPath
}

function Detect-SOTF-SteamID {
    $basePath = "$Env:APPDATA\..\LocalLow\Endnight\SonsOfTheForest\Saves"
    $steamIDFolder = Get-ChildItem $basePath -Directory | Select-Object -First 1
    $global:multiplayerFolder = Join-Path $steamIDFolder.FullName "Multiplayer"
}

function Initialize-Identity {
    $clientRoot = $global:multiplayerFolder.Replace("Multiplayer", "MultiplayerClient")
    if (-not (Test-Path $clientRoot)) { New-Item $clientRoot -ItemType Directory -Force | Out-Null }
    
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    
    # The 8 files that define your character/progress
    $identityFiles = @(
        "PlayerArmourSystemSaveData.json", 
        "PlayerClothingSystemSaveData.json", 
        "PlayerInventorySaveData.json", 
        "PlayerRetrieveDroppedInventoryActionSaveData.json", 
        "PlayerStateSaveData.json", 
        "HotkeysSaveData.json", 
        "PlayerTacticalBowSystemSaveData.json",
        "GameStateSaveData.json" # Needed for ID matching
    )

    $GetId = { param($p)
        try {
            $z = [System.IO.Compression.ZipFile]::OpenRead($p)
            $e = $z.GetEntry("GameStateSaveData.json")
            if ($e) {
                $r = New-Object System.IO.StreamReader($e.Open()); $t = $r.ReadToEnd(); $r.Close(); $z.Dispose()
                if ($t -match 'GameId\\?":\\?"([a-f0-9-]{36})') { return $matches[1] }
            }
            $z.Dispose()
        } catch {} return $null
    }

    # 1. Map what we already have in Client folder
    $existingIds = @{}
    Get-ChildItem $clientRoot -Filter "SaveData.zip" -Recurse | ForEach-Object {
        $id = &$GetId $_.FullName
        if ($id) { $existingIds[$id] = $_.FullName }
    }

    # 2. Check Host folders for missing identities
    Get-ChildItem $global:multiplayerFolder -Filter "SaveData.zip" -Recurse | ForEach-Object {
        $hostZipPath = $_.FullName
        $hostId = &$GetId $hostZipPath
        
        if ($hostId -and -not $existingIds.ContainsKey($hostId)) {
            $targetFolder = Join-Path $clientRoot $_.Directory.Name
            New-Item $targetFolder -ItemType Directory -Force | Out-Null
            $newClientZip = Join-Path $targetFolder "SaveData.zip"

            Write-Host " [IDENTITY] Extracting character data for World: $($_.Directory.Name)..." -ForegroundColor Cyan
            
            # Create a NEW zip and copy ONLY the identity files from the Host zip
            $sourceZip = [System.IO.Compression.ZipFile]::OpenRead($hostZipPath)
            $destZip = [System.IO.Compression.ZipFile]::Open($newClientZip, "Update")

            foreach ($fileName in $identityFiles) {
                $entry = $sourceZip.GetEntry($fileName)
                if ($entry) {
                    $newEntry = $destZip.CreateEntry($fileName)
                    $s = $entry.Open()
                    $d = $newEntry.Open()
                    $s.CopyTo($d)
                    $s.Close(); $d.Close()
                }
            }
            $sourceZip.Dispose()
            $destZip.Dispose()
            Write-Host " [OK] Identity created." -ForegroundColor Green
        }
    }
}

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
        'title SOTF Smart-Sync Launcher',
        'mode con: cols=140 lines=30',
        "set ""LOCAL=$global:multiplayerFolder""",
        "set ""CLOUD=$global:driveFolder""",
        "set ""CLIENT_ROOT=$clientFolder""",
        'set "SOTF_HOST=%LOCAL%"',
        'set "SOTF_CLIENT=%CLIENT_ROOT%"',
        '',
        'echo STEP 1: DOWNLOADING WORLD FROM LOCAL GOOGLE CLOUD DRIVE...',
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
        'echo STEP 3: WAITING FOR SAVE STABILITY...',
        'echo Monitoring Multiplayer folder for file write completion...',
        'set "STABLE=0"',
        ':stabilityCheck',
        'powershell -Command "$files = Get-ChildItem ''%LOCAL%'' -Filter SaveData.zip -Recurse; $t1 = $files | Measure-Object -Property LastWriteTime -Maximum | Select-Object -ExpandProperty Maximum; Start-Sleep -Seconds 10; $files2 = Get-ChildItem ''%LOCAL%'' -Filter SaveData.zip -Recurse; $t2 = $files2 | Measure-Object -Property LastWriteTime -Maximum | Select-Object -ExpandProperty Maximum; if ($t1 -eq $t2) { exit 0 } else { exit 1 }"',
        'if errorlevel 1 (',
        '    echo [!] Files are still being written... waiting another 10s',
        '    goto stabilityCheck',
        ')',
        'echo [OK] Save files are stable.',
        '',
        'echo STEP 5: SAVING PROGRESS',
        'set "SOTF_MODE=Extract"',
        "powershell -NoProfile -EncodedCommand $encodedCommand",
        '',
        'echo STEP 6: UPLOADING TO LOCAL CLOUD DRIVE',
        'robocopy "%LOCAL%" "%CLOUD%" /XO /Z /XF *backup* /LEV:1 /R:2 /W:2',
        'robocopy "%LOCAL%" "%CLOUD%" /S /XO /Z /XF *backup* /R:2 /W:2',
        'echo Local Google Cloud Drive Sync complete.',
        'echo Actual Google Cloud Sync Will Be Handled By Google Drive Desktop.',
        'echo Closing window in 10 seconds...',
        'timeout /t 10 >nul',
        'exit'
    )

    $batchLines | Out-File $launcherPath -Encoding ASCII
}

function Create-SOTF-Launcher {
    Clear-Host
    Write-Host "=== Sons of the Forest Google Drive Setup Assistant ===`n"
    Wait-ForDriveInstall
    Check-DriveRunning
    Ask-DriveFolder
    Detect-SOTF-SteamID
    Initialize-Identity
    Create-Launcher
    Write-Host "`nSetup Complete! Use $sotfLauncherName to play." -ForegroundColor Cyan
}

Create-SOTF-Launcher
pause