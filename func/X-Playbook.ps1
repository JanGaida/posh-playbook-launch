# Init
if (-not $global:__on_exit_terminate) {
    $global:__on_exit_terminate = [System.Collections.Generic.List[PSCustomObject]]::new()
}
if (-not $global:__on_exit_recall) {
    $global:__on_exit_recall = [System.Collections.Generic.List[PSCustomObject]]::new()
}


<#
.SYNOPSIS
    Internal helper to launch a specific process with defined parameters.
#>
function Start-PlaybookProcess {
    param (
        [Parameter(Mandatory = $true)]
        [string]
        $FilePath,

        [Parameter(Mandatory = $true)]
        [string]
        $WorkingDirectory,

        [Parameter(Mandatory = $false)]
        [ValidateSet("Normal", "Minimized", "Maximized", "Hidden")]
        [string]
        $WindowStyle = "Normal",

        [Parameter(Mandatory = $false)]
        [System.Boolean]
        $PassThru = $true,

        [Parameter(Mandatory = $false)]
        [ValidateSet("Continue", "Stop", "SilentlyContinue", "Inquire")]
        [string]
        $ProcErrorAction = "Stop",

        [Parameter(Mandatory = $false)]
        [string]$Arguments
    )
    # Parameters (anytimes)
    $proc_params = @{
        FilePath         = $FilePath
        WorkingDirectory = $WorkingDirectory
        WindowStyle      = $WindowStyle
        PassThru         = $PassThru
        ErrorAction      = $ProcErrorAction
    }

    # Parameter (sometimes)
    $argsString = 'None'
    if (-not [string]::IsNullOrWhiteSpace($Arguments)) {
        $proc_params["ArgumentList"] = $Arguments
        $argsString = ($Arguments -join " ")
    }

    try {
        $process = Start-Process @proc_params
        Write-Verbose ("Started process with [PID: $($process.Id)]`n" +
            "            Path = $($proc_params.FilePath)`n" +
            "     Working Dir = $($proc_params.WorkingDirectory)`n" +
            "    Window Style = $($proc_params.WindowStyle)`n" +
            "       Arguments = $($argsString)`n"
        )
        return $process
    }
    catch {
        Write-Error ("Failed to start process!`n" +
            "            Path = $($proc_params.FilePath)`n" +
            "     Working Dir = $($proc_params.WorkingDirectory)`n" +
            "    Window Style = $($proc_params.WindowStyle)`n" +
            "       Arguments = $($argsString)`n"
        )
        return $null
    }
}

<#
.SYNOPSIS
    Starts the playbook.
