#NAME: Add-ADGroupMembers.ps1#
#AUTHOR: Joshua Breeds - 25/02/2025#
#SYNOPSIS: Adds multiple users from a .txt file based on sAMName, to a specified AD group.#
#DESCRIPTION:
# - Gets a list of names to add to an AD group from a .txt file.
# - Formats the list of names to sAMAccountNames if required.
# - Retries adding usernames using a scoring system for potential matches if unsuccessful the first time.
#LAST EDIT: 02/10/2025#

# Import the Active Directory module
Import-Module ActiveDirectory

# Welcome messages
Write-Host "Welcome to the AD Group Member Addition Script!" -ForegroundColor Cyan
Write-Host "This script will help you add users to an Active Directory group." -ForegroundColor Cyan
Write-Host "Please ensure you have the necessary text file for this process (List of names)." -ForegroundColor Yellow

# Retrieve list of user's names from a text file
$UserNamesFile = Read-Host "Please enter the path to the text file containing user names (Example: C:\Users\jbreeds\Documents\Names.txt)"

# Check if the file exists
if (-Not (Test-Path -Path $UserNamesFile)) {
    Write-Host "The specified file does not exist. Please check the path and try again." -ForegroundColor Red
    exit
}

# Read the user names from the specified file
Write-Host "Getting usernames from file..." -ForegroundColor Yellow
$UserNamesArray = Get-Content -Path $UserNamesFile

# Ask if names need formatting to sAMAccountNames or not
Write-Host "Checking usernames..." -ForegroundColor Yellow
# Natural pause
Start-Sleep -Seconds 3
$FormattingRequired = Read-Host "Do you need to change the names in this list to sAMAccountNames? E.g. joe.bloggs - IF NOT, SELECT 'N', or this script will not work as intended. SELECT 'Y' if the list of names is already in sAMAccountName format. (Y/N)"

if ($FormattingRequired -eq 'Y') {
    # Format list of names to sAMAccount names
    Write-Host "Converting names of users to sAMAccountNames..." -ForegroundColor Yellow
    $sAMNamesArray = @() 
    foreach ($UserName in $UserNamesArray) {
    # Ignore empty lines
    if ([string]::IsNullOrWhiteSpace($UserName)) {
        Write-Host "Skipping empty line." -ForegroundColor Yellow
        continue
    }
    # Assuming the names are in the format "First Last"
    $sAMName = $UserName -replace ' ', '.'  # Replace space with dot for sAMAccountName
    $sAMName = $sAMName.ToLower() # Convert to lowercase
    # Eliminate any numbers or special characters except for dash and dots
    $sAMName = $sAMName -replace '[^a-z.]', ''
    # Remove trailing dot if present
    $sAMName = $sAMName.TrimEnd('.')
    # Remove leading dot if present
    $sAMName = $sAMName.TrimStart('.')
    #Add the formatted sAMAccountName to the array
    $sAMNamesArray += $sAMName
    # Display the formatted sAMAccountNames
    Write-Host "Formatted sAMAccountName: $sAMName" -ForegroundColor Green
}
}

if ($FormattingRequired -eq 'N') {
    Write-Host "You have confirmed the list of names is already in sAMAccountName format. Continuing..." -ForegroundColor Green
    # Add list of names to sAMNamesArray
    $sAMNamesArray = @()
    foreach ($UserName in $UserNamesArray) {
        $sAMNamesArray += $sAMName
        # Ignore empty lines
        if ([string]::IsNullOrWhiteSpace($UserName)) {
        Write-Host "Skipping empty line." -ForegroundColor Yellow
        continue
    }
}
}

# Prompt for desired AD Group
$ADGroup = Read-Host "Add users to which AD Group? (Copy and paste the exact name of the group)"

# Check AD Group is correct
Read-Host "You have chosen to add users to the AD Group: $ADGroup. Press Enter to continue or Ctrl+C to cancel"

# Confirm the AD Group
Write-Host "You have chosen to add users to the AD Group: $ADGroup" -ForegroundColor Cyan

# Check if the AD Group exists
if (-Not (Get-ADGroup -Filter { Name -eq $ADGroup })) {
    Write-Host "The specified AD Group does not exist. Please check the group name and try again." -ForegroundColor Red
    exit
}

