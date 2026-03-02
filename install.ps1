# Agentic Substrate v4.1 - Robust Cross-Platform Installation (PowerShell)
# Works on: Windows (PowerShell 5.1+), PowerShell Core (macOS, Linux)

[CmdletBinding()]
param(
    [switch]$DryRun,
    [switch]$Force,
    [switch]$Help
)

$ErrorActionPreference = "Stop"

# ============================================================================
# GLOBAL VARIABLES
# ============================================================================

$VERSION = "4.2.0"

$script:CurlInstall = $false
$script:TempClone = $false
$script:ScriptDir = ""
$script:ClaudeSource = ""
$script:ClaudeTarget = Join-Path $HOME ".claude"
$script:ManifestTemplate = ""
$script:BackupLocation = ""
$script:LockFile = Join-Path $HOME ".claude-install.lock"
$script:SupportsEmoji = $true
$script:OSType = "unknown"

# ============================================================================
# UTILITY FUNCTIONS - Cross-Platform Compatibility
# ============================================================================

# Detect operating system
function Detect-OS {
    if ($IsWindows -or ($PSVersionTable.PSVersion.Major -le 5)) {
        $script:OSType = "windows"
    } elseif ($IsMacOS) {
        $script:OSType = "macos"
    } elseif ($IsLinux) {
        $script:OSType = "linux"
    } else {
        $script:OSType = "unknown"
    }
}

# Detect terminal capabilities
function Detect-Terminal {
    $script:SupportsEmoji = $true

    # Check if running in CI/automated environment
    if ($env:CI -or $env:GITHUB_ACTIONS) {
        $script:SupportsEmoji = $false
    }

    # Windows console before Windows Terminal may not support emoji well
    if ($script:OSType -eq "windows" -and -not $env:WT_SESSION) {
        $script:SupportsEmoji = $false
    }
}

# Logging functions with fallback
function Log-Info {
    param([string]$Message)
    if ($script:SupportsEmoji) {
        Write-Host ([char]0x2139 + [char]0xFE0F + "  $Message")
    } else {
        Write-Host "[INFO] $Message"
    }
}

function Log-Success {
    param([string]$Message)
    if ($script:SupportsEmoji) {
        Write-Host ([char]0x2705 + " $Message")
    } else {
        Write-Host "[SUCCESS] $Message"
    }
}

function Log-Warning {
    param([string]$Message)
    if ($script:SupportsEmoji) {
        Write-Host ([char]0x26A0 + [char]0xFE0F + "  $Message")
    } else {
        Write-Host "[WARNING] $Message"
    }
}

function Log-Error {
    param([string]$Message)
    if ($script:SupportsEmoji) {
        Write-Host ([char]0x274C + " $Message") -ForegroundColor Red
    } else {
        Write-Host "[ERROR] $Message" -ForegroundColor Red
    }
}

# Cross-platform mktemp
function Safe-MkTemp {
    $tmpDir = Join-Path ([System.IO.Path]::GetTempPath()) ("agentic-substrate-" + [System.Diagnostics.Process]::GetCurrentProcess().Id + "-" + (Get-Random))
    try {
        New-Item -ItemType Directory -Path $tmpDir -Force | Out-Null
        return $tmpDir
    } catch {
        Log-Error "Failed to create temporary directory"
        return $null
    }
}

