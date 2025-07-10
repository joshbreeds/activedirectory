<#
.SYNOPSIS
Creates server-related Active Directory groups, OUs, and GPOs in a specified OU.

.DESCRIPTION
This script prompts for input of a Site Code and Service Name and then:
1. Creates the required Organizational Units (OUs) if they don't exist.
2. Creates three Active Directory groups for server access.
3. Moves existing server objects from a specified OU to the new service OU.
4. Creates three Group Policy Objects (GPOs) and links them to the service OU.

.NOTES
Author: ChatGPT Refactored
#>

function Validate-YesNo {
    param (
        [string]$Prompt
    )
    do {
        $response = Read-Host "$Prompt (Y/N)"
    } while ($response -notmatch '^[YyNn]$')
    return $response.ToUpper() -eq 'Y'
}

function New-ServiceOU {
    param (
        [string]$ParentOU,
        [string]$OUName
    )

    $fullPath = "OU=$OUName,$ParentOU"
    if (-not (Get-ADOrganizationalUnit -Filter "DistinguishedName -eq '$fullPath'" -ErrorAction SilentlyContinue)) {
        New-ADOrganizationalUnit -Name $OUName -Path $ParentOU
        Write-Host "Created OU: $fullPath"
    } else {
        Write-Host "OU already exists: $fullPath"
    }
    return $fullPath
}

function Create-ServerGroups {
    param (
        [string]$OUPath,
        [string]$SiteCode,
        [string]$ServiceName
    )

    $groupTypes = @("Admins", "Ops", "Mon")
    foreach ($type in $groupTypes) {
        $groupName = "$SiteCode-$ServiceName-$type"
        if (-not (Get-ADGroup -Filter "Name -eq '$groupName'" -ErrorAction SilentlyContinue)) {
            New-ADGroup -Name $groupName -GroupScope Global -GroupCategory Security -Path $OUPath
            Write-Host "Created Group: $groupName"
        } else {
            Write-Host "Group already exists: $groupName"
        }
    }
}

function Move-ServerObjects {
    param (
        [string]$SourceOU,
        [string]$TargetOU
    )

    $servers = Get-ADComputer -SearchBase $SourceOU -Filter * -SearchScope OneLevel
    foreach ($server in $servers) {
        Move-ADObject -Identity $server.DistinguishedName -TargetPath $TargetOU
        Write-Host "Moved: $($server.Name)"
    }
}

function Create-ServerGPOs {
    param (
        [string]$OUName,
        [string]$FullOUPath,
        [string]$SiteCode
    )

    $gpoTypes = @("Baseline", "Security", "Apps")
    foreach ($type in $gpoTypes) {
        $gpoName = "$SiteCode-$OUName-$type"
        if (-not (Get-GPO -Name $gpoName -ErrorAction SilentlyContinue)) {
            $gpo = New-GPO -Name $gpoName
            New-GPLink -Name $gpo.DisplayName -Target $FullOUPath
            Write-Host "Created and linked GPO: $gpoName"
        } else {
            Write-Host "GPO already exists: $gpoName"
        }
    }
}

# Script Execution Starts Here

$siteCode = Read-Host "Enter Site Code (e.g., LDN)"
$servicesOU = "OU=Services,OU=Servers,DC=contoso,DC=com"

# Display available OUs
$ous = Get-ADOrganizationalUnit -SearchBase $servicesOU -Filter * | Select-Object -ExpandProperty Name
Write-Host "Existing OUs under Services:"
$ous | ForEach-Object { Write-Host "- $_" }

$createNewOU = Validate-YesNo -Prompt "Would you like to create a new Service OU?"
if ($createNewOU) {
    $ouName = Read-Host "Enter new Service OU name (e.g., Print)"
    $targetOU = New-ServiceOU -ParentOU $servicesOU -OUName $ouName
} else {
    $selection = Read-Host "Enter the name of the existing OU to use"
    if ($ous -notcontains $selection) {
        Write-Host "Invalid OU name. Exiting."
        exit
    }
    $targetOU = "OU=$selection,$servicesOU"
    $ouName = $selection
}

Create-ServerGroups -OUPath $targetOU -SiteCode $siteCode -ServiceName $ouName

$moveServers = Validate-YesNo -Prompt "Would you like to move servers to the new OU?"
if ($moveServers) {
    $sourceOU = Read-Host "Enter source OU DN (e.g., OU=OldServers,OU=Servers,DC=contoso,DC=com)"
    Move-ServerObjects -SourceOU $sourceOU -TargetOU $targetOU
}

$createGPOs = Validate-YesNo -Prompt "Would you like to create and link GPOs to the new OU?"
if ($createGPOs) {
    Create-ServerGPOs -OUName $ouName -FullOUPath $targetOU -SiteCode $siteCode
}

Write-Host "Script completed successfully."
