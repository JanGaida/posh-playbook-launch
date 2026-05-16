<#
.SYNOPSIS
    Requests admin privileges and restarts the script with elevated rights if needed.
#>
function Request-AdminRole {
    # Check assigned roles
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($identity)
    $hasAdminPriveleges = $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

    # Contains admin?
    if (-not $hasAdminPriveleges) {
        Write-Verbose "Elevating privileges..."

        # Determine the current PowerShell executable (pwsh or powershell.exe)
        $psExe = if ($IsCoreCLR) { "pwsh" } else { "powershell.exe" }

        # Get the current script path (works for both .ps1 files and direct execution)
        $scriptPath = $global:MyInvocation.MyCommand.Definition
        if (-not $scriptPath -or $scriptPath -eq "") {
            $scriptPath = $PSScriptRoot
        }

        # Build argument list: preserve all original parameters (including switches like -Log)
        $scriptArgs = @()
        foreach ($param in $script:PSBoundParameters.GetEnumerator()) {
            $scriptArgs += "-$($param.Key)"
            if ($param.Value -ne $true -and $param.Value -ne $false) {
                $scriptArgs += "`"$($param.Value)`""  # Quote values to handle spaces
            }
        }

        # Start the script again with admin rights
        $startParams = @{
            FilePath     = $psExe
            ArgumentList = "-NoProfile -ExecutionPolicy Bypass -File `"$scriptPath`" $($scriptArgs -join ' ')"
            Verb         = "RunAs"
            Wait         = $false
            PassThru     = $false
        }

        try {
            Write-Verbose "Restarting script with admin rights: $psExe $($startParams.ArgumentList)"
            Start-Process @startParams
            Write-Host "`nFinished script...`n" -ForegroundColor Cyan
            Exit-App  # Terminate the non-elevated instance
        }
        catch {
            Write-Error "Unexpected Error in func 'X-AdminRole.ps1' in $($MyInvocation.MyCommand.Name) at line $($_.InvocationInfo.ScriptLineNumber): $_"
            Exit-App -Error
        }
    }
    else {
        Write-Verbose "Already running with admin privileges."
    }
}