# Cross-platform date (ISO 8601)
function Safe-Date {
    try {
        return (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
    } catch {
        return "unknown"
    }
}

# Write file as UTF-8 without BOM (PS 5.1 Out-File -Encoding utf8 adds BOM)
function Write-Utf8NoBom {
    param(
        [string]$FilePath,
        [string]$Content,
        [switch]$NoNewline
    )
    $utf8NoBom = [System.Text.UTF8Encoding]::new($false)
    if (-not $NoNewline) {
        $Content = $Content + [Environment]::NewLine
    }
    [System.IO.File]::WriteAllText($FilePath, $Content, $utf8NoBom)
}

# Parse JSON value
function Parse-JsonValue {
    param(
        [string]$JsonFile,
        [string]$Key
    )

    if (-not (Test-Path $JsonFile)) {
        return $null
    }

    try {
        $json = Get-Content -Raw $JsonFile | ConvertFrom-Json
        return $json.$Key
    } catch {
        return $null
    }
}

# Parse JSON array
function Parse-JsonArray {
    param(
        [string]$JsonFile,
        [string]$ArrayName
    )

    if (-not (Test-Path $JsonFile)) {
        return @()
    }

    try {
        $json = Get-Content -Raw $JsonFile | ConvertFrom-Json
        return @($json.$ArrayName)
    } catch {
        return @()
    }
}

# Count array items in JSON
function Count-JsonArray {
    param(
        [string]$JsonFile,
        [string]$ArrayName
    )

    $arr = Parse-JsonArray -JsonFile $JsonFile -ArrayName $ArrayName
    return $arr.Count
}

# Git clone with retry
function Git-CloneWithRetry {
    param(
        [string]$Url,
        [string]$TargetDir
    )

    $maxAttempts = 3
    $attempt = 1

    while ($attempt -le $maxAttempts) {
        Log-Info "Downloading repository (attempt $attempt/$maxAttempts)..."

        try {
            $output = & git clone --depth 1 --branch main $Url $TargetDir 2>&1
            if ($LASTEXITCODE -eq 0) {
                return $true
            }
        } catch {}

        if ($attempt -lt $maxAttempts) {
            Log-Warning "Clone failed, retrying in $($attempt * 2) seconds..."
            Start-Sleep -Seconds ($attempt * 2)
        }

        $attempt++
    }

    Log-Error "Failed to clone repository after $maxAttempts attempts"
    return $false
}

# ============================================================================
# LOCK FILE MANAGEMENT
# ============================================================================

function Acquire-Lock {
    # Check if lock file exists
    if (Test-Path $script:LockFile) {
        $lockPid = $null
        try {
            $lockPid = Get-Content $script:LockFile -ErrorAction SilentlyContinue
        } catch {}

        # Check if process is still running
        if ($lockPid) {
            try {
                $proc = Get-Process -Id ([int]$lockPid) -ErrorAction SilentlyContinue
                if ($proc) {
                    Log-Error "Another installation is running (PID: $lockPid)"
                    Log-Info "If this is a stale lock, remove: $($script:LockFile)"
                    exit 1
                }
            } catch {}

            # Stale lock, remove it
            Remove-Item $script:LockFile -Force -ErrorAction SilentlyContinue
        }
    }

    # Create lock file with our PID
    try {
        Write-Utf8NoBom -FilePath $script:LockFile -Content ([string][System.Diagnostics.Process]::GetCurrentProcess().Id) -NoNewline
    } catch {
        Log-Warning "Could not create lock file (continuing anyway)"
    }
}

function Release-Lock {
    if ($script:LockFile -and (Test-Path $script:LockFile)) {
        Remove-Item $script:LockFile -Force -ErrorAction SilentlyContinue
    }
}

# ============================================================================
# CLEANUP HANDLER
# ============================================================================

function Invoke-Cleanup {
    # Remove temp directory if curl install
    if ($script:TempClone -and $script:ScriptDir -and (Test-Path $script:ScriptDir)) {
        Log-Info "Cleaning up temporary files..."
        Remove-Item -Recurse -Force $script:ScriptDir -ErrorAction SilentlyContinue
    }

    # Release lock
    Release-Lock
}

# ============================================================================
# INSTALLATION FUNCTIONS
# ============================================================================

# Show help
function Show-Help {
    Write-Host "Agentic Substrate Installer v$VERSION"
    Write-Host ""
    Write-Host "Usage: .\install.ps1 [OPTIONS]"
    Write-Host ""
    Write-Host "Options:"
    Write-Host "  -DryRun     Show what would be installed without installing"
    Write-Host "  -Force      Force reinstall even if already installed"
    Write-Host "  -Help       Show this help message"
    Write-Host ""
    exit 0
}

# Detect if running via remote download
function Detect-CurlInstall {
    $scriptPath = $PSScriptRoot

    # Check if .claude directory exists at script location
    if ($scriptPath -and (Test-Path (Join-Path $scriptPath ".claude")) -and (Test-Path (Join-Path $scriptPath "manifest-template.json"))) {
        $script:CurlInstall = $false
        $script:ScriptDir = $scriptPath
        return
    }

    # Default: assume remote install
    $script:CurlInstall = $true
}

# Clone repository if needed (for remote install)
function Clone-Repository {
    if (-not $script:CurlInstall) {
        return
    }

    Log-Info "Running in remote mode - will download repository"

    # Check for git
    if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
        Log-Error "Git is required but not installed"
        Log-Error "Please install git first, or use:"
        Log-Error "  git clone https://github.com/VAMFI/claude-user-memory.git"
        Log-Error "  cd claude-user-memory; .\install.ps1"
        exit 1
    }

    # Create temp directory
    $script:ScriptDir = Safe-MkTemp
    if (-not $script:ScriptDir) {
        Log-Error "Failed to create temporary directory"
        exit 1
    }
    $script:TempClone = $true

    # Clone repository with retry
    if (-not (Git-CloneWithRetry -Url "https://github.com/VAMFI/claude-user-memory.git" -TargetDir $script:ScriptDir)) {
        exit 1
    }

    Log-Success "Repository downloaded successfully"
}

