# NAME: Get-AdminAccountsGroupMemberships.ps1
# AUTHOR: Joshua Breeds - 28/07/2025
# SYNOPSIS: Gets a report of group memberships for admin accounts.
# LAST EDIT: 28/07/2025

# Import the Active Directory module
Import-Module ActiveDirectory

# Define output file
$OutputFile = "C:\Reports\AdminAccountsGroupMemberships.csv"  # Replace with your desired file path

# Create results array
$Results = @()

# Admin accounts OU path
$AdminAccountsOUPath = "OU=Servers,DC=example,DC=com"  # Replace with your desired OU path

# Get all admin accounts in the admin accounts OU
$AdminAccounts = Get-ADUser -Filter * -SearchBase $AdminAccountsOUPath -Properties MemberOf, DisplayName, DistinguishedName

# Cache for group info
$GroupCache = @{}

# Loop through each admin account
foreach ($AdminAccount in $AdminAccounts) {
    # Initialize an array to hold group names
    $GroupNames = @()

    if ($AdminAccount.MemberOf) {
        # Get the group memberships for the admin account
        foreach ($GroupDN in $AdminAccount.MemberOf) {
            if (-not $GroupCache.ContainsKey($GroupDN)) {
                try {
                    $GroupCache[$GroupDN] = (Get-ADGroup $GroupDN -Properties Name -ErrorAction Stop).Name
                } catch {
                    $GroupCache[$GroupDN] = "Group Not Found"
                }
            }
            $GroupNames += $GroupCache[$GroupDN]
        }
    } else {
        # If no group memberships, add "No Groups"
        $GroupNames += "No Groups"
    }

    # Add the admin account and its group memberships to the results array
    $Results += [PSCustomObject]@{
        AdminAccount       = $AdminAccount.SamAccountName
        DisplayName        = $AdminAccount.DisplayName
        DistinguishedName  = $AdminAccount.DistinguishedName
        GroupMemberships   = ($GroupNames -join ", ")
    }
}

# Export the results to a CSV file
$Results | Export-Csv -Path $OutputFile -NoTypeInformation -Encoding UTF8

# Output completion message
Write-Host "Group memberships for admin accounts have been exported to $OutputFile"

# End of script
