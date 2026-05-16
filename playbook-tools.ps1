#Requires -Version 7.0
<#
todo: synopsis
#>
[CmdletBinding()]
param (
    [Parameter(Mandatory = $true)]
    [ValidateSet("Create-New", "Create-Shortcut")]
    [string]
    $Action,

    [Parameter(Mandatory = $true)]
    [string]
    $Playbook,

    [Parameter(Mandatory = $false)]
    [string]
    $PlaybookDir = "",

    [Parameter(Mandatory = $false)]
    [string]
    $Destination = "",

    [Parameter(Mandatory = $false)]
    [ValidateSet("pwsh.exe", "powershell.exe")]
    [string]
    $Shell = "pwsh.exe"
)

# Prepare
begin {
    Write-Host "Importing functions..." -ForegroundColor Cyan
    $__FuncDir = Join-Path -Path $PSScriptRoot -ChildPath "func"
    Get-ChildItem -Path "$__FuncDir/*.ps1" | ForEach-Object {
        try {
            . $_.FullName
            [PSCustomObject]@{
                Import   = "Success"
                Script   = $_.Name
                FullPath = $_.FullName
            }
        }
        catch {
            [PSCustomObject]@{
                Import   = "Failed"
                Script   = $_.Name
                FullPath = $_.FullName
                Error    = $_.Exception.Message
            }
        }
    } | Format-Table -AutoSize

    # Globals
    $__reached = "Globals"
    $global:CliPlaybookName = $Playbook
    $global:PlaybookDir = $PlaybookDir
    $global:RootDir = $PSScriptRoot

    Write-Host "Starting script...`n" -ForegroundColor Cyan
}

# Act
process {
    # Prepare
    $launchScriptName = "playbook-launch.ps1"

    try {
        switch ($Action) {
            "Create-Shortcut" {
                Write-Host "Creating shortcut..." -ForegroundColor Cyan

                Resolve-Configs
                $mainApp = $global:Cfg.Main_App.Path

                # Prepare
                $rootDir = $PSScriptRoot
                $launchScriptPath = Join-Path $rootDir $launchScriptName
                if ([string]::IsNullOrEmpty($Destination)) {
                    $absoluteTargetDir = [Environment]::GetFolderPath([Environment+SpecialFolder]::Desktop)
                }
                else {
                    $absoluteTargetDir = [System.IO.Path]::GetFullPath($Destination)
                }
                if (-not [string]::IsNullOrEmpty($mainApp) -and (Test-Path $mainApp)) {
                    $exeName = [System.IO.Path]::GetFileNameWithoutExtension($mainApp)
                    $shortcutFilename = "Play $exeName.lnk"
                }
                else {
                    # Fallback, falls der Pfad in der Config leer oder ungültig ist
                    $shortcutFilename = "Play $Playbook.lnk"
                }
                $shortcutPath = Join-Path $absoluteTargetDir $shortcutFilename

                # Build args
                $shortcutArgs = "-NoProfile -ExecutionPolicy Bypass -File `"$launchScriptPath`" -Playbook `"$Playbook`""
                if (-not [string]::IsNullOrEmpty($PlaybookDir)) {
                    $shortcutArgs += " -PlaybookDir `"$PlaybookDir`""
                }
                $shortcutArgs += " -Verbose -Log"

                # Create shortcut
                $wshShell = New-Object -ComObject WScript.Shell
                $shortcut = $wshShell.CreateShortcut($shortcutPath)
                $shortcut.TargetPath = "$Shell"
                $shortcut.WorkingDirectory = "$rootDir"
                $shortcut.Arguments = $shortcutArgs

                # Set icon
                if (-not [string]::IsNullOrEmpty($mainApp) -and (Test-Path $mainApp)) {
                    $shortcut.IconLocation = "$mainApp,0"
                }
                else {
                    $shortcut.IconLocation = "shell32.dll,23"
                }

                # Finally
                Write-Host (
                    "    Output_File = $($shortcutFilename)`n" +
                    "     Output_Dir = $($absoluteTargetDir)`n" +
                    "        Command = $Shell $($shortcut.Arguments)`n" +
                    "           Icon = $($shortcut.IconLocation)"
                )
                $shortcut.Save()
                Write-Host "`nShortcut created successfully!`n" -ForegroundColor Green
            }

            "Create-New" {
                Write-Host "Creating configs..." -ForegroundColor Cyan

                $configPath = Get-ConfigPath
                $defaultConfigs = Get-DefaultConfigs

                $playbookKey = "Playbook"
                $mainAppKey = "Main_App"
                if ($defaultConfigs.PSObject.Properties.Value -contains $playbookKey) {
                    $playbookSec = $defaultConfigs[$playbookKey]
                    $delayMsKey = "Delay_Ms"
                    $logEnabledKey = "Log_Enabled"
                    $logFilenameKey = "Log_Filename"
                    $logDirectoryKey = "Log_Directory"
                    if ($playbookSec.PSObject.Properties.Value -contains $delayMsKey) {
                        $playbookSec.Remove($delayMsKey)
                    }
                    if ($playbookSec.PSObject.Properties.Value -contains $logEnabledKey) {
                        $playbookSec.Remove($logEnabledKey)
                    }
                    if ($playbookSec.PSObject.Properties.Value -contains $logFilenameKey) {
                        $playbookSec.Remove($logFilenameKey)
                    }
                    if ($playbookSec.PSObject.Properties.Value -contains $logDirectoryKey) {
                        $playbookSec.Remove($logDirectoryKey)
                    }
                }
                if ($defaultConfigs.PSObject.Properties.Value -contains $mainAppKey) {
                    $mainAppSec = $defaultConfigs[$mainAppKey]
                    $argumentsKey = "Arguments"
                    $pathKey = "Path"
                    if ($mainAppSec.PSObject.Properties.Value -contains $argumentsKey) {
                        $mainAppSec.Remove($argumentsKey)
                    }
                    $mainAppSec[$pathKey] = "C:\Program Files (x86)\Some Application.exe"
                }

                $finalConfig = New-Object PSCustomObject
                $finalConfig | Add-Member -NotePropertyMembers @{ 
                    '$schema' = "./playbook.schema.json"
                }

                foreach ($key in $defaultConfigs.Keys) {
                    $finalConfig | Add-Member -MemberType NoteProperty -Name $key -Value $defaultConfigs[$key]
                }
                #foreach ($prop in $defaultConfigs.PSObject.Properties) {
                #    $finalConfig | Add-Member -MemberType NoteProperty -Name $prop.Name -Value $prop.Value
                #}

                $jsonRaw = $finalConfig | ConvertTo-Json -Depth 100
                $jsonPretty = ($jsonRaw -split "`r?`n" | ForEach-Object {
                        if ($_ -match '^(\s+)(.*)$') {
                            $spaces = $Matches[1]
                            $content = $Matches[2]
                            "$spaces$spaces$content"
                        }
                        else {
                            $_
                        }
                    }) -join "`r`n"

                $jsonPretty | Set-Content -Path $configPath -Encoding utf8

                Write-Host ("    Output = $($configPath)")
                Write-Host "`nShortcut created successfully!`n" -ForegroundColor Green
            }

            Default {
                Write-Error "Unsupported action."
                Exit-App -Error
            }
        }

        # Done
        Exit-App
    }
    catch {
        Write-Error "Unexpected Error in section '$__reached' in $($MyInvocation.MyCommand.Name) at line $($_.InvocationInfo.ScriptLineNumber): $_"
        Exit-App -Error
    }
}