# Comprehensive pre-flight checks
function Invoke-PreflightChecks {
    Log-Info "Pre-flight checks..."

    # Check PowerShell version
    if ($PSVersionTable.PSVersion.Major -lt 5) {
        Log-Error "This script requires PowerShell 5.1 or later"
        exit 1
    }

    # Check source directory
    $script:ClaudeSource = Join-Path $script:ScriptDir ".claude"
    if (-not (Test-Path $script:ClaudeSource)) {
        Log-Error "Source directory not found: $($script:ClaudeSource)"
        Log-Error "Make sure you're running this script from the repository root"
        exit 1
    }

    # Check manifest
    $script:ManifestTemplate = Join-Path $script:ScriptDir "manifest-template.json"
    if (-not (Test-Path $script:ManifestTemplate)) {
        Log-Error "Manifest template not found: $($script:ManifestTemplate)"
        exit 1
    }

    # Validate JSON
    $jsonValid = $false
    try {
        Get-Content -Raw $script:ManifestTemplate | ConvertFrom-Json | Out-Null
        $jsonValid = $true
    } catch {
        $jsonValid = $false
    }

    if (-not $jsonValid) {
        Log-Error "Manifest template is invalid JSON"
        exit 1
    }

    # Check write permissions
    try {
        $testFile = Join-Path $HOME ".claude-install-write-test"
        Write-Utf8NoBom -FilePath $testFile -Content "test" -NoNewline
        Remove-Item $testFile -Force
    } catch {
        Log-Error "No write permission to $HOME"
        exit 1
    }

    # Check disk space (need ~10MB)
    try {
        $drive = (Resolve-Path $HOME).Drive
        if ($drive) {
            $freeSpace = (Get-PSDrive $drive.Name -ErrorAction SilentlyContinue).Free
            if ($freeSpace -and $freeSpace -lt 10MB) {
                Log-Warning "Low disk space (need ~10MB)"
            }
        }
    } catch {}

    # Check if already installed (unless force)
    $versionFile = Join-Path $script:ClaudeTarget ".agentic-substrate-version"
    if (-not $Force -and (Test-Path $versionFile)) {
        $installedVersion = (Get-Content $versionFile -ErrorAction SilentlyContinue).Trim()
        if ($installedVersion -eq $VERSION) {
            Log-Warning "Agentic Substrate v$VERSION is already installed"
            Log-Info "Use -Force to reinstall"
            exit 0
        }
    }

    Log-Success "Pre-flight checks passed"
}

