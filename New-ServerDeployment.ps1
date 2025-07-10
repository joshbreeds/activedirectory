# NAME: New-ADServerGroups.ps1
# AUTHOR: Joshua Breeds - 03/07/2025
# SYNOPSIS: Creates new service OUs/server AD security groups after VMWare deployment.
# LAST EDIT: 07/07/2025

Write-Host "Welcome to the New-ServerDeployment script!" -ForegroundColor Cyan
Write-Host "This script will help you create the necessary AD groups/OUs for new servers or services." -ForegroundColor Cyan

# Check the server has been deployed
$ServerCheck = Read-Host "Have the new server(s) been deployed and ran the post install configuration in VMware? (Y/N)"
if ($ServerCheck -eq 'Y') {
    Write-Host "You have confirmed that the server(s) have been deployed." -ForegroundColor Green
} elseif ($ServerCheck -eq 'N') {
    Write-Host "Please ensure that the deployment has finished before running this script." -ForegroundColor Red
    exit
} else {
    Write-Host "Invalid input. Please enter Y or N." -ForegroundColor Red
    exit
}

# Ask for the Jira DP ticket number
$TicketNumber = Read-Host "What is the Jira DP ticket number for this request? (Example: DP-123456)"

# Has the service and related servers been added to CMDB?
$CMDBCheck = Read-Host "Has the service and the new servers been added to CMDB? (Y/N)"
if ($CMDBCheck -eq 'Y') {
    Write-Host "You have confirmed that the service and the new servers have been added to CMDB." -ForegroundColor Green
} elseif ($CMDBCheck -eq 'N') {
    Write-Host "Please ensure that the service and related servers are added to CMDB before proceeding. Please contact Jonathan Dean if you need assistance." -ForegroundColor Red
    exit
} else {
    Write-Host "Invalid input. Please enter Y or N." -ForegroundColor Red
    exit
}

# Search AD for the OU of the service
$ADServiceOU = Read-Host "What is the name of the service your server(s) are running? (Example: CROWN DMS, NICHE etc)"
$BaseOU = "OU=Servers,OU=Northumbria Police,OU=Data Management,DC=nbria,DC=police,DC=cjx,DC=gov,DC=uk"

# Get the OU object(s) matching the name
$ExistingOUs = Get-ADOrganizationalUnit -Filter "Name -like '*$ADServiceOU*'" -SearchBase $BaseOU -ErrorAction SilentlyContinue

