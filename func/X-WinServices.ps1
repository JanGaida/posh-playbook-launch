# Init
if (-not $global:__opt_win_services) {
    $global:__opt_win_services = [System.Collections.Generic.List[PSCustomObject]]::new()
}

<#
.SYNOPSIS
    Provides functions to optimize the Windows Services based on a global configuration.
#>
function Optimize-WinServices {
    Resolve-Configs
    if (-not $global:Cfg.Optimiziations.WinServices.Stop -or $global:Cfg.Optimiziations.WinServices.Stop.Count -eq 0) {
        Write-Host "No WinServices found in configuration source to be optimized."
        return
    }

    Write-Verbose "Starting Windows Services optimization process..."
    $outputCollection = [System.Collections.Generic.List[PSCustomObject]]::new()
    foreach ($servicePattern in $global:Cfg.Optimiziations.WinServices.Stop) {
        Write-Verbose "Processing service optimization for: $servicePattern"
        try {
            # Get-Service natively resolves wildcards (e.g., "CaptureService_*")
            $matchedServices = Get-Service -Name $servicePattern -ErrorAction Stop

            # Loop through all services that matched the placeholder
            foreach ($service in $matchedServices) {
                $serviceName = $service.Name
                $previousState = $service.Status
                $description = $service.DisplayName

                if ($service.Status -ne 'Stopped') {
                    Write-Verbose "Stopping service '$serviceName'..."
                    Stop-Service -Name $serviceName -Force:$Force -ErrorAction Stop
                    $service.Refresh()
                } else {
                    Write-Verbose "Service '$serviceName' is already stopped."
                }

                $nowState = $service.Status

                # Construct the record object with the exact resolved name
                $stateRecord = [PSCustomObject]@{
                    Changed       = if ($nowState -eq $previousState) { 'No' } else { 'Yes' }
                    NowState      = $nowState
                    PreviousState = $previousState
                    Name          = $serviceName
                    Desc          = $description
                }

                # Save the exact service to global memory and output collection
                $global:__opt_win_services.Add($stateRecord)
                $outputCollection.Add($stateRecord)
            }
        }
        catch {
            Write-Warning "Failed to optimize service '$serviceName'. Reason: $_"
        }
    }

    # Finally
    Write-Host "Optimized Windows Services..."
    $outputCollection | Format-Table -AutoSize
}

<#
.SYNOPSIS
    Provides functions to restore the state of the Windows Services based on a global configuration.
#>
function Restore-WinServices {
    if (-not $global:__opt_win_services -or $global:__opt_win_services.Count -eq 0) {
        Write-Verbose "No WinServices to be restored. Tracking registry is empty."
        return
    }

    Write-Verbose "Starting Windows Services restoration process..."
    $outputCollection = [System.Collections.Generic.List[PSCustomObject]]::new()
    foreach ($savedService in $global:__opt_win_services) {
        $serviceName = $savedService.Name
        Write-Verbose "Restoring service '$serviceName' to its previous state: $($savedService.PreviousState)"

        try {
            $service = Get-Service -Name $serviceName -ErrorAction Stop

            # Restore to previous state only if it differs from current state
            if ($savedService.PreviousState -eq 'Running' -and $service.Status -ne 'Running') {
                Start-Service -Name $serviceName -ErrorAction Stop
            }
            elseif ($savedService.PreviousState -eq 'Stopped' -and $service.Status -ne 'Stopped') {
                Stop-Service -Name $serviceName -Force -ErrorAction Stop
            }

            $service.Refresh()
            $nowState = $service.Status
            $previousState = $savedService.NowState
            $restoreRecord = [PSCustomObject]@{
                Changed       = if ($nowState -eq $previousState) { 'No' } else { 'Yes' }
                NowState      = $nowState
                PreviousState = $previousState
                Name          = $serviceName
                Desc          = $savedService.Desc
            }

            $outputCollection.Add($restoreRecord)
        }
        catch {
            Write-Error "Failed to restore service '$serviceName'. Reason: $_"
        }
    }

    # Finally
    $global:__opt_win_services.Clear()
    Write-Host -NoNewline "Restored Windows Services..."
    $outputCollection | Format-Table -AutoSize
}