# Create backup
function Create-Backup {
    if (-not (Test-Path $script:ClaudeTarget)) {
        Log-Info "No existing installation - skipping backup"
        return
    }

    $backupDir = Join-Path $HOME (".claude.backup-" + (Get-Date -Format "yyyyMMdd-HHmmss"))

    if ($DryRun) {
        Log-Info "[DRY RUN] Would create backup: $backupDir"
        return
    }

    Log-Info "Creating backup of existing installation..."

    try {
        Copy-Item -Recurse -Force $script:ClaudeTarget $backupDir
        Log-Success "Backup created: $backupDir"
        $script:BackupLocation = $backupDir
    } catch {
        Log-Warning "Backup creation failed (continuing anyway)"
    }
}

# Install files from manifest
function Install-Files {
    Log-Info "Installing Agentic Substrate components..."

    # Create directory structure
    $dirs = @("agents", "skills", "commands", "hooks", "validators", "metrics", "templates", "data")
    foreach ($dir in $dirs) {
        $dirPath = Join-Path $script:ClaudeTarget $dir
        if (-not (Test-Path $dirPath)) {
            try {
                New-Item -ItemType Directory -Path $dirPath -Force | Out-Null
            } catch {
                Log-Error "Failed to create installation directories"
                return $false
            }
        }
    }

    # Read managed files from manifest
    $files = Parse-JsonArray -JsonFile $script:ManifestTemplate -ArrayName "managed_files"

    if ($files.Count -eq 0) {
        Log-Error "Failed to read managed files from manifest"
        return $false
    }

    $count = 0
    $total = $files.Count

    # Install each file
    foreach ($file in $files) {
        if (-not $file) { continue }
        $count++

        $sourceFile = Join-Path $script:ClaudeSource $file
        $targetFile = Join-Path $script:ClaudeTarget $file

        if (-not (Test-Path $sourceFile)) {
            Log-Warning "Source file not found (skipping): $file"
            continue
        }

        if ($DryRun) {
            Log-Info "[DRY RUN] Would install [$count/$total]: $file"
        } else {
            # Create parent directory if needed
            $parentDir = Split-Path $targetFile -Parent
            if (-not (Test-Path $parentDir)) {
                New-Item -ItemType Directory -Path $parentDir -Force -ErrorAction SilentlyContinue | Out-Null
            }

            # Copy file
            try {
                Copy-Item -Force $sourceFile $targetFile
                # Log progress every 5 files or last file
                if (($count % 5) -eq 0 -or $count -eq $total) {
                    Log-Info "Progress: $count/$total files installed"
                }
            } catch {
                Log-Warning "Failed to install: $file"
            }
        }
    }

    Log-Success "All managed files installed ($count files)"
    return $true
}

# Set executable permissions (Unix-only, no-op on Windows)
function Set-Permissions {
    if ($DryRun) {
        Log-Info "[DRY RUN] Would set executable permissions on scripts"
        return
    }

    Log-Info "Setting executable permissions..."

    # On Windows, file permissions work differently - scripts are executable by default
    if ($script:OSType -eq "windows") {
        Log-Success "Permissions set (Windows - scripts executable by default)"
        return
    }

    # On Unix (PowerShell Core), set chmod +x
    $execFiles = Parse-JsonArray -JsonFile $script:ManifestTemplate -ArrayName "executable_files"

    if ($execFiles.Count -gt 0) {
        foreach ($file in $execFiles) {
            if (-not $file) { continue }
            $filePath = Join-Path $script:ClaudeTarget $file
            if (Test-Path $filePath) {
                try {
                    & chmod +x $filePath 2>$null
                } catch {}
            }
        }
    }

    Log-Success "Permissions set on executable files"
}