if ($ExistingOUs) {
    Write-Host "Found the following OUs:"
    $ExistingOUs | Select-Object Name, DistinguishedName | Format-Table -AutoSize
} else {
    Write-Host "No matching OUs found for $ADServiceOU." -ForegroundColor Red
    $createNewOU = Read-Host "Would you like to create a new OU for this service? (Y/N)"
    if ($createNewOU -eq 'Y') {
        # Creating a new OU structure
        Write-Host "Ok, let's create a new OU and sub OUs for this service..." -ForegroundColor Yellow
        $NewOUName = Read-Host "What is the name the new OU for this service/application?"
        $ServiceOU = "OU=$NewOUName,$BaseOU"

        Write-Host "Building new OU structure..." -ForegroundColor Yellow
        New-ADOrganizationalUnit -Name $NewOUName -Path $BaseOU
        Write-Host "Created OU: $NewOUName" -ForegroundColor Green
        New-ADOrganizationalUnit -Name "LIVE" -Path $ServiceOU
        Write-Host "Created sub-OU: LIVE under $NewOUName" -ForegroundColor Green
        New-ADOrganizationalUnit -Name "TEST" -Path $ServiceOU
        Write-Host "Created sub-OU: TEST under $NewOUName" -ForegroundColor Green
        New-ADOrganizationalUnit -Name "Service Accounts" -Path $ServiceOU
        Write-Host "Created Service Accounts sub-OU under $NewOUName" -ForegroundColor Green
        New-ADGroup -Name "$NewOUName - OU Admins" -GroupScope Global -Path $ServiceOU -Description "Users in this group are SMEs for the service and have delegated control rights for this OU and linked GPOs -$TicketNumber"
        Write-Host "Created OU Admins group for $NewOUName" -ForegroundColor Green

        # Prompt for SME admin accounts (comma-separated)
        $SMEAdmins = Read-Host "Enter the username(s) (sAMAccountName) of the SME admin(s) to add to the OU Admins group (comma-separated, or leave blank to skip)"
        if ($SMEAdmins) {
            $SMEAdminArray = $SMEAdmins -split ',\s*'
            try {
                Add-ADGroupMember -Identity "$NewOUName - OU Admins" -Members $SMEAdminArray
                Write-Host "Added $($SMEAdminArray -join ', ') to $NewOUName - OU Admins group." -ForegroundColor Green
            } catch {
                Write-Host "Failed to add one or more SME admins to $NewOUName - OU Admins group: $_" -ForegroundColor Red
            }
        }

        New-ADOrganizationalUnit -Name "Servers" -Path "OU=LIVE,$ServiceOU"
        Write-Host "Created Servers sub-OU under LIVE in $NewOUName" -ForegroundColor Green
        New-ADOrganizationalUnit -Name "Servers" -Path "OU=TEST,$ServiceOU"
        Write-Host "Created Servers sub-OU under TEST in $NewOUName" -ForegroundColor Green
        New-ADOrganizationalUnit -Name "Security Groups" -Path "OU=LIVE,$ServiceOU"
        Write-Host "Created Security Groups sub-OU under LIVE in $NewOUName" -ForegroundColor Green
        New-ADOrganizationalUnit -Name "Security Groups" -Path "OU=TEST,$ServiceOU"
        Write-Host "Created Security Groups sub-OU under TEST in $NewOUName" -ForegroundColor Green
        Write-Host "All required OUs and groups have been created successfully." -ForegroundColor Green

        $LiveSecurityGroupsOU = "OU=Security Groups,OU=LIVE,$ServiceOU"
        $TestSecurityGroupsOU = "OU=Security Groups,OU=TEST,$ServiceOU"
    } else {
        Write-Host "Cannot continue without an OU. Exiting script." -ForegroundColor Red
        exit
    }
}

