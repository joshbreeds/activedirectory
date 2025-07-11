# NAME: New-ADServerGroups.ps1
# AUTHOR: Joshua Breeds - 03/07/2025
# SYNOPSIS: Creates new service OUs/server AD security groups and LogOnAsService GPOs after VMWare deployment.
# LAST EDIT: 11/07/2025

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
if ($TicketNumber -match 'DP-\d{6}') {
    Write-Host "You have entered a valid ticket number: $TicketNumber" -ForegroundColor Green
} else {
    Write-Host "Invalid ticket number format. Please enter a valid Jira DP ticket number (e.g., DP-123456)." -ForegroundColor Red
    exit
}

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
$ADServiceOU = Read-Host "What is the name of the service that your server(s) are running? (Example: CROWN DMS, NICHE etc)"
$BaseOU = "OU=Servers,OU=Northumbria Police,OU=Data Management,DC=nbria,DC=police,DC=cjx,DC=gov,DC=uk"

# Get the OU object(s) matching the name
$ExistingOUs = Get-ADOrganizationalUnit -Filter "Name -like '*$ADServiceOU*'" -SearchBase $BaseOU -ErrorAction SilentlyContinue

if ($ExistingOUs) {
    Write-Host "Found the following Active Directory OUs under the Server OU:"
    $ExistingOUs | Select-Object Name, DistinguishedName | Format-Table -AutoSize
} else {
    Write-Host "No matching OUs found for $ADServiceOU." -ForegroundColor Red
    $CreateNewOU = Read-Host "Would you like to create a new OU for this service? (Y/N)"
    if ($CreateNewOU -eq 'Y') {
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
                Write-Host "Failed to add one or more SME admins to $NewOUName - OU Admins group: $_. OU Admins group may be configured incorrectly, please review in AD." -ForegroundColor Red
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
                Write-Host "Failed to add one or more SME admins to $NewOUName - OU Admins group: $_. OU Admins group may be configured incorrectly, please review in AD." -ForegroundColor Red
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

# Validate server names
$ServerNamesCheck = Read-Host "You have entered the following server names: $ServerNamesArray. Are these correct and free from typos? [Y/N]"
if ($ServerNamesCheck -eq 'N') {
    Write-Host "Please re-run the script and enter the correct server names." -ForegroundColor Red
    exit
} elseif ($ServerNamesCheck -ne 'Y') {
    Write-Host "Invalid input. Please enter Y or N." -ForegroundColor Red
    exit
} else {
    Write-Host "You have confirmed that the server names are correct." -ForegroundColor Green
}
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

# Creates GPOs for each server
foreach ($ServerName in $ServerNamesArray) {
    # Determine the OU based on server name
    if ($ServerName -like "*VVD*" -or $ServerName -like "*VVT*") {
        $TargetOU = "OU=Servers,OU=TEST,$ServiceOU"
    } elseif ($ServerName -like "*VVL*") {
        $TargetOU = "OU=Servers,OU=LIVE,$ServiceOU"
    } else {
        Write-Host "Skipping GPO creation for $ServerName as it does not match expected patterns." -ForegroundColor Yellow
        continue
    }

    # Check if the GPO already exists
    $GPOName = "$ADServiceOU - $ServerName - LogOnAsService"
    $ExistingGPO = Get-GPO -Name $GPOName -ErrorAction SilentlyContinue
    if ($ExistingGPO) {
        Write-Host "GPO '$GPOName' already exists." -ForegroundColor Yellow
    } else {
        # Create the new GPO
        if ($CreateNewOU = 'Y') {
            $GPOName = "$NewOUName - $ServerName - LogOnAsService"
        } else {
            $GPOName = "$ADServiceOU - $ServerName - LogOnAsService"
        }

        Write-Host "Creating GPO: $GPOName" -ForegroundColor Yellow
        $NewGPO = New-GPO -Name $GPOName -Comment "LogOnAsService GPO for $ServerName - $TicketNumber"
        Write-Host "Created GPO: $GPOName" -ForegroundColor Green

        #Wait for GPO creation to propagate
        Write-Host "If a new AD OU was created, please wait for the new AD OU to propagate to GPMC...Please allow a few mins..." -ForegroundColor Yellow

        # Wait for the OU to be available in GPMC
        $MaxAttempts= 15
        $Delay = 60
        $Success = $false

        for ($i = 1; $i -le $MaxAttempts; $i++) {
            try {
                New-GPLink -Name $NewGPO.DisplayName -Target $TargetOU -LinkEnabled Yes -ErrorAction Stop
                Write-Host "Successfully linked GPO '$GPOName' to OU '$TargetOU'." -ForegroundColor Green
                $Success = $true
                break
            }
            catch {
                Write-Host "Attempt $i of $MaxAttempts. Failed to link GPO '$GPOName' to OU '$TargetOU'. Retrying in $Delay seconds..." -ForegroundColor Red
                Start-Sleep -Seconds $Delay
            }
        }

        if (-not $Success) {
            Write-Host "Failed to link GPO '$GPOName' to OU '$TargetOU' after $MaxAttempts attempts. Proceeding anyway, GPOs may not be linked correctly." -ForegroundColor Red
        }

        # Set security filtering to allow only the server AD object and remove Authenticated Users
        $ComputerObj = Get-ADComputer -Identity $ServerName -ErrorAction SilentlyContinue
        Set-GPPermission -Guid $NewGPO.Id -PermissionLevel None -TargetType Group -TargetName "Authenticated Users"
        Set-GPPermission -Name $GPOName -TargetName "$($ComputerObj.Name)$" -TargetType Computer -PermissionLevel GpoApply
        Write-Host "Set security filtering for GPO '$GPOName'." -ForegroundColor Green
    }
}

# Final messages
Write-Host "All GPOs have been created, security filtered and linked successfully." -ForegroundColor Green
Write-Host "Please ensure you configure user rights assignment on the new GPOs with the Group Police Management Console." -ForegroundColor Yellow
Write-Host "Don't forget to assign AD RDPUsers and ServerAdmins group to their respective local groups!" -ForegroundColor Yellow
Write-Host "Thank you for using the New-ServerDeployment script!" -ForegroundColor Cyan