# Smart-merge user-level CLAUDE.md
function SmartMerge-ClaudeMd {
    $source = Join-Path (Join-Path $script:ClaudeSource "templates") "CLAUDE.md.user-level"
    $target = Join-Path $script:ClaudeTarget "CLAUDE.md"
    $backup = Join-Path $script:ClaudeTarget "CLAUDE.md.backup"

    if (-not (Test-Path $source)) {
        Log-Warning "CLAUDE.md.user-level template not found (skipping)"
        return
    }

    if ($DryRun) {
        if (Test-Path $target) {
            Log-Info "[DRY RUN] Would smart-merge user-level CLAUDE.md"
        } else {
            Log-Info "[DRY RUN] Would install user-level CLAUDE.md"
        }
        return
    }

    # If no existing CLAUDE.md, just copy template
    if (-not (Test-Path $target)) {
        Log-Info "Installing user-level CLAUDE.md..."
        try {
            Copy-Item -Force $source $target
            Log-Success "User-level CLAUDE.md installed"
        } catch {
            Log-Warning "Failed to install CLAUDE.md"
        }
        return
    }

    # Existing CLAUDE.md found - smart merge
    Log-Info "Existing CLAUDE.md found - performing smart merge..."

    # Create backup
    try {
        Copy-Item -Force $target $backup
    } catch {}

    # Create merged version
    try {
        $sourceContent = Get-Content -Raw $source
        $targetContent = Get-Content -Raw $target
        $merged = $sourceContent + "`n`n---`n`n# USER CUSTOMIZATIONS (preserved from previous installation)`n`n" + $targetContent

        $tmpFile = "$target.tmp"
        Write-Utf8NoBom -FilePath $tmpFile -Content $merged -NoNewline

        if (Test-Path $tmpFile) {
            Move-Item -Force $tmpFile $target
            Log-Success "User-level CLAUDE.md smart-merged"
            Log-Info "Original backed up to: CLAUDE.md.backup"
        }
    } catch {
        Log-Warning "Smart merge failed, keeping existing CLAUDE.md"
    }
}

# Install MCP config (install-if-missing)
function Install-McpConfig {
    $source = Join-Path (Join-Path $script:ClaudeSource "data") "mcp-config-template.json"
    $target = Join-Path (Join-Path $script:ClaudeTarget "data") "mcp-config.json"

    if (-not (Test-Path $source)) {
        Log-Warning "MCP config template not found (skipping)"
        return
    }

    if ($DryRun) {
        if (Test-Path $target) {
            Log-Info "[DRY RUN] Would preserve existing MCP config"
        } else {
            Log-Info "[DRY RUN] Would install MCP config from template"
        }
        return
    }

    # If MCP config already exists, preserve it
    if (Test-Path $target) {
        Log-Info "Existing MCP config found - preserving user configuration"
        Log-Success "MCP config preserved"
        return
    }

    # No existing config - install from template
    Log-Info "Installing MCP config from template..."
    $dataDir = Join-Path $script:ClaudeTarget "data"
    if (-not (Test-Path $dataDir)) {
        New-Item -ItemType Directory -Path $dataDir -Force -ErrorAction SilentlyContinue | Out-Null
    }

    try {
        Copy-Item -Force $source $target
        Log-Success "MCP config installed from template"
    } catch {
        Log-Warning "Failed to install MCP config"
    }
}

# Install MCP servers
function Install-McpServers {
    if ($DryRun) {
        Log-Info "[DRY RUN] Would configure MCP servers"
        return
    }

    Log-Info "Configuring MCP servers..."

    if (Get-Command claude -ErrorAction SilentlyContinue) {
        Log-Info "Installing DeepWiki MCP..."
        try {
            $output = & claude mcp add -s user -t http deepwiki https://mcp.deepwiki.com/mcp 2>&1
            if ($LASTEXITCODE -eq 0) {
                Log-Success "DeepWiki MCP configured"
            } else {
                Log-Warning "DeepWiki MCP installation failed (non-critical)"
                Log-Info "You can install manually later: claude mcp add -s user -t http deepwiki https://mcp.deepwiki.com/mcp"
            }
        } catch {
            Log-Warning "DeepWiki MCP installation failed (non-critical)"
            Log-Info "You can install manually later: claude mcp add -s user -t http deepwiki https://mcp.deepwiki.com/mcp"
        }
    } else {
        Log-Warning "Claude CLI not found, skipping MCP setup"
        Log-Info "Install Claude CLI then run: claude mcp add -s user -t http deepwiki https://mcp.deepwiki.com/mcp"
    }
}

