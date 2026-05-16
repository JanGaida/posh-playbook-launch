<#
.SYNOPSIS
    Resolves the logging-feature

.PARAMETER Stop
    If Logging should be gracefully stopped.
#>
function Resolve-Logging {
    param (
        [Parameter(Mandatory = $false)]
        [switch]
        $Stop = $false
    )
    #Guards
    if ($null -eq "$($global:Cfg.Playbook)") {
        Write-Error "Mandatory variable `$global:Cfg.Playbook is null or empty."
        return
    }
    if ($null -eq "$($global:Cfg.Playbook.Log_Enabled)") {
        Write-Error "Mandatory variable `$global:Cfg.Playbook.Log_Enabled is null or empty."
        return
    }
    if ($null -eq "$($global:Cfg.Playbook.Log_Directory)") {
        Write-Error "Mandatory variable `$global:Cfg.Playbook.Log_Directory is null or empty."
        return
    }

    if ($Stop) {
        # --- STOP ---

        # Guard
        if ($($null -eq $global:__log_initialized) -or -not $($global:__log_initialized)) { return }

        Resolve-Configs
        if ($global:Cfg.Playbook.Log_Enabled) {
            Stop-Logging
        }

        $global:__log_initialized = $false
    }
    else {
        # --- START ---

        # Guard
        if (-not $($null -eq $global:__log_initialized) -or $($global:__log_initialized)) { return }
        Resolve-Configs
        if ($global:Cfg.Playbook.Log_Enabled) {
            if (-not (Test-Path "$($global:Cfg.Playbook.Log_Directory)")) {
                New-Item -Path "$($global:Cfg.Playbook.Log_Directory)" -ItemType Directory
            }
            Start-Logging
        }

        $global:__log_initialized = $true
    }
}

<#
.SYNOPSIS
    Starts an active transcript log.
#>
function Start-Logging {
    #Guards
    if ($null -eq "$($global:Cfg.Playbook)") {
        Write-Error "Mandatory variable `$global:Cfg.Playbook is null or empty."
        return
    }
    if ($null -eq "$($global:Cfg.Playbook.Log_Directory)") {
        Write-Error "Mandatory variable `$global:Cfg.Playbook.Log_Directory is null or empty."
        return
    }
    if ($null -eq "$($global:Cfg.Playbook.Log_Filename)") {
        Write-Error "Mandatory variable `$global:Cfg.Playbook.Log_Filename is null or empty."
        return
    }
    if ($null -eq "$($global:Cfg.Playbook.Logging_Append)") {
        Write-Error "Mandatory variable `$global:Cfg.Playbook.Logging_Append is null or empty."
        return
    }

    Resolve-Configs
    $logPath = Join-Path $global:Cfg.Playbook.Log_Directory $global:Cfg.Playbook.Log_Filename

    try {
        if (-not $($global:Cfg.Playbook.Logging_Append) -and $(Test-Path $LogPath)) {
            Remove-Item $LogPath -Force
        }

        Start-Transcript -Path $LogPath -Force | Out-Null
        Write-Verbose ("New Logging started`n" +
            "    Date = $([DateTime]::UtcNow.ToString('u'))`n" +
            "    Dir  = $($global:Cfg.Playbook.Log_Directory)`n" +
            "    File = $($global:Cfg.Playbook.Log_Filename)"
        )
    }
    catch {
        Write-Warning "Unexpected Error in func 'X-Logging.ps1' in $($MyInvocation.MyCommand.Name) at line $($_.InvocationInfo.ScriptLineNumber): $_"
    }
}

<#
.SYNOPSIS
    Stops the active transcript log.
#>
function Stop-Logging {
    #Guards
    if ($null -eq "$($global:Cfg.Playbook)") {
        Write-Error "Mandatory variable `$global:Cfg.Playbook is null or empty."
        return
    }
    if ($null -eq "$($global:Cfg.Playbook.Log_Enabled)") {
        Write-Error "Mandatory variable `$global:Cfg.Playbook.Log_Enabled is null or empty."
        return
    }

    Resolve-Configs
    if (-not $global:Cfg.Playbook.Log_Enabled) { return }

    try {
        Write-Verbose "Logging stopped."
        Stop-Transcript | Out-Null
    }
    catch {
        Write-Warning "Unexpected Error in func 'X-Logging.ps1' in $($MyInvocation.MyCommand.Name) at line $($_.InvocationInfo.ScriptLineNumber): $_"
    }

    $global:__log_initialized = $false
}
