# NAME: Get-StaleADComputers.ps1
# AUTHOR: Joshua Breeds - 28/07/2025
# SYNOPSIS: Gets a report of stale AD Computers based on last logon time.
# LAST EDIT: 28/07/2025

# Import the Active Directory module
Import-Module ActiveDirectory

# Define output file
$OutputFile = ##ENTER FILE PATH OF OUTPUT FILE HERE##

# Create results array
$Results = @()

# Servers OU path
$ServersOUPath = ##ENTER SERVERS OU PATH HERE##

# Get Servers OU from AD
$ServersOU =  Get-ADOrganizationalUnit -Identity $ServersOUPath

# Get all computer accounts in the Servers OU and child OUs
$Computers = Get-ADComputer -Filter * -SearchBase $ServersOU.DistinguishedName -Properties LastLogonDate

# Filter for stale computers (not logged on in the last 60 days)
$StaleComputers = $Computers | Where-Object {
    $_.LastLogonDate -eq $null -or
    $_.LastLogonDate -lt (Get-Date).AddDays(-60)
}

# Process each stale computer
foreach ($Computer in $StaleComputers) {
    $Results += [PSCustomObject]@{
        Name            = $Computer.Name
        DistinguishedName = $Computer.DistinguishedName
        LastLogonDate   = $Computer.LastLogonDate
    }
}

# Export results to CSV
$Results | Export-Csv -Path $OutputFile -NoTypeInformation

# Output the results to the console
$Results | Format-Table -AutoSize

# Notify user of completion
Write-Host "Stale AD Computers report generated and saved to $OutputFile" -ForegroundColor Green


