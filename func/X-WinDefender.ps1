# Initialize the global state tracking object if it does not exist.
if (-not $global:__wnd_previous_preferences) {
    $global:__wnd_previous_preferences = @{
        RealtimeMonitoring = $null
        BehaviorMonitoring = $null
        BlockAtFirstSeen   = $null
        IOAVProtection     = $null
        PrivacyMode        = $null
    }
}

<#
.SYNOPSIS
    Temporarily disables Windows Defender real-time protection features and backs up their current states.
#>
function Stop-WinDefender {
    Write-Verbose "Stopping Windows Defender..."

    try {
        # 1. Fetch current live preferences from the system
        $currentPrefs = Get-MpPreference -ErrorAction Stop

        # 2. Backup and disable RealtimeMonitoring
        if ($null -eq $global:__wnd_previous_preferences.RealtimeMonitoring) {
            $global:__wnd_previous_preferences.RealtimeMonitoring = $currentPrefs.DisableRealtimeMonitoring
        }
        if (-not $currentPrefs.DisableRealtimeMonitoring) {
            Set-MpPreference -DisableRealtimeMonitoring $true
        }

        # 3. Backup and disable BehaviorMonitoring
        if ($null -eq $global:__wnd_previous_preferences.BehaviorMonitoring) {
            $global:__wnd_previous_preferences.BehaviorMonitoring = $currentPrefs.DisableBehaviorMonitoring
        }
        if (-not $currentPrefs.DisableBehaviorMonitoring) {
            Set-MpPreference -DisableBehaviorMonitoring $true
        }

        # 4. Backup and disable BlockAtFirstSeen
        if ($null -eq $global:__wnd_previous_preferences.BlockAtFirstSeen) {
            $global:__wnd_previous_preferences.BlockAtFirstSeen = $currentPrefs.DisableBlockAtFirstSeen
        }
        if (-not $currentPrefs.DisableBlockAtFirstSeen) {
            Set-MpPreference -DisableBlockAtFirstSeen $true
        }

        # 5. Backup and disable IOAVProtection (IE/Edge download scanning)
        if ($null -eq $global:__wnd_previous_preferences.IOAVProtection) {
            $global:__wnd_previous_preferences.IOAVProtection = $currentPrefs.DisableIOAVProtection
        }
        if (-not $currentPrefs.DisableIOAVProtection) {
            Set-MpPreference -DisableIOAVProtection $true
        }

        # 6. Backup and disable PrivacyMode (hides malware history from non-admins)
        if ($null -eq $global:__wnd_previous_preferences.PrivacyMode) {
            $global:__wnd_previous_preferences.PrivacyMode = $currentPrefs.DisablePrivacyMode
        }
        if (-not $currentPrefs.DisablePrivacyMode) {
            Set-MpPreference -DisablePrivacyMode $true
        }

        # Finally
        Write-Host "Changed Windows Defender..." -ForegroundColor Yellow
        $outputCollection = @(
            [PSCustomObject]@{ Feature = "RealtimeMonitoring"; PreviousState = if ($global:__wnd_previous_preferences.RealtimeMonitoring) { "Disabled" } else { "Enabled" }; NewState = "Disabled" }
            [PSCustomObject]@{ Feature = "BehaviorMonitoring"; PreviousState = if ($global:__wnd_previous_preferences.BehaviorMonitoring) { "Disabled" } else { "Enabled" }; NewState = "Disabled" }
            [PSCustomObject]@{ Feature = "BlockAtFirstSeen"; PreviousState = if ($global:__wnd_previous_preferences.BlockAtFirstSeen) { "Disabled" } else { "Enabled" }; NewState = "Disabled" }
            [PSCustomObject]@{ Feature = "IOAVProtection"; PreviousState = if ($global:__wnd_previous_preferences.IOAVProtection) { "Disabled" } else { "Enabled" }; NewState = "Disabled" }
            [PSCustomObject]@{ Feature = "PrivacyMode"; PreviousState = if ($global:__wnd_previous_preferences.PrivacyMode) { "Disabled" } else { "Enabled" }; NewState = "Disabled" }
        )
        $outputCollection | Format-Table -Autosize
    }
    catch {
        Write-Warning "Failed to stop Windows Defender. Ensure Tamper Protection is disabled and running as Admin. Reason: $_"
    }
}

<#
.SYNOPSIS
    Restores Windows Defender protection features to their original pre-stopped state.
#>
function Start-WinDefender {
    Write-Verbose "Starting Windows Defender..."

    try {
        # If no backup exists, we default to enabling the protection ($false means "Do NOT disable")
        $targetRealtime = if ($null -ne $global:__wnd_previous_preferences.RealtimeMonitoring) { $global:__wnd_previous_preferences.RealtimeMonitoring } else { $false }
        $targetBehavior = if ($null -ne $global:__wnd_previous_preferences.BehaviorMonitoring) { $global:__wnd_previous_preferences.BehaviorMonitoring } else { $false }
        $targetBlockAt = if ($null -ne $global:__wnd_previous_preferences.BlockAtFirstSeen) { $global:__wnd_previous_preferences.BlockAtFirstSeen }   else { $false }
        $targetIOAV = if ($null -ne $global:__wnd_previous_preferences.IOAVProtection) { $global:__wnd_previous_preferences.IOAVProtection }     else { $false }
        $targetPrivacy = if ($null -ne $global:__wnd_previous_preferences.PrivacyMode) { $global:__wnd_previous_preferences.PrivacyMode }        else { $false }

        # Reapply the original states to the system
        Set-MpPreference -DisableRealtimeMonitoring $targetRealtime `
            -DisableBehaviorMonitoring $targetBehavior `
            -DisableBlockAtFirstSeen $targetBlockAt `
            -DisableIOAVProtection $targetIOAV `
            -DisablePrivacyMode $targetPrivacy

        Write-Host "Changed Windows Defender..." -ForegroundColor Yellow
        $outputCollection = @(
            [PSCustomObject]@{ Feature = "RealtimeMonitoring"; StoppedState = "Disabled"; RestoredState = if ($targetRealtime) { "Disabled" } else { "Enabled" } }
            [PSCustomObject]@{ Feature = "BehaviorMonitoring"; StoppedState = "Disabled"; RestoredState = if ($targetBehavior) { "Disabled" } else { "Enabled" } }
            [PSCustomObject]@{ Feature = "BlockAtFirstSeen";   StoppedState = "Disabled"; RestoredState = if ($targetBlockAt)  { "Disabled" } else { "Enabled" } }
            [PSCustomObject]@{ Feature = "IOAVProtection";     StoppedState = "Disabled"; RestoredState = if ($targetIOAV)     { "Disabled" } else { "Enabled" } }
            [PSCustomObject]@{ Feature = "PrivacyMode";        StoppedState = "Disabled"; RestoredState = if ($targetPrivacy)  { "Disabled" } else { "Enabled" } }
        )
        $outputCollection | Format-Table -Autosize

        # Reset the global variables cache so they can be fresh-read during the next cycle
        $global:__wnd_previous_preferences.RealtimeMonitoring = $null
        $global:__wnd_previous_preferences.BehaviorMonitoring = $null
        $global:__wnd_previous_preferences.BlockAtFirstSeen = $null
        $global:__wnd_previous_preferences.IOAVProtection = $null
        $global:__wnd_previous_preferences.PrivacyMode = $null

    }
    catch {
        Write-Warning "Failed to restore Windows Defender states. Reason: $_"
    }
}
