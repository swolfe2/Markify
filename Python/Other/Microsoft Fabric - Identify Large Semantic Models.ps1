# ============================================
# Power BI - Large Dataset Report (Single Workspace + XMLA Size)
# Author: Elden Lord Copilot 🐈‍⬛
# ============================================

# -------- Settings --------
$TargetWorkspaceName     = "GL DV COE - Adhoc"     # << change or keep as-is
$OutputFolder            = "C:\Temp"
$FilePrefix              = "PowerBI_LargeDataset_SingleWS_XMLA"
$SleepMsBetweenDatasets  = 100   # Helps avoid throttling
$RequirePremiumWorkspace = $true # XMLA read requires Premium/PPU
# -------------------------

# Ensure output folder exists
if (-not (Test-Path $OutputFolder)) { New-Item -Path $OutputFolder -ItemType Directory | Out-Null }
$Timestamp   = Get-Date -Format 'yyyyMMdd_HHmm'
$OutputPath  = Join-Path $OutputFolder "$FilePrefix`_$Timestamp.csv"
$LogPath     = Join-Path $OutputFolder "$FilePrefix`_$Timestamp.log"

# -------- Modules --------
$modules = @('MicrosoftPowerBIMgmt','SqlServer')  # SqlServer provides ADOMD client + Invoke-ASCmd
foreach ($m in $modules) {
    if (-not (Get-Module -ListAvailable -Name $m)) {
        Write-Host "Installing module: $m ..."
        Install-Module -Name $m -Scope CurrentUser -Force -ErrorAction Stop
    }
    Import-Module $m -ErrorAction Stop
}

# -------- Connect to Power BI --------
Write-Host "Connecting to Power BI Service..."
$connection = Connect-PowerBIServiceAccount
"`nEnvironment : $($connection.Environment)" | Tee-Object -FilePath $LogPath -Append
"TenantId    : $($connection.TenantId)"       | Tee-Object -FilePath $LogPath -Append
"UserName    : $($connection.UserName)"       | Tee-Object -FilePath $LogPath -Append

# Access token for XMLA ADOMD connection
try {
    $accessToken = (Get-PowerBIAccessToken).AccessToken
} catch {
    throw "Failed to obtain Power BI access token. Cannot use XMLA. $($_.Exception.Message)"
}

# -------- Helpers --------
function Write-LogWarn {
    param([string]$Message)
    $Message | Tee-Object -FilePath $LogPath -Append | Write-Warning
}

function Invoke-AdomdQuery {
    <#
      Executes a DMV query against a dataset via ADOMD.NET using the current AAD access token.
      Returns a DataTable (or $null on error).
    #>
    param(
        [Parameter(Mandatory)][string]$WorkspaceName,
        [Parameter(Mandatory)][string]$DatabaseName,
        [Parameter(Mandatory)][string]$Query
    )
    try {
        # Connection string using AAD token
        # Note: 'User ID' can be blank; 'Password' carries the bearer token.
        $connStr = "Provider=MSOLAP;Data Source=powerbi://api.powerbi.com/v1.0/myorg/$WorkspaceName;User ID=;Password=$accessToken;Persist Security Info=True;"
        Add-Type -AssemblyName "Microsoft.AnalysisServices.AdomdClient" -ErrorAction SilentlyContinue
        $conn = New-Object Microsoft.AnalysisServices.AdomdClient.AdomdConnection($connStr)
        $conn.Open()
        $conn.ChangeDatabase($DatabaseName)

        $cmd = $conn.CreateCommand()
        $cmd.CommandText = $Query

        $adapter = New-Object Microsoft.AnalysisServices.AdomdClient.AdomdDataAdapter($cmd)
        $table = New-Object System.Data.DataTable
        [void]$adapter.Fill($table)

        $conn.Close()
        return $table
    }
    catch {
        Write-LogWarn "ADOMD query failed on '$DatabaseName' in '$WorkspaceName': $($_.Exception.Message)"
        return $null
    }
}

function Invoke-PBIGetJson {
    param([Parameter(Mandatory)][string]$Url)
    try {
        $raw = Invoke-PowerBIRestMethod -Url $Url -Method Get -ErrorAction Stop
        if ([string]::IsNullOrWhiteSpace($raw)) { return $null }
        return ($raw | ConvertFrom-Json)
    }
    catch {
        Write-LogWarn "REST GET failed: $Url`n$($_.Exception.Message)"
        return $null
    }
}

# -------- Resolve Workspace --------
Write-Host "Retrieving workspace: $TargetWorkspaceName"
$workspace = Get-PowerBIWorkspace -Scope Individual -All | Where-Object { $_.Name -eq $TargetWorkspaceName } | Select-Object -First 1

if (-not $workspace) { throw "Workspace '$TargetWorkspaceName' not found in your scope." }

if ($RequirePremiumWorkspace -and (-not $workspace.CapacityId)) {
    throw "Workspace '$($workspace.Name)' is not on Premium capacity (CapacityId is null). XMLA read requires Premium or PPU."
}

# -------- Get Datasets in Workspace --------
try {
    $datasets = Get-PowerBIDataset -WorkspaceId $workspace.Id -ErrorAction Stop
} catch {
    throw "Failed to list datasets for workspace '$($workspace.Name)': $($_.Exception.Message)"
}

if (-not $datasets) {
    Write-Host "No datasets found in workspace '$($workspace.Name)'."
    "" | Out-File -FilePath $OutputPath
    return
}

