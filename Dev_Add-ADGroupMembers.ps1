<#
.SYNOPSIS
Adds multiple users to an AD group from a list in a .txt file.

.PARAMETER UserNamesFile
Path to a text file containing user names in "First Last" format.

.PARAMETER ADGroup
The name of the Active Directory group to add users to.

.EXAMPLE
.\Add-ADGroupMembers.ps1 -UserNamesFile "C:\Users.txt" -ADGroup "My AD Group"
#>

param (
    [Parameter(Mandatory = $false)]
    [string]$UserNamesFile,

    [Parameter(Mandatory = $false)]
    [string]$ADGroup
)

# Import AD module
Import-Module ActiveDirectory

# Prompt if parameters not provided
if (-not $UserNamesFile) {
    $UserNamesFile = Read-Host "Enter path to the text file with user names"
}
if (-not $ADGroup) {
    $ADGroup = Read-Host "Enter the AD group to add users to"
}

# Validate file
if (-Not (Test-Path -Path $UserNamesFile)) {
    Write-Host "File not found: $UserNamesFile" -ForegroundColor Red
    exit
}

# Confirm group exists
if (-Not (Get-ADGroup -Filter { Name -eq $ADGroup })) {
    Write-Host "The specified AD group does not exist: $ADGroup" -ForegroundColor Red
    exit
}

# Read names
Write-Host "Reading user names from file..." -ForegroundColor Yellow
$UserNamesArray = Get-Content -Path $UserNamesFile
$sAMNamesArray = @()

foreach ($UserName in $UserNamesArray) {
    if ([string]::IsNullOrWhiteSpace($UserName)) { continue }

    $sAMName = $UserName -replace ' ', '.'
    $sAMName = $sAMName.ToLower() -replace '[^a-z.]', ''
    $sAMName = $sAMName.Trim('.')
    $sAMNamesArray += $sAMName
    Write-Host "Formatted sAMAccountName: $sAMName" -ForegroundColor Green
}

# Add users to group
$GroupMembers = Get-ADGroupMember -Identity $ADGroup | Select-Object -ExpandProperty SamAccountName

foreach ($sAMName in $sAMNamesArray) {
    try {
        if ($GroupMembers -contains $sAMName) {
            Write-Host "$sAMName is already a member of $ADGroup" -ForegroundColor Yellow
            continue
        }
        Add-ADGroupMember -Identity $ADGroup -Members $sAMName -ErrorAction Stop
        Write-Host "Added $sAMName to $ADGroup" -ForegroundColor Green
    }
    catch {
        Write-Host "Failed to add $sAMName: $_" -ForegroundColor Red
    }
}

# Done
Write-Host "Done processing users." -ForegroundColor Cyan