#>
function Invoke-Playbook {
    Write-Host  "`nStarting playbook...`n" -ForegroundColor Cyan

    # --- MAIN APP ---

    # Prepare
    $global:__main_process_cwd = if ([string]::IsNullOrWhiteSpace("$($global:Cfg.Main_App.Working_Directory)")) {
        Split-Path "$($global:Cfg.Main_App.Path)"
    }
    else {
        "$($global:Cfg.Main_App.Working_Directory)"
    }
    $windowStyle = if ([string]::IsNullOrWhiteSpace("$($global:Cfg.Main_App.WindowStyle)")) {
        "Normal"
    }
    else {
        "$($global:Cfg.Main_App.WindowStyle)"
    }
    $mainArgs = if ([string]::IsNullOrWhiteSpace("$($global:Cfg.Main_App.Arguments)")) {
        $null
    }
    else {
        $global:Cfg.Main_App.Arguments
    }

    $global:__main_process = Start-PlaybookProcess `
        -FilePath         "$($global:Cfg.Main_App.Path)" `
        -WorkingDirectory "$($global:__main_process_cwd)" `
        -WindowStyle      "$windowStyle" `
        -Arguments        "$mainArgs"

    # Set-ProcessPriority
    Start-Sleep -Milliseconds $global:Cfg.Playbook.Delay_Ms
    Set-ProcessPriority `
        -Process       $global:__main_process `
        -PriorityClass "$($global:Cfg.Main_App.Priority_Class)"


    # --- SIDE APPS ---

    foreach ($sideApp in $global:Cfg.Side_Apps) {
        if (-not $sideApp) { continue }

        # Prepare
        $cwd = if ([string]::IsNullOrWhiteSpace("$($sideApp.Working_Directory)")) {
            Split-Path "$($sideApp.Path)"
        }
        else {
            "$($sideApp.Working_Directory)"
        }
        $windowStyle = if ([string]::IsNullOrWhiteSpace("$($sideApp.WindowStyle)")) {
            "Minimized"
        }
        else {
            "$($sideApp.WindowStyle)"
        }
        $sideArgs = if ([string]::IsNullOrWhiteSpace("$($sideApp.Arguments)")) {
            $null
        }
        else {
            $sideApp.Arguments
        }

        # Launch
        $sideAppProc = Start-PlaybookProcess `
            -FilePath         $($sideApp.Path) `
            -WorkingDirectory $cwd `
            -WindowStyle      $windowStyle `
            -Arguments        $sideArgs

        # Check Exit
        if ($sideApp.OnExit) {
            switch ($sideApp.OnExit) {
                "Terminate" {
                    $global:__on_exit_terminate.Add([PSCustomObject]@{
                        Proc = $sideAppProc
                    })
                }
                "RecallWithArgs" {
                    if ([string]::IsNullOrWhiteSpace("$($sideApp.OnExit_Args)")) {
                        Write-Warning "Unsupported OnExit_Args variable '$($sideApp.OnExit_Args)'!"
                        break
                    }
                    $global:__on_exit_recall.Add([PSCustomObject]@{
                        Path        = $sideApp.Path
                        Cwd         = $cwd
                        WindowStyle = $windowStyle
                        Args        = $sideApp.OnExit_Args
                    })
                }
                Default {
                    Write-Warning "Unsupported OnExit variable '$($sideApp.OnExit)'!"
                }
            }
        }
    }


    # --- Misc ---

    if ($global:Cfg.Playbook.Manage_Windows_Defender) {
        Stop-WinDefender
    }

    Start-Sleep -Milliseconds $global:Cfg.Playbook.Delay_Ms
}

<#
.SYNOPSIS
    Waits for the Main-App to finish, then will continue stopping the playbook.
#>
function Wait-Playbook {
    Write-Host "Awaiting exit of main-app...`n" -ForegroundColor Cyan
    [System.GC]::Collect()

    Start-Sleep -Milliseconds $global:Cfg.Playbook.Delay_Ms

    if ($global:__main_process -and -not $global:__main_process.HasExited) {
        $global:__main_process.WaitForExit() | Out-Null
    }

    Stop-Playbook
}

<#
.SYNOPSIS
    Stops the playbook.
#>
function Stop-Playbook {
    Write-Host "`nStopping playbook...`n" -ForegroundColor Cyan
    try {
        # On Exit: Termiante
        foreach ($item in $global:__on_exit_terminate) {
            if ($item.Proc -and -not $item.Proc.HasExited) {
                try {
                    Write-Verbose "Terminating side-app process [PID: $($item.Proc.Id)]..."
                    Stop-Process -InputObject $item.Proc -Force -ErrorAction Stop
                    Write-Verbose "Successfully terminated."
                }
                catch {
                    Write-Warning "Failed to terminate process [PID: $($item.Proc.Id)]: $_"
                }
            }
        }

        # On Exit: Recall with arguments
        foreach ($item in $global:__on_exit_recall) {
            if ($item) {
                Write-Verbose "Reaclling side-app process..."
                $recalledProc = Start-PlaybookProcess `
                    -FilePath $item.Path `
                    -WorkingDirectory $item.Cwd `
                    -WindowStyle $item.WindowStyle `
                    -Arguments $item.Args `
                    -ProcErrorAction "Continue"
                if ($recalledProc) {
                    Write-Verbose "Successfully recalled process '$($item.Path)' with PID $($recalledProc.Id)"
                }
            }

        }

        # Optimizations
        Restore-WinServices
        Restore-ProcessPriority
        Restore-CoreParking

        # Windows Defender
        if ($global:Cfg.Playbook.Manage_Windows_Defender) {
            Start-WinDefender
        }

        # Stop trayIcon
        Unregister-TrayIcon

        # Stop logging
        Resolve-Logging -Stop

        # Exit
        Exit-App
    }
    catch {
        Write-Error "Unexpected Error in func 'X-Playbook.ps1' in $($MyInvocation.MyCommand.Name) at line $($_.InvocationInfo.ScriptLineNumber): $_"
        Exit-App -Error
    }

    Stop-Process -Id $PID -Force
}