# Generate manifest in installation
function Generate-Manifest {
    if ($DryRun) {
        Log-Info "[DRY RUN] Would generate installation manifest"
        return
    }

    Log-Info "Generating installation manifest..."

    $manifest = Join-Path $script:ClaudeTarget ".agentic-substrate-manifest.json"
    $timestamp = Safe-Date

    try {
        $data = Get-Content -Raw $script:ManifestTemplate | ConvertFrom-Json
        $data | Add-Member -NotePropertyName "installed_at" -NotePropertyValue $timestamp -Force
        $data | Add-Member -NotePropertyName "installed_by" -NotePropertyValue "install.ps1" -Force
        $jsonStr = $data | ConvertTo-Json -Depth 10
        Write-Utf8NoBom -FilePath $manifest -Content $jsonStr
        Log-Success "Installation manifest created"
    } catch {
        # Fallback: copy template as-is
        try {
            Copy-Item -Force $script:ManifestTemplate $manifest
            Log-Success "Installation manifest created"
        } catch {
            Log-Warning "Failed to create manifest"
        }
    }
}

# Write version file
function Write-VersionFile {
    if ($DryRun) {
        Log-Info "[DRY RUN] Would write version file: $VERSION"
        return
    }

    $versionFile = Join-Path $script:ClaudeTarget ".agentic-substrate-version"
    try {
        Write-Utf8NoBom -FilePath $versionFile -Content $VERSION -NoNewline
        Log-Success "Version file created: v$VERSION"
    } catch {
        Log-Warning "Failed to write version file"
    }
}

# Generate rollback script
function Generate-Rollback {
    if ($DryRun) {
        Log-Info "[DRY RUN] Would generate rollback script"
        return
    }

    if (-not $script:BackupLocation) {
        Log-Info "No backup created - skipping rollback script"
        return
    }

    $rollbackScript = Join-Path $script:ClaudeTarget "rollback-to-previous.ps1"

    $rollbackContent = @"
# Agentic Substrate Rollback Script
`$BackupLocation = "$($script:BackupLocation)"
`$Version = "$VERSION"

Write-Host "Rolling back Agentic Substrate..."
Write-Host "  From: v`$Version"
Write-Host "  Backup: `$BackupLocation"
Write-Host ""

`$reply = Read-Host "Proceed with rollback? (y/N)"
if (`$reply -notmatch '^[Yy]$') {
    Write-Host "Rollback cancelled"
    exit 1
}

