<#
.SYNOPSIS
    Syncs specific folders from the Code repository to the DV CoE Azure DevOps repository.

.DESCRIPTION
    This script mirrors selected folders from your personal Code directory to the 
    Global DV CoE repository, preserving folder structure. It can optionally commit 
    and push changes to the ADO remote.

.PARAMETER Execute
    Actually perform the sync. Without this flag, the script runs in preview mode.

.PARAMETER Commit
    Stage and commit changes after syncing. Requires -Execute.

.PARAMETER Push
    Push commits to the remote repository. Requires -Commit.

.PARAMETER Message
    Custom commit message. Default: "Sync from Code repository - <timestamp>"

.EXAMPLE
    .\Sync-DVCoE.ps1
    # Preview mode - shows what would be synced without making changes

.EXAMPLE
    .\Sync-DVCoE.ps1 -Execute
    # Sync files only, no git operations

.EXAMPLE
    .\Sync-DVCoE.ps1 -Execute -Commit -Push
    # Full sync: copy files, commit, and push to ADO

.EXAMPLE
    .\Sync-DVCoE.ps1 -Execute -Commit -Push -Message "Updated SQL queries for Q1 reporting"
    # Full sync with custom commit message
#>

[CmdletBinding(SupportsShouldProcess)]
param(
    [switch]$Execute,
    [switch]$Commit,
    [switch]$Push,
    [string]$Message = "Sync from Code repository - $(Get-Date -Format 'yyyy-MM-dd HH:mm')"
)

# ============================================================================
# CONFIGURATION
# ============================================================================

$SourceRoot = "C:\Users\U15405\OneDrive - Kimberly-Clark\Desktop\Code"
$DestRoot = "C:\Users\U15405\OneDrive - Kimberly-Clark\Desktop\Files\DV CoE\Global DV CoE"

# Folders to sync (relative to source root)
# Format: @{ Source = "relative\path"; Dest = "relative\path" }
$FolderMappings = @(
    @{ Source = "Copilot"; Dest = "Copilot" }
    @{ Source = "SQL\DV CoE Queries"; Dest = "SQL\DV CoE Queries" }
    @{ Source = "SQL\PBI Statistics - Azure"; Dest = "SQL\PBI Statistics - Azure" }
    @{ Source = "Python\Azure Dev Ops"; Dest = "Python\Azure Dev Ops" }
    @{ Source = "Python\Download Folder - PBIX Purge"; Dest = "Python\Download Folder - PBIX Purge" }
    @{ Source = "Python\Tableau License Management"; Dest = "Python\Tableau License Management" }
    @{ Source = "PowerQuery"; Dest = "PowerQuery" }
    @{ Source = ".net\PBI_ & TAB_ AD Groups"; Dest = ".net\PBI_ & TAB_ AD Groups" }
    @{ Source = "Tabular Editor - C#"; Dest = "Tabular Editor - C#" }
)

# Directories to exclude from sync
$ExcludeDirs = @(
    "__pycache__"
    ".pytest_cache"
    ".git"
    ".venv"
    "venv"
    "node_modules"
    ".vs"
    "bin"
    "obj"
)

# File patterns to exclude from sync
$ExcludeFiles = @(
    "*.pyc"
    "*.pyo"
    "*.pyd"
    "*.dll"
    "*.exe"
    "*.so"
    "*.dylib"
    "*.cache"
    "*.log"
    "Thumbs.db"
    ".DS_Store"
)

# ============================================================================
# FUNCTIONS
# ============================================================================

function Write-Header {
    param([string]$Text)
    Write-Host "`n$('=' * 60)" -ForegroundColor Cyan
    Write-Host " $Text" -ForegroundColor Cyan
    Write-Host "$('=' * 60)" -ForegroundColor Cyan
}

function Write-FolderStatus {
    param(
        [string]$Source,
        [string]$Dest,
        [string]$Status,
        [string]$Color = "White"
    )
    Write-Host "  [$Status] " -ForegroundColor $Color -NoNewline
    Write-Host "$Source " -ForegroundColor Yellow -NoNewline
    Write-Host "-> " -NoNewline
    Write-Host "$Dest" -ForegroundColor Green
}

