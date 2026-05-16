#Requires -Version 7.0
<#
.SYNOPSIS
    Launches and manages the execution of a playbook.
#>
[CmdletBinding()]
param (
    [Parameter(Mandatory = $true)]
    [string]
    $Playbook,

    [Parameter(Mandatory = $false)]
    [string]
    $PlaybookDir = "",

    [Parameter(Mandatory = $false)]
    [switch]
    $Log = $false
)

begin {
    $__reached = 'None'
    try {
        # Prepare
        $__reached = "Prepare"
        $__FuncDir = Join-Path -Path $PSScriptRoot -ChildPath "func"
        if (-not (Test-Path -Path $__FuncDir)) {
            Write-Error "Function directory not found: '$__FuncDir'."
            Exit-App -Error
        }

        # Assemblies
        $__reached = "Assemblies"
        try {
            Add-Type -AssemblyName System.Windows.Forms
            Add-Type -AssemblyName System.Drawing
        }
        catch {
            Write-Error "Failed to load required assemblies: $_"
            Exit-App -Error
        }

        # Win32
        Add-Type (
            "using System;`n" +
            "using System.Runtime.InteropServices;`n" +
            "public static class Win32 {`n" +
            "    [DllImport(`"kernel32.dll`")]`n" +
            "    public static extern IntPtr GetConsoleWindow();`n" +
            "    [DllImport(`"user32.dll`")]`n" +
            "    public static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);`n" +
            "}"
        )

        # Imports
        $__reached = "Imports"
        Write-Host "Importing functions..." -ForegroundColor Cyan
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

        # Finally
        $__reached = "Finally"
        Write-Host "Starting script...`n" -ForegroundColor Cyan
    }
    catch {
        Write-Error "Unexpected Error in section '$__reached' in $($MyInvocation.MyCommand.Name) at line $($_.InvocationInfo.ScriptLineNumber): $_"
        Exit-App -Error
    }
}

process {
    $__reached = 'None'
    try {
        # Enforce admin-privileges
        $__reached = "Request-AdminRole"
        Request-AdminRole

        # Start logging
        $__reached = "Resolve-Logging"
        Resolve-Logging

        # Start trayIcon
        $__reached = "Register-TrayIcon"
        Register-TrayIcon

        # Hide
        Hide-App

        # Playbook
        $__reached = "Invoke-Playbook"
        Invoke-Playbook

        # Optimizations
        Optimize-WinServices
        Optimize-ProcessPriority

        # Playbook
        $__reached = "Wait-Playbook"
        Wait-Playbook
    }
    catch {
        Write-Error "Unexpected Error in section '$__reached' in $($MyInvocation.MyCommand.Name) at line $($_.InvocationInfo.ScriptLineNumber): $_"
        Exit-App -Error
    }
}
