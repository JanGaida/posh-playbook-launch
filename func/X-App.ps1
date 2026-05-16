<#
.SYNOPSIS
    Called to exit the Application

.PARAMETER Error
    When the App should exit indicating an error.
#>
function Exit-App {
    param (
        [Parameter(Mandatory = $false)]
        [switch]
        $Error = $false
    )

    if ($Error) {
        Show-App
        $seconds = 15
        Write-Host "Delaying exit towards $seconds seconds."
        Start-Sleep -Seconds $seconds
        exit 1
    }

    exit 0
}

<#
.SYNOPSIS
    Shows the terminal of this application

.PARAMETER Hide
    Wether the visibility of the app should be toggled when visible
#>
function Show-App {
    param (
        [Parameter(Mandatory = $false)]
        [switch]
        $Toggle = $false
    )

    if ($null -eq $global:__main_process_visibility) {
        $global:__main_process_visibility = $true
    }

    if ($Toggle -and $global:__main_process_visibility) {
        Hide-App
        return
    }

    # Guard
    if ($global:__main_process_visibility) { return }

    # Show
    [Win32]::ShowWindow([Win32]::GetConsoleWindow(), 5) | Out-Null
    $global:__main_process_visibility = $true
}

<#
.SYNOPSIS
    Hides the terminal of this application
#>
function Hide-App {
    if ($null -eq $global:__main_process_visibility) {
        $global:__main_process_visibility = $true
    }

    # Guard
    if (-not $global:__main_process_visibility) { return }

    # Hide
    [Win32]::ShowWindow([Win32]::GetConsoleWindow(), 0) | Out-Null
    $global:__main_process_visibility = $false
}
