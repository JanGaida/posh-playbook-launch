<#
.SYNOPSIS
    Registers and initializes the system tray icon.
#>
function Register-TrayIcon {
    param (
        [Parameter(Mandatory = $false)]
        [string]
        $Icon = "rocket",

        [Parameter(Mandatory = $false)]
        [string]
        $Resolution = "32",

        [Parameter(Mandatory = $false)]
        [string]
        $FileType = "ico"
    )
    # Guard
    if ($global:NotifyIcon) { return }
    Resolve-Configs

    # Load icon
    $iconChildPath = "ico/$Icon/$Resolution.$FileType"
    $iconPath = $(Join-Path $global:RootDir -ChildPath $iconChildPath)
    $global:NotifyIcon         = [System.Windows.Forms.NotifyIcon]::new()
    $global:NotifyIcon.Icon    = [System.Drawing.Icon]::new($iconPath)
    $global:NotifyIcon.Text    = "Playbook-Launcher: $($global:Cfg.Playbook.Name)"
    $global:NotifyIcon.Visible = $true

    Write-Verbose ("Showing NotifyIcon`n" +
        "    Icon_Dir  = $($global:RootDir)`n" +
        "    Icon_File = $iconChildPath"
    )
}

<#
.SYNOPSIS
    Unregisters and disposes of the system tray icon.
#>
function Unregister-TrayIcon {
    if ($global:NotifyIcon) {
        $global:NotifyIcon.Visible = $false
        $global:NotifyIcon.Dispose()
        Remove-Variable -Name "NotifyIcon" -Scope "Global" -ErrorAction "SilentlyContinue"
    }
    else {
        Write-Warning "No tray icon found to unregister."
    }
}
