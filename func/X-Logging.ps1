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

        Clear-Logging
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
    if ($null -eq "$($global:Cfg.Playbook.Log_Append)") {
        Write-Error "Mandatory variable `$global:Cfg.Playbook.Log_Append is null or empty."
        return
    }

    Resolve-Configs
    $logPath = Join-Path $global:Cfg.Playbook.Log_Directory $global:Cfg.Playbook.Log_Filename

    try {
        if (-not $($global:Cfg.Playbook.Log_Append) -and $(Test-Path $LogPath)) {
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

<#
.SYNOPSIS
    Removes outdated log files and orphaned log directories.
#>
function Clear-Logging {
    [CmdletBinding(
        SupportsShouldProcess = $true,
        ConfirmImpact = 'Medium'
    )]
    param (
        [Parameter(Mandatory = $false)]
        [switch]
        $KeepEmptyDirectories = $false
    )

    try {
        # Guards
        Resolve-Configs

        if ([string]::IsNullOrWhiteSpace($global:Cfg.Playbook.Log_Directory)) {
            throw "Mandatory variable `$global:Cfg.Playbook.Log_Directory is null or empty."
        }
        if ([string]::IsNullOrWhiteSpace("$($global:Cfg.Playbook.Log_RetentionDays)")) {
            throw "Mandatory variable `$global:Cfg.Playbook.Log_RetentionDays is null or empty."
        }
        if ([string]::IsNullOrWhiteSpace($global:Cfg.Playbook.Log_Filename)) {
            throw "Mandatory variable `$global:Cfg.Playbook.Log_Filename is null or empty."
        }

        # Init
        $logDirectory = $global:Cfg.Playbook.Log_Directory
        while (
            -not [string]::IsNullOrWhiteSpace($logDirectory) -and
            [System.IO.Path]::GetFileName($logDirectory) -match '^\d+$'
        ) {
            $logDirectory = Split-Path $logDirectory -Parent
        }
        $retentionDays = [int]$global:Cfg.Playbook.Log_RetentionDays
        $filePattern = "*.$(($global:Cfg.Playbook.Log_Filename -split "\.")[-1])"

        # Resolve
        if (-not (Test-Path -LiteralPath $logDirectory)) {
            return
        }
        $resolvedPath = (Resolve-Path -LiteralPath $logDirectory).Path
        $cutoffDate = (Get-Date).Date.AddDays(-$retentionDays)

        Write-Verbose (
            "Cleaning logs`n" +
            "    Path          = $resolvedPath`n" +
            "    RetentionDays = $retentionDays`n" +
            "    FilePattern   = $filePattern"
        )

        # Find outdated logs
        $logFiles = Get-ChildItem `
            -LiteralPath $resolvedPath `
            -Filter $filePattern `
            -File `
            -Recurse `
            -ErrorAction Stop `
            | Where-Object {
                $_.LastWriteTime.Date -lt $cutoffDate
            }

        if ($null -eq $logFiles -or $logFiles.Count -eq 0) {
            Write-Verbose (
                "No outdated log files found older than $retentionDays days " +
                "in '$resolvedPath'."
            )
            return
        }
        Write-Verbose "Found $($logFiles.Count) outdated log file(s) for cleanup."

        # Remove each
        $outputCollection = [System.Collections.Generic.List[object]]::new()
        foreach ($file in $logFiles) {

            try {

                $ageDays = ((Get-Date) - $file.LastWriteTime).Days

                if ($PSCmdlet.ShouldProcess(
                        $file.FullName,
                        "Remove outdated log file"
                )) {
                    Remove-Item `
                        -LiteralPath $file.FullName `
                        -Force `
                        -ErrorAction Stop
                    $outputCollection.Add(
                        [PSCustomObject]@{
                            PSTypeName = 'Logging.Cleanup.Result'
                            Action     = 'DeletedFile'
                            Path       = $file.FullName.Replace($resolvedPath, '').TrimStart('\')
                            AgeDays    = $ageDays
                        }
                    )
                }
            }
            catch {

                Write-Warning (
                    "Failed to remove log file '$($file.FullName)': $($_.Exception.Message)"
                )
            }
        }

        # Remove orphan directories
        if (-not $KeepEmptyDirectories) {

            $directories = Get-ChildItem `
                -LiteralPath $resolvedPath `
                -Directory `
                -Recurse `
                -ErrorAction Stop `
                | Sort-Object FullName -Descending

            foreach ($directory in $directories) {

                try {

                    $remainingItems = Get-ChildItem `
                        -LiteralPath $directory.FullName `
                        -Force `
                        -ErrorAction Stop

                    if ($remainingItems.Count -eq 0) {

                        if ($PSCmdlet.ShouldProcess(
                                $directory.FullName,
                                "Remove empty directory"
                        )) {
                            Remove-Item `
                                -LiteralPath $directory.FullName `
                                -Force `
                                -ErrorAction Stop
                            $outputCollection.Add(
                                [PSCustomObject]@{
                                    PSTypeName = 'Logging.Cleanup.Result'
                                    Action     = 'DeletedDirectory'
                                    Path       = $directory.FullName.Replace($resolvedPath, '').TrimStart('\')
                                    AgeDays    = $null
                                }
                            )
                        }
                    }
                }
                catch {

                    Write-Warning (
                        "Failed to remove directory '$($directory.FullName)': $($_.Exception.Message)"
                    )
                }
            }
        }

        # Finally
        $outputCollection | Format-Table -AutoSize
    }
    catch {

        Write-Error (
            "Unexpected error in Clear-Logging: $($_.Exception.Message)"
        )
    }
}
