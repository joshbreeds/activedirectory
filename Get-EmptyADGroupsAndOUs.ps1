# NAME: Get-EmptyADGroupsAndOUs.ps1
# AUTHOR: Joshua Breeds - 28/07/2025
# SYNOPSIS: Gets a report of empty AD groups and OUs.
# LAST EDIT: 28/07/2025

# Import the Active Directory module
Import-Module ActiveDirectory

# Define output file
$OutputFile = "C:\Reports\EmptyADGroupsAndOUs.csv"  # Replace with your desired file path

# Create results array
$Results = @()

# Servers OU path
$ServersOUPath = "OU=Servers,DC=example,DC=com"  # Replace with your desired OU path

# Get all OUs in the Servers OU
$OUs = Get-ADOrganizationalUnit -Filter * -SearchBase $ServersOUPath    

# Loop through each OU to check for empty groups
foreach ($OU in $OUs) {
    # Get all groups in the OU
    $Groups = Get-ADGroup -Filter * -SearchBase $OU.DistinguishedName

    foreach ($Group in $Groups) {
        # Skip groups that match the specified pattern
        if ($Group.Name -match '^.+ - (ServerAdmins|RDPUsers|LogOnAsService)$') {
            continue
        }

        # Check if the group is empty
        $Members = Get-ADGroupMember -Identity $Group.DistinguishedName -ErrorAction SilentlyContinue
        if ($Members.Count -eq 0) {
            $Results += [PSCustomObject]@{
                Type               = "Group"
                Name               = $Group.Name
                DistinguishedName  = $Group.DistinguishedName
                OU                 = $OU.Name
            }
        }
    }
}

# Loop through each OU again to check for empty OUs
foreach ($OU in $OUs) {
    # Get child OUs
    $ChildOUs = Get-ADOrganizationalUnit -Filter * -SearchBase $OU.DistinguishedName

    # Skip OUs that match the specified pattern
    if ($OU.Name -match '^.+ - (Servers|Security Groups)$') {
        continue
    }

    # Check if the OU is empty (no child OUs and no groups)
    $GroupsInOU = Get-ADGroup -Filter * -SearchBase $OU.DistinguishedName
    if ($ChildOUs.Count -eq 0 -and $GroupsInOU.Count -eq 0) {
        $Results += [PSCustomObject]@{
            Type               = "OU"
            Name               = $OU.Name
            DistinguishedName  = $OU.DistinguishedName
            ParentOU           = (Get-ADOrganizationalUnit -Identity $OU.DistinguishedName).Parent
        }
    }
}

# Export results to CSV
$Results | Export-Csv -Path $OutputFile -NoTypeInformation -Encoding UTF8

# Output completion message
Write-Host "Report generated and saved to $OutputFile" -ForegroundColor Green

# End of script