# Let user select by number, not by typing the DN
if ($ExistingOUs) {
    # Force $ouList to be an array
    $ouList = @($ExistingOUs | Select-Object -Property Name, DistinguishedName)
    for ($i=0; $i -lt $ouList.Count; $i++) {
        Write-Host "$i. $($ouList[$i].Name) - $($ouList[$i].DistinguishedName)" -ForegroundColor Yellow
    }
    $ouIndex = Read-Host "Enter the number of the OU you want to use, or type 'New' to create a new OU"
    if ($ouIndex -eq 'New') {
        # Creating a new OU structure
        Write-Host "Ok, let's create a new OU and sub OUs for this service..." -ForegroundColor Yellow
        $NewOUName = Read-Host "What is the name of the new OU for this service/application?"
        $ServiceOU = "OU=$NewOUName,$BaseOU"

        Write-Host "Building new OU structure..." -ForegroundColor Yellow
        New-ADOrganizationalUnit -Name $NewOUName -Path $BaseOU
        Write-Host "Created OU: $NewOUName" -ForegroundColor Green
        New-ADOrganizationalUnit -Name "LIVE" -Path $ServiceOU
        Write-Host "Created sub-OU: LIVE under $NewOUName" -ForegroundColor Green
        New-ADOrganizationalUnit -Name "TEST" -Path $ServiceOU
        Write-Host "Created sub-OU: TEST under $NewOUName" -ForegroundColor Green
        New-ADOrganizationalUnit -Name "Service Accounts" -Path $ServiceOU
        Write-Host "Created Service Accounts sub-OU under $NewOUName" -ForegroundColor Green
        New-ADGroup -Name "$NewOUName - OU Admins" -GroupScope Global -Path $ServiceOU -Description "Users in this group are SMEs for the service and have delegated control rights for this OU and linked GPOs -$TicketNumber"
        Write-Host "Created OU Admins group for $NewOUName" -ForegroundColor Green

        
        # Prompt for SME admin accounts (comma-separated)
        $SMEAdmins = Read-Host "Enter the username(s) (sAMAccountName) of the SME admin(s) to add to the OU Admins group (comma-separated, or leave blank to skip)"
        if ($SMEAdmins) {
            $SMEAdminArray = $SMEAdmins -split ',\s*'
            try {
                Add-ADGroupMember -Identity "$NewOUName - OU Admins" -Members $SMEAdminArray
                Write-Host "Added $($SMEAdminArray -join ', ') to $NewOUName - OU Admins group." -ForegroundColor Green
            } catch {
                Write-Host "Failed to add one or more SME admins to $NewOUName - OU Admins group: $_" -ForegroundColor Red
            }
        }

        New-ADOrganizationalUnit -Name "Servers" -Path "OU=LIVE,$ServiceOU"
        Write-Host "Created Servers sub-OU under LIVE in $NewOUName" -ForegroundColor Green
        New-ADOrganizationalUnit -Name "Servers" -Path "OU=TEST,$ServiceOU"
        Write-Host "Created Servers sub-OU under TEST in $NewOUName" -ForegroundColor Green
        New-ADOrganizationalUnit -Name "Security Groups" -Path "OU=LIVE,$ServiceOU"
        Write-Host "Created Security Groups sub-OU under LIVE in $NewOUName" -ForegroundColor Green
        New-ADOrganizationalUnit -Name "Security Groups" -Path "OU=TEST,$ServiceOU"
        Write-Host "Created Security Groups sub-OU under TEST in $NewOUName" -ForegroundColor Green
        Write-Host "All required OUs and groups have been created successfully." -ForegroundColor Green

        $LiveSecurityGroupsOU = "OU=Security Groups,OU=LIVE,$ServiceOU"
        $TestSecurityGroupsOU = "OU=Security Groups,OU=TEST,$ServiceOU"
    }
    elseif ($ouIndex -match '^\d+$' -and [int]$ouIndex -ge 0 -and [int]$ouIndex -lt $ouList.Count) {
        $ServiceOU = $ouList[$ouIndex].DistinguishedName
        Write-Host "You have selected to use an existing OU: $ServiceOU" -ForegroundColor Green
        $LiveSecurityGroupsOU = "OU=Security Groups,OU=LIVE,$ServiceOU"
        $TestSecurityGroupsOU = "OU=Security Groups,OU=TEST,$ServiceOU"
    }
    else {
        Write-Host "Invalid selection. Please run the script again and enter the number shown next to the OU." -ForegroundColor Red
        exit
    }
}

# Prompt for server names
$ServerNames = Read-Host "What are the hostnames of the new servers you are deploying? (Example: Server1, Server2, Server3) - Separate multiple servers with a comma."
$ServerNamesArray = $ServerNames -split ',\s*'
Write-Host "You have entered the following server names: $($ServerNamesArray -join ', ')" -ForegroundColor Green

# Create groups for each server
Write-Host "Creating AD groups for each server..." -ForegroundColor Yellow
foreach ($ServerName in $ServerNamesArray) {
    if ($ServerName -like "*VVD*" -or $ServerName -like "*VVT*") {
        # TEST
        New-ADGroup -Name "$ServerName - RDP Users" -GroupScope Global -Path $TestSecurityGroupsOU -Description "Users in this group have RDP access to $ServerName - $TicketNumber"
        Write-Host "Created RDP Users group for $ServerName" -ForegroundColor Green

        New-ADGroup -Name "$ServerName - Server Admins" -GroupScope Global -Path $TestSecurityGroupsOU -Description "Users in this group are server admins for $ServerName - $TicketNumber"
        Write-Host "Created Server Admins group for $ServerName" -ForegroundColor Green

        New-ADGroup -Name "$ServerName - LogOnAsService" -GroupScope Global -Path $TestSecurityGroupsOU -Description "Users in this group have LogOnAsService rights for $ServerName - $TicketNumber"
        Write-Host "Created LogOnAsService group for $ServerName" -ForegroundColor Green

        Write-Host "Adding backup_user to LogOnAsService group for $ServerName..." -ForegroundColor Yellow

        try {
            Add-ADGroupMember -Identity "$ServerName - LogOnAsService" -Members "backup_user"
            Write-Host "Added backup_user to LogOnAsService group for $ServerName" -ForegroundColor Green
        } catch {
            Write-Host "Failed to add backup_user to LogOnAsService group for ${ServerName}: $_" -ForegroundColor Red
        }
    }
    elseif ($ServerName -like "*VVL*") {
        # LIVE
        New-ADGroup -Name "$ServerName - RDP Users" -GroupScope Global -Path $LiveSecurityGroupsOU -Description "Users in this group have RDP access to $ServerName - $TicketNumber"
        Write-Host "Created RDP Users group for $ServerName" -ForegroundColor Green

        New-ADGroup -Name "$ServerName - Server Admins" -GroupScope Global -Path $LiveSecurityGroupsOU -Description "Users in this group are server admins for $ServerName - $TicketNumber"
        Write-Host "Created Server Admins group for $ServerName" -ForegroundColor Green

        New-ADGroup -Name "$ServerName - LogOnAsService" -GroupScope Global -Path $LiveSecurityGroupsOU -Description "Users in this group have LogOnAsService rights for $ServerName - $TicketNumber"
        Write-Host "Created LogOnAsService group for $ServerName" -ForegroundColor Green

        Write-Host "Adding backup_user to LogOnAsService group for $ServerName..." -ForegroundColor Yellow

        try {
            Add-ADGroupMember -Identity "$ServerName - LogOnAsService" -Members "backup_user"
            Write-Host "Added backup_user to LogOnAsService group for $ServerName" -ForegroundColor Green
        } catch {
            Write-Host "Failed to add backup_user to LogOnAsService group for ${ServerName}: $_" -ForegroundColor Red
        }
    }
}