if (-not (Test-Path `$BackupLocation)) {
    Write-Host "ERROR: Backup not found: `$BackupLocation" -ForegroundColor Red
    exit 1
}

`$rollbackBackup = Join-Path `$HOME (".claude.rollback-backup-" + (Get-Date -Format "yyyyMMdd-HHmmss"))
Write-Host "Backing up current state to `$rollbackBackup"
Copy-Item -Recurse -Force (Join-Path `$HOME ".claude") `$rollbackBackup -ErrorAction SilentlyContinue

Write-Host "Restoring from backup..."
Remove-Item -Recurse -Force (Join-Path `$HOME ".claude") -ErrorAction SilentlyContinue
try {
    Copy-Item -Recurse -Force `$BackupLocation (Join-Path `$HOME ".claude")
    Write-Host "Rollback complete!"
} catch {
    Write-Host "ERROR: Rollback failed" -ForegroundColor Red
    exit 1
}
"@

    try {
        Write-Utf8NoBom -FilePath $rollbackScript -Content $rollbackContent
        Log-Success "Rollback script created"
    } catch {
        Log-Warning "Failed to create rollback script"
    }
}

# Validate installation
function Validate-Installation {
    if ($DryRun) {
        Log-Info "[DRY RUN] Would validate installation"
        return $true
    }

    Log-Info "Validating installation..."

    $errors = 0

    # Check version file
    $versionFile = Join-Path $script:ClaudeTarget ".agentic-substrate-version"
    if (-not (Test-Path $versionFile)) {
        Log-Error "Version file missing"
        $errors++
    }

    # Check manifest
    $manifestFile = Join-Path $script:ClaudeTarget ".agentic-substrate-manifest.json"
    if (-not (Test-Path $manifestFile)) {
        Log-Error "Manifest file missing"
        $errors++
    } else {
        # Get expected file count dynamically from manifest
        $expected = Count-JsonArray -JsonFile $manifestFile -ArrayName "managed_files"
        if ($expected -gt 0) {
            Log-Info "Expected files: $expected"
        }
    }

    if ($errors -eq 0) {
        Log-Success "Installation validation passed"
        return $true
    } else {
        Log-Error "Installation validation failed with $errors error(s)"
        return $false
    }
}

# Display summary
function Display-Summary {
    Write-Host ""
    Write-Host ([string]::new([char]0x2501, 62))
    Log-Success "Agentic Substrate v$VERSION installed successfully!"
    Write-Host ([string]::new([char]0x2501, 62))
    Write-Host ""

    if ($DryRun) {
        Write-Host "DRY RUN COMPLETE - No changes were made"
        Write-Host "Run without -DryRun to perform actual installation"
        Write-Host ""
        return
    }

    Write-Host "Installation Summary:"
    Write-Host "  Location: $($script:ClaudeTarget)"
    Write-Host "  Version: $VERSION"
    Write-Host "  Agents: 9 | Skills: 8 | Commands: 5"
    Write-Host ""

    if ($script:BackupLocation) {
        Write-Host "Backup Information:"
        Write-Host "  Backup: $($script:BackupLocation)"
        Write-Host "  Rollback: $(Join-Path $script:ClaudeTarget 'rollback-to-previous.ps1')"
        Write-Host ""
    }

    Write-Host "Quick Start:"
    Write-Host "  1. Start Claude Code CLI"
    Write-Host "  2. Try: /workflow Add feature X"
    Write-Host ""

    Write-Host "Documentation:"
    Write-Host "  ~/.claude/CLAUDE.md"
    Write-Host "  ~/.claude/templates/"
    Write-Host ""
}

# ============================================================================
# MAIN EXECUTION
# ============================================================================

function Main {
    # Show help
    if ($Help) {
        Show-Help
    }

    # Initialize
    Detect-OS
    Detect-Terminal

    $psVersion = "$($PSVersionTable.PSVersion.Major).$($PSVersionTable.PSVersion.Minor)"
    Write-Host "Agentic Substrate v$VERSION - Robust Cross-Platform Installation"
    Write-Host ([string]::new([char]0x2501, 62))
    Write-Host "OS: $($script:OSType) | PowerShell: $psVersion"
    Write-Host ""

    if ($DryRun) {
        Log-Warning "DRY RUN MODE - No changes will be made"
        Write-Host ""
    }

    # Acquire lock
    Acquire-Lock

    # Ensure cleanup runs even on Ctrl+C (matches bash trap cleanup EXIT INT TERM)
    Register-EngineEvent -SourceIdentifier PowerShell.Exiting -Action { Invoke-Cleanup } -SupportEvent

    try {
        # Detect install mode and clone if needed
        Detect-CurlInstall
        Clone-Repository

        # Run installation
        Invoke-PreflightChecks
        Create-Backup

        $installResult = Install-Files
        if (-not $installResult) {
            Log-Error "File installation failed"
            exit 1
        }

        Set-Permissions
        SmartMerge-ClaudeMd
        Install-McpConfig
        Install-McpServers
        Generate-Manifest
        Write-VersionFile
        Generate-Rollback

        $validResult = Validate-Installation
        if (-not $validResult) {
            Log-Error "Installation validation failed"
            if ($script:BackupLocation) {
                Log-Info "You can restore from backup: $(Join-Path $script:ClaudeTarget 'rollback-to-previous.ps1')"
            }
            exit 1
        }

        Display-Summary
    } finally {
        Invoke-Cleanup
    }
}

Main
