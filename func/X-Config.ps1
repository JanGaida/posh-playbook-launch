<#
.SYNOPSIS
    Loads, validates and normalizes the playbook configuration.
#>
function Initialize-Configs {
    <#
    .SYNOPSIS
        Recursively merges default values into a PSCustomObject.
    #>
    function Merge-Hashtable {
        param(
            [Parameter(Mandatory = $true)]
            [hashtable]
            $Defaults,

            [Parameter(Mandatory = $true)]
            [object]
            $Base
        )

        foreach ($key in $Defaults.Keys) {

            $defaultValue = $Defaults[$key]

            # Property fehlt komplett
            if (-not $Base.PSObject.Properties[$key]) {

                $Base | Add-Member `
                    -MemberType NoteProperty `
                    -Name $key `
                    -Value $defaultValue

                continue
            }

            $configValue = $Base.$key

            # Rekursiver Merge
            if (
                $defaultValue -is [hashtable] -and
                $configValue -is [pscustomobject]
            ) {
                Merge-Hashtable `
                    -Defaults $defaultValue `
                    -Base $configValue

                continue
            }

            # String leer/null/whitespace -> Default setzen
            if (
                $defaultValue -is [string] -and
                [string]::IsNullOrWhiteSpace($configValue)
            ) {
                $Base.$key = $defaultValue
            }

            # Allgemeines null fallback
            elseif ($null -eq $configValue) {
                $Base.$key = $defaultValue
            }
        }

        return $Base
    }

    # Guard
    if ([string]::IsNullOrWhiteSpace($global:RootDir)) {
        Write-Error "Mandatory variable `$global:RootDir is null or empty."
        Exit-App -Error
    }
    if ([string]::IsNullOrWhiteSpace($global:CliPlaybookName)) {
        Write-Error "Mandatory variable `$global:CliPlaybookName is null or empty."
        Exit-App -Error
    }

    # Config file
    $configPath = Get-ConfigPath

    # Guard
    if (-not $(Test-Path $configPath)) {
        Write-Error "Could not find the configs at filepath '$configPath'."
        Exit-App -Error
    }

    try {
        # Load configs
        $readCfg    = Get-Content -Raw $configPath | ConvertFrom-Json
        $defaultCfg = Get-DefaultConfigs

        # Merge
        $global:Cfg = Merge-Hashtable -Defaults $defaultCfg -Base $readCfg
    }
    catch {
        Write-Error "Unexpected Error in func 'X-Config.ps1' in $($MyInvocation.MyCommand.Name) at line $($_.InvocationInfo.ScriptLineNumber): $_"
        Exit-App -Error
    }
}

<#
.SYNOPSIS
    Enforces that the configs have been loaded.
#>
function Resolve-Configs {
    # Guard
    if ($global:__cfg_initialized) { return }

    # Init them
    try {
        Initialize-Configs
    }
    catch {
        Write-Error "Unexpected Error in func 'X-Config.ps1' in $($MyInvocation.MyCommand.Name) at line $($_.InvocationInfo.ScriptLineNumber): $_"
        Exit-App -Error
    }
    $global:__cfg_initialized = $true
}

<#
.SYNOPSIS
    Returns the default configurations.
#>
function Get-DefaultConfigs {
    # Guard
    if ([string]::IsNullOrWhiteSpace($global:CliPlaybookName)) {
        Write-Error "Mandatory variable `$global:CliPlaybookName is null or empty."
        Exit-App -Error
    }

    # Date
    $date = Get-Date

    return @{
        Playbook = @{
            Name          = $global:CliPlaybookName
            Delay_Ms      = 250
            Log_Enabled   = $false
            Log_Directory = Join-Path `
                -Path $global:RootDir `
                -ChildPath "$("playbooks/$($global:CliPlaybookName)/logs/$($date.ToString("yyyy"))/$($date.ToString("MM"))/$($date.ToString("dd"))")"
            Log_Filename = "transcript_$($date.ToString("HHmmss"))_$($global:CliPlaybookName).log"
            Logging_Append = $false
        }

        Main_App = @{
            Priority_Class = "High"
            Power_Profile  = "Performance"
            Arguments      = $null
        }

        Optimiziations = @{
            Priority_Class = @{
                Self       = "BelowNormal"
                Apps       = @{}
            }
            WinServices    = @{
                Stop       = @()
            }
        }

        Side_Apps = @()
    }


}

<#
.SYNOPSIS
    Returns the filepath to the configurations file specified
#>
function Get-ConfigPath {
    # Guard
    if ([string]::IsNullOrWhiteSpace($global:RootDir)) {
        Write-Error "Mandatory variable `$global:RootDir is null or empty."
        Exit-App -Error
    }

    if ([string]::IsNullOrWhiteSpace($global:PlaybookDir)) {
        return "$(Join-Path `
            -Path      $global:RootDir `
            -ChildPath "playbooks/$global:CliPlaybookName.json"
        )"
    }
    else {
        return "$(Join-Path `
            -Path      $PlaybookDir `
            -ChildPath "$global:CliPlaybookName.json"
        )"
    }
}
