# Init
if (-not $global:__opt_priority_class) {
    $global:__opt_priority_class = [System.Collections.Generic.List[PSCustomObject]]::new()
}

<#
.SYNOPSIS
    Adjusts the CPU priority of a running process.
#>
function Set-ProcessPriority {
    param (
        [Parameter(Mandatory = $true)]
        [System.Diagnostics.Process]
        $Process,

        [Parameter(Mandatory = $true)]
        [ValidateSet("Idle", "BelowNormal", "Normal", "AboveNormal", "High", "RealTime")]
        [string]
        $PriorityClass,

        [Parameter(Mandatory = $false)]
        [switch]
        $Silent = $false
    )

    try {
        if (-not $Silent) {
            $_previous_PriorityClass = $Process.PriorityClass
            $Process.PriorityClass = $PriorityClass
            if (-not $Silent) {
                Write-Verbose (
                    "Adjusted Process-Priority`n" +
                    "        PID = $($Process.Id)`n" +
                    "  New Class = $PriorityClass`n" +
                    "Prev. Class = $_previous_PriorityClass"
                )
            }
        }
        else {
            $Process.PriorityClass = $PriorityClass
        }
    }
    catch {
        Write-Warning "Unexpected Error in func 'Set-ProcessPriority.ps1' in $($MyInvocation.MyCommand.Name) at line $($_.InvocationInfo.ScriptLineNumber): $_"
    }
}

<#
.SYNOPSIS
    Optimizes the CPU priority of a configured processes.
#>
function Optimize-ProcessPriority {
    $outputCollection = [System.Collections.Generic.List[PSCustomObject]]::new()

    # Optimize self
    $selfPriority = $global:Cfg.Optimiziations.Priority_Class.Self
    if ($selfPriority) {
        try {
            $currentProc = [System.Diagnostics.Process]::GetCurrentProcess()
            $previousClass = $currentProc.PriorityClass

            if ($previousClass -ne $selfPriority) {
                Write-Verbose "Optimizing self process priority to: $selfPriority"
                Set-ProcessPriority -Process $currentProc -PriorityClass $selfPriority -Silent

                $stateRecord = [PSCustomObject]@{
                    Changed       = if ($selfPriority -eq $previousClass) { 'No' } else { 'Yes' }
                    NowState      = $selfPriority
                    PreviousState = $previousClass
                    Name          = $currentProc.ProcessName
                    PID           = $currentProc.Id
                }
                #$global:__opt_priority_class.Add($stateRecord)
                $outputCollection.Add($stateRecord)
            }
        }
        catch {
            Write-Warning "Failed to optimize self process priority. Reason: $_"
        }
    }

    # Optimize side apps
    $priorityLevels = @('Idle', 'BelowNormal', 'Normal', 'AboveNormal', 'High', 'RealTime')
    $appsConfig = $global:Cfg.Optimiziations.Priority_Class.Apps
    if ($appsConfig) {
        foreach ($targetPriority in $priorityLevels) {
            $patterns = $appsConfig.$targetPriority
            if (-not $patterns -or $patterns.Count -eq 0) { continue }

            foreach ($pattern in $patterns) {
                Write-Verbose "Resolving process pattern '$pattern' for target priority '$targetPriority'..."

                # Get-Process natively handles wildcards
                $matchedProcesses = Get-Process -Name $pattern -ErrorAction SilentlyContinue

                foreach ($proc in $matchedProcesses) {
                    # Skip self if it was accidentally targeted in the app patterns
                    if ($proc.Id -eq $PID) { continue }

                    try {
                        $previousClass = $proc.PriorityClass

                        # Only change if the current priority differs from the target

                        if ($previousClass -ne $targetPriority) {

                            # Only if new priority is lower than current
                            $targetIndex  = $priorityLevels.IndexOf("$targetPriority")
                            $currentIndex = $priorityLevels.IndexOf("$previousClass")
                            if ($targetIndex -ge $currentIndex) { continue; }

                            Set-ProcessPriority -Process $proc -PriorityClass $targetPriority -Silent

                            $stateRecord = [PSCustomObject]@{
                                Changed       = if ($targetPriority -eq $previousClass) { 'No' } else { 'Yes' }
                                NowState      = $targetPriority
                                PreviousState = $previousClass
                                Name          = $proc.ProcessName
                                PID           = $proc.Id
                            }
                            $global:__opt_priority_class.Add($stateRecord)
                            $outputCollection.Add($stateRecord)
                        }
                    }
                    catch {
                        Write-Error "Failed to update process '$($proc.ProcessName)' (PID: $($proc.Id)). Reason: $_"
                    }
                }
            }

        }
    }

    # Finally
    Write-Host "Optimized processs priorities..."
    $outputCollection | Format-Table -AutoSize
}

<#
.SYNOPSIS
    Restores the CPU priority of a configured processes.
#>
function Restore-ProcessPriority {
    if (-not $global:__opt_priority_class -or $global:__opt_priority_class.Count -eq 0) {
        Write-Verbose "No process priorities to restore."
        return
    }
    $outputCollection = [System.Collections.Generic.List[PSCustomObject]]::new()

    foreach ($savedProc in $global:__opt_priority_class) {
        Write-Verbose "Restoring process '$($savedProc.Name)' (PID: $($savedProc.PID)) to $($savedProc.PreviousState)..."

        try {
            # Find the exact process by its unique PID to prevent wildcard mismatches on restore
            $proc = Get-Process -Id $savedProc.PID -ErrorAction SilentlyContinue

            if ($proc) {
                $currentClass = $proc.PriorityClass
                Set-ProcessPriority -Process $proc -PriorityClass $savedProc.PreviousState -Silent

                $restoreRecord = [PSCustomObject]@{
                    Changed       = if ($currentClass -eq $proc.PriorityClass) { 'No' } else { 'Yes' }
                    NowState      = $proc.PriorityClass
                    PreviousState = $currentClass
                    Name          = $savedProc.Name
                    PID           = $savedProc.PID
                }
                $outputCollection.Add($restoreRecord)
            }
            else {
                Write-Verbose "Process '$($savedProc.Name)' (PID: $($savedProc.PID)) is no longer running. Skipping restore."
            }
        }
        catch {
            Write-Error "Failed to restore process '$($savedProc.Name)' (PID: $($savedProc.PID)). Reason: $_"
        }
    }

    # Finally
    $global:__opt_priority_class.Clear()
    Write-Host -NoNewline  "Restored processs priorities..."
    $outputCollection | Format-Table -AutoSize
}
