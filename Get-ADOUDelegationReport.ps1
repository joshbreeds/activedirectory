# NAME: Get-ADOUDelegationReport.ps1
# AUTHOR: Joshua Breeds - 28/07/2025
# SYNOPSIS: Gets reports of delegations of AD OUs.
# LAST EDIT: 28/07/2025

# Import Active Directory Module
Import-Module ActiveDirectory

# Define output file
$OutputFile = ##ENTER FILE PATH OF OUTPUT FILE HERE##

# Create results array
$Results = @()

# Servers OU path
$ServersOUPath = ##ENTER SERVERS OU PATH HERE##

# Get Servers OU from AD
$ServersOU =  Get-ADOrganizationalUnit -Identity $ServersOUPath

# Get all child OUs of Servers OU
$ChildOUs = Get-ADOrganizationalUnit -Filter * -SearchBase $ServersOU.DistinguishedName

# Loop through each child OU
foreach ($OU in $ChildOUs) {
    # Get the delegation information for the OU
    $DelegationInfo = Get-ADObject -Identity $OU.DistinguishedName -Properties msDS-ManagedBy, managedBy
    
    # ACL inspection
    $ACL = Get-Acl -Path "AD:\$($OU.DistinguishedName)"
    $ACLEntries = $ACL.Access | ForEach-Object {
        [PSCustomObject]@{
            IdentityReference = $_.IdentityReference
            ActiveDirectoryRights = $_.ActiveDirectoryRights
            IsInherited = $_.IsInherited
            InheritanceType = $_.InheritanceType
            ObjectType = $_.ObjectType
        }
    }

    # Loop through each ACL entry and create a flattened result
    foreach ($ACLEntry in $ACLEntries) {
        $Result = [PSCustomObject]@{
            OUName                = $OU.Name
            OUDistinguishedName   = $OU.DistinguishedName
            ManagedBy             = $DelegationInfo.managedBy
            ManagedByDN           = $DelegationInfo.'msDS-ManagedBy'
            IdentityReference     = $ACLEntry.IdentityReference
            ActiveDirectoryRights = $ACLEntry.ActiveDirectoryRights
            IsInherited           = $ACLEntry.IsInherited
            InheritanceType       = $ACLEntry.InheritanceType
            ObjectType            = $ACLEntry.ObjectType
        }

        # Add the result to the results array
        $Results += $Result
    }
}

# Export results to CSV
$Results | Export-Csv -Path $OutputFile -NoTypeInformation -Encoding UTF8

