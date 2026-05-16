<#
.SYNOPSIS
    Changes the power configuration to enforce an ratio of cpu-cores to be awake at all the time.
#>
function Optimize-CoreParking {
    param(
        [Parameter(Mandatory = $false)]
        [switch]
        $Restore
    )

    Resolve-Configs

    # Guard
    if (-not $global:Cfg.Optimiziations.Core_Parking.Enabled) {
        return
    }

    # Prepare
    $outputCollection = [System.Collections.Generic.List[PSCustomObject]]::new()

    # GUIDs
    $subProcessor = "SUB_PROCESSOR"
    $settingMinCores = "CPMINCORES"

    # Read current value
    try {
        $powerCfgOutput = powercfg /query SCHEME_CURRENT $subProcessor $settingMinCores 2>$null
        $currentValueLine = $powerCfgOutput |
        Select-String "Current AC Power Setting Index"

        if ($currentValueLine) {
            $hexValue = ($currentValueLine.Line -split ':')[-1].Trim()
            $hexValue = $hexValue -replace '^0x', ''
            $previousValue = [Convert]::ToInt32($hexValue, 16)
        }
        else {
            $previousValue = $null
        }
    }
    catch {
        $previousValue = $null
    }

    if ($Restore) {
        Write-Host "Restoring core parking configuration..."
        $newValue = $global:__core_parking_old
        $global:__core_parking_old = $null
    }
    else {
        Write-Host "Optimizing core parking configuration..."
        $newValue = [int]$global:Cfg.Optimiziations.Core_Parking.Min_Percentage
        if ($null -eq $global:__core_parking_old) {
            $global:__core_parking_old = $previousValue
        }
    }

    # Apply values (ac + dc)
    powercfg /setacvalueindex SCHEME_CURRENT $subProcessor $settingMinCores $newValue | Out-Null
    powercfg /setdcvalueindex SCHEME_CURRENT $subProcessor $settingMinCores $newValue | Out-Null

    # Activate scheme
    powercfg /setactive SCHEME_CURRENT | Out-Null

    $changed = $previousValue -ne $newValue

    $outputCollection.Add([PSCustomObject]@{
            Changed        = if ($changed) { 'Yes' } else { 'No' }
            Now_Percentage = "$newValue%"
            Old_Percentage = "$previousValue%"
        })

    $outputCollection | Format-Table -AutoSize
}

<#
.SYNOPSIS
    Restores the previous power configuration.
#>
function Restore-CoreParking {
    Optimize-CoreParking -Restore
}