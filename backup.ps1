# Windows Backup script
param (
    [Parameter(Mandatory = $false)]
    [string]$destDrive,

    [Parameter(Mandatory = $false)]
    [string]$targetDrive,

    [Parameter(Mandatory = $false)]
    [switch]$confirm
)

# Relaunch script as admin if not already elevated
if (-not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Write-Output "Restarting script with administrative privileges..."

    # Build argument list dynamically
    $argList = @()
    if ($destDrive)    { $argList += "-destDrive `"$destDrive`"" }
    if ($targetDrive)  { $argList += "-targetDrive `"$targetDrive`"" }
    if ($confirm)      { $argList += "-confirm" }

    Start-Process powershell -ArgumentList "-ExecutionPolicy Bypass -File `"$PSCommandPath`" $($argList -join ' ')" -Verb RunAs
    exit
}

Write-Output "Windows Backup Script"

# Prompt for missing parameters
if (-not $targetDrive) {
    $targetDrive = Read-Host "What drive is being backed up?"
}

if (-not $destDrive) {
    $destDrive = Read-Host "Where is the backup being stored?"
}

# Sanitize drive letters (remove colons)
$targetDrive = $targetDrive.TrimEnd(":")
$destDrive   = $destDrive.TrimEnd(":")

# Construct proper volume paths
$targetPath = "$targetDrive`:\"
$destPath   = "$destDrive`:\"

# Validate that the target drive exists
if (Get-PSDrive -Name $targetDrive -ErrorAction SilentlyContinue) {
    Write-Output "Drive $targetDrive exists."
} else {
    Write-Output "Drive $targetDrive does not exist."
    exit
}

# Show estimated backup size
Get-PSDrive $targetDrive | Format-Table `
  @{Label = "Drive Letter"; Expression = { $_.Name } }, `
  @{Label = "Backup Size (GB)"; Expression = { [math]::Round($_.Used / 1GB, 2) } }

# Show destination drive stats
Get-Volume -DriveLetter $destDrive | Format-Table `
  @{Label = "Available (GB)"; Expression = { [math]::Round($_.SizeRemaining / 1GB, 2) } }, `
  @{Label = "Total (GB)"; Expression = { [math]::Round($_.Size / 1GB, 2) } }

# Confirmation
if (-not $confirm) {
    $response = Read-Host "Are you sure you want to do this? It may take a while. (Y/N)"
    if ($response -ne "Y") {
        Write-Output "Backup cancelled."
        exit
    }
} else {
    Write-Output "Confirmation flag detected. Proceeding with backup..."
}

# Run the backup
wbadmin start backup -backupTarget:$destPath -include:$targetPath -allCritical -quiet