# -------- Process Datasets --------
$results = New-Object System.Collections.Generic.List[object]
$idx = 0
$total = $datasets.Count

foreach ($ds in $datasets) {
    $idx++
    Write-Host ("[{0}/{1}] Dataset: {2}" -f $idx, $total, $ds.Name)

    $owner              = $ds.ConfiguredBy
    $largeDatasetFlag   = $null  # true/false/null
    $datasetSizeMB      = 'Unavailable'

    # -- Try REST for Large Dataset toggle & sizeInBytes --
    $detailUrl = "groups/$($workspace.Id)/datasets/$($ds.Id)"
    $details   = Invoke-PBIGetJson -Url $detailUrl

    if ($details) {
        if ($details.PSObject.Properties.Name -contains 'configuredBy') {
            $owner = $details.configuredBy
        }
        if ($details.PSObject.Properties.Name -contains 'isLargeDatasetStorageFormat') {
            $largeDatasetFlag = [bool]$details.isLargeDatasetStorageFormat
        }
        if ($details.PSObject.Properties.Name -contains 'sizeInBytes' -and $details.sizeInBytes) {
            $datasetSizeMB = [math]::Round(([double]$details.sizeInBytes / 1MB), 2)
        }
    }

    # -- XMLA DMV fallback for size (and best-effort inference for large flag) --
    # Size from $SYSTEM.DISCOVER_STORAGE_TABLES (sum USED_SIZE)
    # Note: USED_SIZE is in bytes for Power BI XMLA rowset.
    if ($datasetSizeMB -eq 'Unavailable') {
        $dt = Invoke-AdomdQuery -WorkspaceName $workspace.Name -DatabaseName $ds.Name -Query "SELECT * FROM $SYSTEM.DISCOVER_STORAGE_TABLES"
        if ($dt -and $dt.Rows.Count -gt 0 -and $dt.Columns.Contains('USED_SIZE')) {
            try {
                $totalBytes = 0
                foreach ($row in $dt.Rows) {
                    # Some rows may have null/empty USED_SIZE
                    if ($row.USED_SIZE -ne $null -and "$($row.USED_SIZE)".Trim() -ne "") {
                        $totalBytes += [double]$row.USED_SIZE
                    }
                }
                if ($totalBytes -gt 0) {
                    $datasetSizeMB = [math]::Round(($totalBytes / 1MB), 2)
                }
            } catch {
                Write-LogWarn "Failed to sum USED_SIZE for dataset '$($ds.Name)': $($_.Exception.Message)"
            }
        }
    }

    # Try to infer Large Dataset via Extended Properties (best-effort)
    if ($null -eq $largeDatasetFlag) {
        $ep = Invoke-AdomdQuery -WorkspaceName $workspace.Name -DatabaseName $ds.Name -Query "SELECT * FROM $SYSTEM.DISCOVER_EXTENDED_PROPERTIES"
        if ($ep -and $ep.Rows.Count -gt 0 -and $ep.Columns.Contains('PROPERTY_NAME') -and $ep.Columns.Contains('PROPERTY_VALUE')) {
            # Known candidates seen in the wild (tenants differ). We'll match semantically.
            $candidates = @('PBIDatasetStorageFormat','PBIDatabaseStorageEngineUsed','StorageFormat','PBIStorageFormat','PBIDatasetEngineVersion')
            $hit = $ep | Where-Object { $candidates -contains $_.PROPERTY_NAME } | Select-Object -First 1
            if ($hit) {
                $val = "$($hit.PROPERTY_VALUE)"
                if ($val -match '(?i)\bLarge\b|V3|3')       { $largeDatasetFlag = $true }
                elseif ($val -match '(?i)\bSmall\b|V2|2')   { $largeDatasetFlag = $false }
            }
        }
    }

    # Normalize nulls/empties for CSV clarity
    $ownerStr = if ($owner) { $owner } else { 'Unavailable' }
    $largeStr = if ($null -ne $largeDatasetFlag) { [bool]$largeDatasetFlag } else { $null }

    $results.Add([PSCustomObject]@{
        WorkspaceName        = $workspace.Name
        WorkspaceID          = $workspace.Id
        DatasetName          = $ds.Name
        DatasetID            = $ds.Id
        DatasetOwner         = $ownerStr
        LargeDatasetEnabled  = $largeStr
        DatasetSizeMB        = $datasetSizeMB
    })

    Start-Sleep -Milliseconds $SleepMsBetweenDatasets
}

# -------- Export & Summary --------
$results | Export-Csv -Path $OutputPath -NoTypeInformation
Write-Host "`n✅ Report exported: $OutputPath"

$enabledCount    = ($results | Where-Object { $_.LargeDatasetEnabled -eq $true }).Count
$falseCount      = ($results | Where-Object { $_.LargeDatasetEnabled -eq $false }).Count
$unknownCount    = ($results | Where-Object { $null -eq $_.LargeDatasetEnabled }).Count
$totalDatasets   = $results.Count

$summary = @"
-----------------------------------------
Summary (Workspace: $($workspace.Name))
-----------------------------------------
Datasets scanned        : $totalDatasets
Large Dataset = TRUE    : $enabledCount
Large Dataset = FALSE   : $falseCount
Large Dataset = Unknown : $unknownCount
CSV                     : $OutputPath
Log                     : $LogPath
"@

$summary | Tee-Object -FilePath $LogPath -Append
Write-Host $summary