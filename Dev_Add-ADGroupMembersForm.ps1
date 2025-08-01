New-UDForm -Title "Add Users to AD Group" -Content {
    New-UDTextbox -Id "txtFilePath" -Label "Path to User Names File (.txt)"
    New-UDTextbox -Id "txtGroupName" -Label "AD Group Name"
} -OnSubmit {
    $FilePath = $EventData.txtFilePath
    $GroupName = $EventData.txtGroupName

    # Run the script with parameters
    $Output = Invoke-UAScript -Name "Add-ADGroupMembers.ps1" -Parameters @{
        UserNamesFile = $FilePath
        ADGroup       = $GroupName
    }

    Show-UDToast -Message "Script started. Monitor jobs for progress." -Duration 5000
}