Write-Host "All groups and OUs have been created successfully." -ForegroundColor Green

# Move AD Computer objects to the correct OUs
Write-Host "Moving new AD Computer objects to the new/current OUs..." -ForegroundColor Yellow

foreach ($ServerName in $ServerNamesArray) {
    $ComputerObject = Get-ADComputer -Filter "Name -eq '$ServerName'" -ErrorAction SilentlyContinue
    if ($ComputerObject) {
        if ($ServerName -like "*VVD*" -or $ServerName -like "*VVT*") {
            $TargetOU = "OU=Servers,OU=TEST,$ServiceOU"
            Move-ADObject -Identity $ComputerObject.DistinguishedName -TargetPath $TargetOU
            Write-Host "Moved $ServerName to TEST OU ($TargetOU)" -ForegroundColor Green
        }
        elseif ($ServerName -like "*VVL*") {
            $TargetOU = "OU=Servers,OU=LIVE,$ServiceOU"
            Move-ADObject -Identity $ComputerObject.DistinguishedName -TargetPath $TargetOU
            Write-Host "Moved $ServerName to LIVE OU ($TargetOU)" -ForegroundColor Green
        }
    } else {
        Write-Host "No AD Computer object found for $ServerName" -ForegroundColor Red
    }
}

Write-Host "All groups and any necessary OUs have been created successfully, the computer(s) have been moved to the correct OU." -ForegroundColor Green

# Create GPOs for each server
Write-Host "Creating LogOnAsService GPOs for each server..." -ForegroundColor Yellow
$TargetOU = "OU=Servers,$ServiceOU"
$ServerNames = $ServerNamesArray -join ', '                 
Import-Module GroupPolicy

# Decide OU path for each server
function Get-ServerTargetOU {
    param (
        [string]$ServerName,
        [string]$ServiceOU
    )
    if ($ServerName -like "*VVD*" -or $ServerName -like "*VVT*") {
        return "OU=Servers,OU=TEST,$ServiceOU"
    } elseif ($ServerName -like "*VVL*") {
        return "OU=Servers,OU=LIVE,$ServiceOU"
    } else {
        return "OU=Servers,$ServiceOU"
    }
}

# Check if a GPO is already linked to an OU 
function Test-GPOLinked {
    param (
        [string]$GPOName,
        [string]$OU
    )
    $links = (Get-GPInheritance -Target $OU).GpoLinks
    return $links | Where-Object { $_.DisplayName -eq $GPOName }
}

