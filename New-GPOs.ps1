# List of server names
$ServerNames = @(
    "SERVER1",
    "SERVER2",
"
    # Add more server names as needed
)

# The OU where the servers reside (Distinguished Name)
$TargetOU = "" # <-- Replace with your OU DN

Import-Module GroupPolicy

foreach ($Server in $ServerNames) {
    $GPOName = "yourservice - $Server - LogOnAsService"
    # Create GPO if it doesn't exist
    if (-not (Get-GPO -Name $GPOName -ErrorAction SilentlyContinue)) {
        New-GPO -Name $GPOName | Out-Null
        Write-Host "Created GPO: $GPOName" -ForegroundColor Green
    } else {
        Write-Host "GPO $GPOName already exists." -ForegroundColor Yellow
    }

    # Link GPO to the OU
    New-GPLink -Name $GPOName -Target $TargetOU | Out-Null

    Write-Host "GPO $GPOName created and linked to $TargetOU. (Add LogOnAsService rights manually or with LGPO.exe)" -ForegroundColor Cyan
}