# Run through each name in the user list $sAMNames and add user to $ADGroup and display success or failure.
foreach ($sAMName in $sAMNamesArray){
    try {
        # Check if user is already in the group
        $GroupMembers = Get-ADGroupMember -Identity $ADGroup | Select-Object -ExpandProperty SamAccountName
        if ($GroupMembers -contains $sAMName) { 
            Write-Host "User $sAMName is already a member of $ADGroup." -ForegroundColor Yellow
            continue
        }
        # Add user to the AD Group
        Add-ADGroupMember -Identity $ADGroup -Members $sAMName -ErrorAction Stop
        Write-Host "Successfully added $sAMName to $ADGroup" -ForegroundColor Green
    }
    catch {
        Write-Host "Failed to add $sAMName to $ADGroup. Error: $_" -ForegroundColor Red
    }
}

# Check for failed user additions
Write-Host "Checking for any failed additions..." -ForegroundColor Yellow
# Natural pause
Start-Sleep -Seconds 5
$FailedUsers = @()
$GroupMembers = Get-ADGroupMember -Identity $ADGroup | Select-Object -ExpandProperty SamAccountName
foreach ($sAMName in $sAMNamesArray) {
    if ($GroupMembers -notcontains $sAMName) {
        Write-Host "User $sAMName was not added successfully. Retrying..." -ForegroundColor Red
        $FailedUsers += $sAMName
    }
}

# Retry failed users by finding similar sAMAccountNames in AD
if ($FailedUsers.Count -gt 0) {
    Write-Host "Trying to find similar sAMAccountNames for failed users..." -ForegroundColor Yellow
    foreach ($sAMName in $FailedUsers) {
        try {
            Write-Host "Searching for similar users for $sAMName..." -ForegroundColor Yellow
            $parts = $sAMName.Split('.')
            $firstName = $parts[0]
            $lastName = $parts[-1]
            $added = $false

            # Gather all possible candidates (surname, givenname, swapped)
            $Candidates = @()
            $Candidates += Get-ADUser -Filter "Surname -like '*$lastName*'" -ErrorAction SilentlyContinue
            $Candidates += Get-ADUser -Filter "GivenName -like '*$firstName*'" -ErrorAction SilentlyContinue
            $Candidates += Get-ADUser -Filter "GivenName -like '*$lastName*' -or Surname -like '*$firstName*'" -ErrorAction SilentlyContinue

            # Remove duplicates and filter out numeric-only/non-dot accounts
            $Candidates = $Candidates | Sort-Object SamAccountName -Unique | Where-Object {
                $_.SamAccountName -match "\." -and
                $_.SamAccountName -notmatch '^\d+$'
            }

            # Score candidates: prioritize those that start and end with the right names
            $Scored = $Candidates | Select-Object *, @{
                Name = "Score"
                Expression = {
                    $score = 0
                    if ($_.SamAccountName -eq $sAMName) { $score += 100 }
                    if ($_.SamAccountName -like "$firstName.$lastName") { $score += 50 }
                    if ($_.SamAccountName -like "$firstName*.$lastName*") { $score += 25 }
                    if ($_.SamAccountName -like "$firstName*") { $score += 10 }
                    if ($_.SamAccountName -like "*.$lastName*") { $score += 10 }
                    $score
                }
            } | Sort-Object Score -Descending

            # Take top 5 best matches
            $TopMatches = $Scored | Select-Object -First 5

            if ($TopMatches) {
                foreach ($User in $TopMatches) {
                    $Confirmation = Read-Host "Is $($User.SamAccountName) ($($User.Name)) the correct user to add? (Y/N)"
                    if ($Confirmation -eq 'Y') {        
                        Add-ADGroupMember -Identity $ADGroup -Members $User.SamAccountName -ErrorAction Stop
                        Write-Host "Successfully added similar user $($User.SamAccountName) to $ADGroup" -ForegroundColor Green
                        $added = $true
                        break
                    } else {
                        Write-Host "Skipping $($User.SamAccountName)." -ForegroundColor Yellow
                    }
                }
                if (-not $added) {
                    Write-Host "No confirmed match for $sAMName." -ForegroundColor Red
                }
            } else {
                Write-Host "No similar users found for $sAMName. Please check Active Directory." -ForegroundColor Red
            }
        }
        catch {
            Write-Host "Failed to retry adding $sAMName. Error: $_" -ForegroundColor Red
        }
    }
} else {
    Write-Host "All users were added successfully!" -ForegroundColor Green
}

# Goodbye message
Write-Host "Thank you for using the AD Group Member Addition Script!" -ForegroundColor Cyan