# If a new OU was created earlier
if ($createNewOU -eq 'Y' -or ($ExistingOUs -and $ouIndex -eq 'New')) {
    Write-Host "Creating GPOs for each server in the new OU structure..." -ForegroundColor Yellow
    foreach ($ServerName in $ServerNamesArray) {
        $TargetOU = Get-ServerTargetOU -ServerName $ServerName -ServiceOU $ServiceOU
        $GPOLogOnAsService = "$ADServiceOU - $ServerName - LogOnAsService"

        foreach ($GPOName in @($GPOLogOnAsService)) {
            # Create GPO if it doesn't exist
            if (-not (Get-GPO -Name $GPOName -ErrorAction SilentlyContinue)) {
                New-GPO -Name $GPOName | Out-Null
                Write-Host "Created GPO: $GPOName" -ForegroundColor Yellow
            } else {
                Write-Host "GPO $GPOName already exists." -ForegroundColor Yellow
            }
            # Always link the GPO to the relevant OU (even if already linked)
            if (-not (Test-GPOLinked -GPOName $GPOName -OU $TargetOU)) {
                New-GPLink -Name $GPOName -Target $TargetOU | Out-Null
                Write-Host "Linked GPO $GPOName to $TargetOU" -ForegroundColor Green
            } else {
                Write-Host "GPO $GPOName is already linked to $TargetOU" -ForegroundColor Yellow
            }

            # Remove Authenticated Users from security filtering
            Set-GPPermission -Name $GPOName -TargetName "Authenticated Users" -TargetType Group -PermissionLevel None

            # Add the computer object to security filtering
            $ComputerObj = Get-ADComputer -Identity $ServerName -ErrorAction SilentlyContinue
            if ($ComputerObj) {
                Set-GPPermission -Name $GPOName -TargetName "$($ComputerObj.Name)$" -TargetType Computer -PermissionLevel GpoApply
                Write-Host "Added $($ComputerObj.Name)$ to security filtering for $GPOName." -ForegroundColor Green
            } else {
                Write-Host "Could not find computer object for $ServerName. Skipping security filtering." -ForegroundColor Yellow
            }
        }
    }
} else {
    # Existing OU path logic
    Write-Host "Creating GPOs for each server in the existing OU structure..." -ForegroundColor Yellow
    foreach ($ServerName in $ServerNamesArray) {
        $TargetOU = Get-ServerTargetOU -ServerName $ServerName -ServiceOU $ServiceOU
        $GPOLogOnAsService = "$ADServiceOU - $ServerName - LogOnAsService"

        foreach ($GPOName in @($GPOLogOnAsService)) {
            # Create GPO if it doesn't exist
            if (-not (Get-GPO -Name $GPOName -ErrorAction SilentlyContinue)) {
                New-GPO -Name $GPOName | Out-Null
                Write-Host "Created GPO: $GPOName" -ForegroundColor Yellow
            } else {
                Write-Host "GPO $GPOName already exists." -ForegroundColor Yellow
            }
            # Always link the GPO to the relevant OU (even if already linked)
            if (-not (Test-GPOLinked -GPOName $GPOName -OU $TargetOU)) {
                New-GPLink -Name $GPOName -Target $TargetOU | Out-Null
                Write-Host "Linked GPO $GPOName to $TargetOU" -ForegroundColor Green
            } else {
                Write-Host "GPO $GPOName is already linked to $TargetOU" -ForegroundColor Yellow
            }

            # Remove Authenticated Users from security filtering
            Set-GPPermission -Name $GPOName -TargetName "Authenticated Users" -TargetType Group -PermissionLevel None

            # Add the computer object to security filtering
            $ComputerObj = Get-ADComputer -Identity $ServerName -ErrorAction SilentlyContinue
            if ($ComputerObj) {
                Set-GPPermission -Name $GPOName -TargetName "$($ComputerObj.Name)$" -TargetType Computer -PermissionLevel GpoApply
                Write-Host "Added $($ComputerObj.Name)$ to security filtering for $GPOName." -ForegroundColor Green
            } else {
                Write-Host "Could not find computer object for $ServerName. Skipping security filtering." -ForegroundColor Yellow
            }
        }
    }
}

Write-Host "LogOnAsService GPOs created, security filtered, and linked to the correct OUs." -ForegroundColor Cyan

# Final message
Write-Host "Thank you for using the New-ServerDeployment script!" -ForegroundColor Cyan