function Sync-Folder {
    param(
        [string]$SourcePath,
        [string]$DestPath,
        [bool]$PreviewOnly
    )
    
    if (-not (Test-Path $SourcePath)) {
        Write-Host "    [SKIP] Source folder does not exist: $SourcePath" -ForegroundColor Red
        return $false
    }
    
    # Ensure destination parent directory exists
    $destParent = Split-Path $DestPath -Parent
    if (-not (Test-Path $destParent)) {
        if ($PreviewOnly) {
            Write-Host "    [WOULD CREATE] $destParent" -ForegroundColor DarkGray
        } else {
            New-Item -ItemType Directory -Path $destParent -Force | Out-Null
            Write-Host "    [CREATED] $destParent" -ForegroundColor DarkYellow
        }
    }
    
    if ($PreviewOnly) {
        # Use robocopy in list-only mode with exclusions
        $robocopyArgs = @($SourcePath, $DestPath, "/MIR", "/L", "/NJH", "/NJS", "/NDL", "/NC", "/NS")
        # Add directory exclusions
        if ($ExcludeDirs.Count -gt 0) {
            $robocopyArgs += "/XD"
            $robocopyArgs += $ExcludeDirs
        }
        # Add file exclusions
        if ($ExcludeFiles.Count -gt 0) {
            $robocopyArgs += "/XF"
            $robocopyArgs += $ExcludeFiles
        }
        $output = & robocopy @robocopyArgs 2>&1
        $changedFiles = $output | Where-Object { $_ -match '\S' }
        
        if ($changedFiles.Count -gt 0) {
            Write-Host "    Files that would be synced:" -ForegroundColor DarkGray
            $changedFiles | ForEach-Object { Write-Host "      $_" -ForegroundColor DarkGray }
        } else {
            Write-Host "    [UP TO DATE] No changes needed" -ForegroundColor DarkGreen
        }
    } else {
        # Actually sync with robocopy /MIR (mirror) with exclusions
        $robocopyArgs = @($SourcePath, $DestPath, "/MIR", "/NJH", "/NJS", "/NDL", "/NC", "/NS")
        # Add directory exclusions
        if ($ExcludeDirs.Count -gt 0) {
            $robocopyArgs += "/XD"
            $robocopyArgs += $ExcludeDirs
        }
        # Add file exclusions
        if ($ExcludeFiles.Count -gt 0) {
            $robocopyArgs += "/XF"
            $robocopyArgs += $ExcludeFiles
        }
        $output = & robocopy @robocopyArgs 2>&1
        $changedFiles = $output | Where-Object { $_ -match '\S' }
        
        if ($changedFiles.Count -gt 0) {
            Write-Host "    Synced files:" -ForegroundColor Green
            $changedFiles | ForEach-Object { Write-Host "      $_" -ForegroundColor Green }
        } else {
            Write-Host "    [UP TO DATE] No changes needed" -ForegroundColor DarkGreen
        }
    }
    
    return $true
}

# ============================================================================
# MAIN SCRIPT
# ============================================================================

# Header
Write-Header "DV CoE Repository Sync Tool"

# Validate parameters
if ($Push -and -not $Commit) {
    Write-Host "[ERROR] -Push requires -Commit flag" -ForegroundColor Red
    exit 1
}

if ($Commit -and -not $Execute) {
    Write-Host "[ERROR] -Commit requires -Execute flag" -ForegroundColor Red
    exit 1
}

# Display mode
if (-not $Execute) {
    Write-Host "`n[PREVIEW MODE] No changes will be made. Use -Execute to sync files.`n" -ForegroundColor Yellow
} else {
    Write-Host "`n[EXECUTE MODE] Files will be synced.`n" -ForegroundColor Green
}

# Display paths
Write-Host "Source: $SourceRoot" -ForegroundColor DarkGray
Write-Host "Destination: $DestRoot" -ForegroundColor DarkGray

# Process each folder mapping
Write-Header "Syncing Folders"

$syncCount = 0
foreach ($mapping in $FolderMappings) {
    $sourcePath = Join-Path $SourceRoot $mapping.Source
    $destPath = Join-Path $DestRoot $mapping.Dest
    
    Write-Host "`n[$($syncCount + 1)/$($FolderMappings.Count)] $($mapping.Source)" -ForegroundColor White
    
    $result = Sync-Folder -SourcePath $sourcePath -DestPath $destPath -PreviewOnly (-not $Execute)
    if ($result) { $syncCount++ }
}

Write-Host "`n"

# Git operations
if ($Execute -and $Commit) {
    Write-Header "Git Operations"
    
    Push-Location $DestRoot
    
    try {
        # Stage all changes
        Write-Host "Staging changes..." -ForegroundColor Cyan
        git add -A
        
        # Check if there are changes to commit
        $status = git status --porcelain
        if ($status) {
            Write-Host "Committing with message: $Message" -ForegroundColor Cyan
            git commit -m $Message
            
            if ($Push) {
                Write-Host "Pushing to remote..." -ForegroundColor Cyan
                git push
                Write-Host "[SUCCESS] Changes pushed to ADO repository!" -ForegroundColor Green
            } else {
                Write-Host "[INFO] Changes committed locally. Use -Push to push to remote." -ForegroundColor Yellow
            }
        } else {
            Write-Host "[INFO] No changes to commit - repository is up to date." -ForegroundColor Yellow
        }
    }
    finally {
        Pop-Location
    }
}

# Summary
Write-Header "Summary"
Write-Host "Folders processed: $syncCount / $($FolderMappings.Count)" -ForegroundColor White

if (-not $Execute) {
    Write-Host "`nTo execute the sync, run:" -ForegroundColor Yellow
    Write-Host "  .\Sync-DVCoE.ps1 -Execute                  # Sync files only" -ForegroundColor DarkGray
    Write-Host "  .\Sync-DVCoE.ps1 -Execute -Commit          # Sync + commit" -ForegroundColor DarkGray
    Write-Host "  .\Sync-DVCoE.ps1 -Execute -Commit -Push    # Sync + commit + push" -ForegroundColor DarkGray
}

Write-Host ""
