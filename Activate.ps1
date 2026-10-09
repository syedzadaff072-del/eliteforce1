<#
.Synopsis
Activate a Python virtual environment for the current PowerShell session.

.Description
Pushes the python executable for a virtual environment to the front of the
$Env:PATH environment variable and sets the prompt to signify that you are
in a Python virtual environment. Makes use of the command line switches as
well as the `pyvenv.cfg` file values present in the virtual environment.

.Parameter VenvDir
Path to the directory that contains the virtual environment to activate. The
default value for this is the parent of the directory that the Activate.ps1
script is located within.

.Parameter Prompt
The prompt prefix to display when this virtual environment is activated. By
default, this prompt is the name of the virtual environment folder (VenvDir)
surrounded by parentheses and followed by a single space (ie. '(.venv) ').

.Example
Activate.ps1
Activates the Python virtual environment that contains the Activate.ps1 script.

.Example
Activate.ps1 -Verbose
Activates the Python virtual environment that contains the Activate.ps1 script,
and shows extra information about the activation as it executes.

.Example
Activate.ps1 -VenvDir C:\Users\MyUser\Common\.venv
Activates the Python virtual environment located in the specified location.

.Example
Activate.ps1 -Prompt "MyPython"
Activates the Python virtual environment that contains the Activate.ps1 script,
and prefixes the current prompt with the specified string (surrounded in
parentheses) while the virtual environment is active.

.Notes
On Windows, it may be required to enable this Activate.ps1 script by setting the
execution policy for the user. You can do this by issuing the following PowerShell
command:

PS C:\> Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser

For more information on Execution Policies: 
https://go.microsoft.com/fwlink/?LinkID=135170

#>
Param(
    [Parameter(Mandatory = $false)]
    [String]
    $VenvDir,
    [Parameter(Mandatory = $false)]
    [String]
    $Prompt
)

<# Function declarations --------------------------------------------------- #>

<#
.Synopsis
Remove all shell session elements added by the Activate script, including the
addition of the virtual environment's Python executable from the beginning of
the PATH variable.

.Parameter NonDestructive
If present, do not remove this function from the global namespace for the
session.

#>
function global:deactivate ([switch]$NonDestructive) {
    # Revert to original values

    # The prior prompt:
    if (Test-Path -Path Function:_OLD_VIRTUAL_PROMPT) {
        Copy-Item -Path Function:_OLD_VIRTUAL_PROMPT -Destination Function:prompt
        Remove-Item -Path Function:_OLD_VIRTUAL_PROMPT
    }

    # The prior PYTHONHOME:
    if (Test-Path -Path Env:_OLD_VIRTUAL_PYTHONHOME) {
        Copy-Item -Path Env:_OLD_VIRTUAL_PYTHONHOME -Destination Env:PYTHONHOME
        Remove-Item -Path Env:_OLD_VIRTUAL_PYTHONHOME
    }

    # The prior PATH:
    if (Test-Path -Path Env:_OLD_VIRTUAL_PATH) {
        Copy-Item -Path Env:_OLD_VIRTUAL_PATH -Destination Env:PATH
        Remove-Item -Path Env:_OLD_VIRTUAL_PATH
    }

    # Just remove the VIRTUAL_ENV altogether:
    if (Test-Path -Path Env:VIRTUAL_ENV) {
        Remove-Item -Path env:VIRTUAL_ENV
    }

    # Just remove VIRTUAL_ENV_PROMPT altogether.
    if (Test-Path -Path Env:VIRTUAL_ENV_PROMPT) {
        Remove-Item -Path env:VIRTUAL_ENV_PROMPT
    }

    # Just remove the _PYTHON_VENV_PROMPT_PREFIX altogether:
    if (Get-Variable -Name "_PYTHON_VENV_PROMPT_PREFIX" -ErrorAction SilentlyContinue) {
        Remove-Variable -Name _PYTHON_VENV_PROMPT_PREFIX -Scope Global -Force
    }

    # Leave deactivate function in the global namespace if requested:
    if (-not $NonDestructive) {
        Remove-Item -Path function:deactivate
    }
}

<#
.Description
Get-PyVenvConfig parses the values from the pyvenv.cfg file located in the
given folder, and returns them in a map.

For each line in the pyvenv.cfg file, if that line can be parsed into exactly
two strings separated by `=` (with any amount of whitespace surrounding the =)
then it is considered a `key = value` line. The left hand string is the key,
the right hand is the value.

If the value starts with a `'` or a `"` then the first and last character is
stripped from the value before being captured.

.Parameter ConfigDir
Path to the directory that contains the `pyvenv.cfg` file.
#>
function Get-PyVenvConfig(
    [String]
    $ConfigDir
) {
    Write-Verbose "Given ConfigDir=$ConfigDir, obtain values in pyvenv.cfg"

    # Ensure the file exists, and issue a warning if it doesn't (but still allow the function to continue).
    $pyvenvConfigPath = Join-Path -Resolve -Path $ConfigDir -ChildPath 'pyvenv.cfg' -ErrorAction Continue

    # An empty map will be returned if no config file is found.
    $pyvenvConfig = @{ }

    if ($pyvenvConfigPath) {

        Write-Verbose "File exists, parse `key = value` lines"
        $pyvenvConfigContent = Get-Content -Path $pyvenvConfigPath

        $pyvenvConfigContent | ForEach-Object {
            $keyval = $PSItem -split "\s*=\s*", 2
            if ($keyval[0] -and $keyval[1]) {
                $val = $keyval[1]

                # Remove extraneous quotations around a string value.
                if ("'""".Contains($val.Substring(0, 1))) {
                    $val = $val.Substring(1, $val.Length - 2)
                }

                $pyvenvConfig[$keyval[0]] = $val
                Write-Verbose "Adding Key: '$($keyval[0])'='$val'"
            }
        }
    }
    return $pyvenvConfig
}


<# Begin Activate script --------------------------------------------------- #>

# Determine the containing directory of this script
$VenvExecPath = Split-Path -Parent $MyInvocation.MyCommand.Definition
$VenvExecDir = Get-Item -Path $VenvExecPath

Write-Verbose "Activation script is located in path: '$VenvExecPath'"
Write-Verbose "VenvExecDir Fullname: '$($VenvExecDir.FullName)"
Write-Verbose "VenvExecDir Name: '$($VenvExecDir.Name)"

# Set values required in priority: CmdLine, ConfigFile, Default
# First, get the location of the virtual environment, it might not be
# VenvExecDir if specified on the command line.
if ($VenvDir) {
    Write-Verbose "VenvDir given as parameter, using '$VenvDir' to determine values"
}
else {
    Write-Verbose "VenvDir not given as a parameter, using parent directory name as VenvDir."
    $VenvDir = $VenvExecDir.Parent.FullName.TrimEnd("\\/")
    Write-Verbose "VenvDir=$VenvDir"
}

# Next, read the `pyvenv.cfg` file to determine any required value such
# as `prompt`.
$pyvenvCfg = Get-PyVenvConfig -ConfigDir $VenvDir

# Next, set the prompt from the command line, or the config file, or
# just use the name of the virtual environment folder.
if ($Prompt) {
    Write-Verbose "Prompt specified as argument, using '$Prompt'"
}
else {
    Write-Verbose "Prompt not specified as argument to script, checking pyvenv.cfg value"
    if ($pyvenvCfg -and $pyvenvCfg['prompt']) {
        Write-Verbose "  Setting based on value in pyvenv.cfg='$($pyvenvCfg['prompt'])'"
        $Prompt = $pyvenvCfg['prompt'];
    }
    else {
        Write-Verbose "  Setting prompt based on parent's directory's name. (Is the directory name passed to venv module when creating the virtual environment)"
        Write-Verbose "  Got leaf-name of $VenvDir='$(Split-Path -Path $venvDir -Leaf)'"
        $Prompt = Split-Path -Path $venvDir -Leaf
    }
}

Write-Verbose "Prompt = '$Prompt'"
Write-Verbose "VenvDir='$VenvDir'"

# Deactivate any currently active virtual environment, but leave the
# deactivate function in place.
deactivate -nondestructive

# Now set the environment variable VIRTUAL_ENV, used by many tools to determine
# that there is an activated venv.
$env:VIRTUAL_ENV = $VenvDir

$env:VIRTUAL_ENV_PROMPT = $Prompt

if (-not $Env:VIRTUAL_ENV_DISABLE_PROMPT) {

    Write-Verbose "Setting prompt to '$Prompt'"

    # Set the prompt to include the env name
    # Make sure _OLD_VIRTUAL_PROMPT is global
    function global:_OLD_VIRTUAL_PROMPT { "" }
    Copy-Item -Path function:prompt -Destination function:_OLD_VIRTUAL_PROMPT
    New-Variable -Name _PYTHON_VENV_PROMPT_PREFIX -Description "Python virtual environment prompt prefix" -Scope Global -Option ReadOnly -Visibility Public -Value $Prompt

    function global:prompt {
        Write-Host -NoNewline -ForegroundColor Green "($_PYTHON_VENV_PROMPT_PREFIX) "
        _OLD_VIRTUAL_PROMPT
    }
}

# Clear PYTHONHOME
if (Test-Path -Path Env:PYTHONHOME) {
    Copy-Item -Path Env:PYTHONHOME -Destination Env:_OLD_VIRTUAL_PYTHONHOME
    Remove-Item -Path Env:PYTHONHOME
}

# Add the venv to the PATH
Copy-Item -Path Env:PATH -Destination Env:_OLD_VIRTUAL_PATH
$Env:PATH = "$VenvExecDir$([System.IO.Path]::PathSeparator)$Env:PATH"

# SIG # Begin signature block
# MII28gYJKoZIhvcNAQcCoII24zCCNt8CAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCBALKwKRFIhr2RY
# IW/WJLd9pc8a9sj/IoThKU92fTfKsKCCG1wwggXMMIIDtKADAgECAhBUmNLR1FsZ
# lUgTecgRwIeZMA0GCSqGSIb3DQEBDAUAMHcxCzAJBgNVBAYTAlVTMR4wHAYDVQQK
# ExVNaWNyb3NvZnQgQ29ycG9yYXRpb24xSDBGBgNVBAMTP01pY3Jvc29mdCBJZGVu
# dGl0eSBWZXJpZmljYXRpb24gUm9vdCBDZXJ0aWZpY2F0ZSBBdXRob3JpdHkgMjAy
# MDAeFw0yMDA0MTYxODM2MTZaFw00NTA0MTYxODQ0NDBaMHcxCzAJBgNVBAYTAlVT
# MR4wHAYDVQQKExVNaWNyb3NvZnQgQ29ycG9yYXRpb24xSDBGBgNVBAMTP01pY3Jv
# c29mdCBJZGVudGl0eSBWZXJpZmljYXRpb24gUm9vdCBDZXJ0aWZpY2F0ZSBBdXRo
# b3JpdHkgMjAyMDCCAiIwDQYJKoZIhvcNAQEBBQADggIPADCCAgoCggIBALORKgeD
# Bmf9np3gx8C3pOZCBH8Ppttf+9Va10Wg+3cL8IDzpm1aTXlT2KCGhFdFIMeiVPvH
# or+Kx24186IVxC9O40qFlkkN/76Z2BT2vCcH7kKbK/ULkgbk/WkTZaiRcvKYhOuD
# PQ7k13ESSCHLDe32R0m3m/nJxxe2hE//uKya13NnSYXjhr03QNAlhtTetcJtYmrV
# qXi8LW9J+eVsFBT9FMfTZRY33stuvF4pjf1imxUs1gXmuYkyM6Nix9fWUmcIxC70
# ViueC4fM7Ke0pqrrBc0ZV6U6CwQnHJFnni1iLS8evtrAIMsEGcoz+4m+mOJyoHI1
# vnnhnINv5G0Xb5DzPQCGdTiO0OBJmrvb0/gwytVXiGhNctO/bX9x2P29Da6SZEi3
# W295JrXNm5UhhNHvDzI9e1eM80UHTHzgXhgONXaLbZ7LNnSrBfjgc10yVpRnlyUK
# xjU9lJfnwUSLgP3B+PR0GeUw9gb7IVc+BhyLaxWGJ0l7gpPKWeh1R+g/OPTHU3mg
# trTiXFHvvV84wRPmeAyVWi7FQFkozA8kwOy6CXcjmTimthzax7ogttc32H83rwjj
# O3HbbnMbfZlysOSGM1l0tRYAe1BtxoYT2v3EOYI9JACaYNq6lMAFUSw0rFCZE4e7
# swWAsk0wAly4JoNdtGNz764jlU9gKL431VulAgMBAAGjVDBSMA4GA1UdDwEB/wQE
# AwIBhjAPBgNVHRMBAf8EBTADAQH/MB0GA1UdDgQWBBTIftJqhSobyhmYBAcnz1AQ
# T2ioojAQBgkrBgEEAYI3FQEEAwIBADANBgkqhkiG9w0BAQwFAAOCAgEAr2rd5hnn
# LZRDGU7L6VCVZKUDkQKL4jaAOxWiUsIWGbZqWl10QzD0m/9gdAmxIR6QFm3FJI9c
# Zohj9E/MffISTEAQiwGf2qnIrvKVG8+dBetJPnSgaFvlVixlHIJ+U9pW2UYXeZJF
# xBA2CFIpF8svpvJ+1Gkkih6PsHMNzBxKq7Kq7aeRYwFkIqgyuH4yKLNncy2RtNwx
# AQv3Rwqm8ddK7VZgxCwIo3tAsLx0J1KH1r6I3TeKiW5niB31yV2g/rarOoDXGpc8
# FzYiQR6sTdWD5jw4vU8w6VSp07YEwzJ2YbuwGMUrGLPAgNW3lbBeUU0i/OxYqujY
# lLSlLu2S3ucYfCFX3VVj979tzR/SpncocMfiWzpbCNJbTsgAlrPhgzavhgplXHT2
# 6ux6anSg8Evu75SjrFDyh+3XOjCDyft9V77l4/hByuVkrrOj7FjshZrM77nq81YY
# uVxzmq/FdxeDWds3GhhyVKVB0rYjdaNDmuV3fJZ5t0GNv+zcgKCf0Xd1WF81E+Al
# GmcLfc4l+gcK5GEh2NQc5QfGNpn0ltDGFf5Ozdeui53bFv0ExpK91IjmqaOqu/dk
# ODtfzAzQNb50GQOmxapMomE2gj4d8yu8l13bS3g7LfU772Aj6PXsCyM2la+YZr9T
# 03u4aUoqlmZpxJTG9F9urJh4iIAGXKKy7aIwgga6MIIEoqADAgECAhMzAAdgufAz
# AJFY7rPoAAAAB2C5MA0GCSqGSIb3DQEBDAUAMFoxCzAJBgNVBAYTAlVTMR4wHAYD
# VQQKExVNaWNyb3NvZnQgQ29ycG9yYXRpb24xKzApBgNVBAMTIk1pY3Jvc29mdCBJ
# RCBWZXJpZmllZCBDUyBFT0MgQ0EgMDMwHhcNMjYxMDAxMDg1OTUyWhcNMjYxMDA0
# MDg1OTUyWjB8MQswCQYDVQQGEwJVUzEPMA0GA1UECBMGT3JlZ29uMRIwEAYDVQQH
# EwlCZWF2ZXJ0b24xIzAhBgNVBAoTGlB5dGhvbiBTb2Z0d2FyZSBGb3VuZGF0aW9u
# MSMwIQYDVQQDExpQeXRob24gU29mdHdhcmUgRm91bmRhdGlvbjCCAaIwDQYJKoZI
# hvcNAQEBBQADggGPADCCAYoCggGBAK2tzroT7VwKHyNJx22Yxp5LYBNqAXPrbdzh
# oAHMBNTvwd6Xnz+Nw8mXhAkhf+UzrhSRG8TRk8en62B3cqhFOZ4TwWaV9kQZu3pt
# KPgnoO6QREPqT7N22fNg+mbUKfX39t29aWyhR/ufsQW6BNE6ckXrpc0XWGTT1cnM
# SsdhAyz0TbGcHShxyQfehBMhcWOdSnHUYSyHmcW3WsgW6QtEe7ltTsgN7dBMHvIZ
# a5vzRr3+bVpqqKPRwnGJIwSKqLb0scIdPmjGRFvPjQ+pE1xfqW+Jl1LJqH08b37L
# QkArpBlN/jzg2rEsoASW01xvzEy1+ZX0gR73Zw4FNK851SYO8USC/G1wgr60jILg
# jIAKXVbyWstmwTnq+ITnHG4CumgLF2K5qLYxheKqO3e8L28dyHp65AkFOoj/5sU/
# kQhDNkV3oJlSDTBD4Gz2O7d2z1OZwbrbiwarJ1lm0PoT/ibt6wsvpPwf34LYtK0H
# Ty/2MQVhAGjBTvVBKIIJf+b6gp1KcwIDAQABo4IB1TCCAdEwDAYDVR0TAQH/BAIw
# ADAOBgNVHQ8BAf8EBAMCB4AwPAYDVR0lBDUwMwYKKwYBBAGCN2EBAAYIKwYBBQUH
# AwMGGysGAQQBgjdhgqKNuwqmkohkgZH0oEWCk/3hbzAdBgNVHQ4EFgQUX6G/pE0j
# jKa8Af2rdMlrsQZGLMcwHwYDVR0jBBgwFoAUa16lNMMFxWJKIVqOq3NgYtSsY4Uw
# ZwYDVR0fBGAwXjBcoFqgWIZWaHR0cDovL3d3dy5taWNyb3NvZnQuY29tL3BraW9w
# cy9jcmwvTWljcm9zb2Z0JTIwSUQlMjBWZXJpZmllZCUyMENTJTIwRU9DJTIwQ0El
# MjAwMy5jcmwwdAYIKwYBBQUHAQEEaDBmMGQGCCsGAQUFBzAChlhodHRwOi8vd3d3
# Lm1pY3Jvc29mdC5jb20vcGtpb3BzL2NlcnRzL01pY3Jvc29mdCUyMElEJTIwVmVy
# aWZpZWQlMjBDUyUyMEVPQyUyMENBJTIwMDMuY3J0MFQGA1UdIARNMEswSQYEVR0g
# ADBBMD8GCCsGAQUFBwIBFjNodHRwOi8vd3d3Lm1pY3Jvc29mdC5jb20vcGtpb3Bz
# L0RvY3MvUmVwb3NpdG9yeS5odG0wDQYJKoZIhvcNAQEMBQADggIBAGLpxNUT/Agq
# AP57QRJA38FuGIdT1kzYpQdPQq1AOT1MRh8Bn+BT+BXqU3ovL9L51OQd5INMWi3y
# BQeSBhO1WEd72Ypo0H+wObp19AnDSEwSTti5QEOZdVcTxrzwys/8gRojsKkO8Gci
# Wn8abScHlS2c2x10QUmp7g73uyN1P3WhzqwQZy2Hm5OqS7qWYkpkX0YDtfMLy7H7
# IwDdQNijADZ7zDof0LSG1TshIB3GjWA407Jg80tHqhHpJ1XsSZJsFifztiRwurjH
# kfjWXfTtqs22CDuzyZSV1LAgasGD+OcOhJwlUaJWZjG27Lgk8FQPCGLGWUwSp8rR
# kziBpR5Ghxo70tNafe0+zjmJYS0Mx52tH6JfHJX4+gaRXbVjoKsDUrcxsSCXdiD1
# wCFnsyYZhM7+EpplYgqZ/aeLo/6y7pQ56eGkRItYkpqpQ8aPiZQVnW9Z0Fg/htzO
# XGPbWzDlGUTGf+OclEgMzbZQ73Pfe20XjJLR5UAnXZ85X/7hDuzSdl3CVcsD0Xlq
# Pq531gwiqpM5rin8uD+Vd/gOrDfUie8TnryUIONxN8T8uVzp6++ZkEEwWFOSYaCh
# q2//+17DqW051pdbWsEInNrazbM8nFNMAbdvHTdjKggK4gf8PnTAYoujMWNOdCLV
# vjuUtx7q8jB4DKP6LgQpgqQ5XEXIQ78QMIIHKDCCBRCgAwIBAgITMwAAABUFPm4Z
# jpMp2QAAAAAAFTANBgkqhkiG9w0BAQwFADBjMQswCQYDVQQGEwJVUzEeMBwGA1UE
# ChMVTWljcm9zb2Z0IENvcnBvcmF0aW9uMTQwMgYDVQQDEytNaWNyb3NvZnQgSUQg
# VmVyaWZpZWQgQ29kZSBTaWduaW5nIFBDQSAyMDIxMB4XDTI2MDMyNjE4MTEyOFoX
# DTMxMDMyNjE4MTEyOFowWjELMAkGA1UEBhMCVVMxHjAcBgNVBAoTFU1pY3Jvc29m
# dCBDb3Jwb3JhdGlvbjErMCkGA1UEAxMiTWljcm9zb2Z0IElEIFZlcmlmaWVkIENT
# IEVPQyBDQSAwMzCCAiIwDQYJKoZIhvcNAQEBBQADggIPADCCAgoCggIBAOD0yz0C
# qi8Ocx4+8w574rJuEJ3z6WiTNg5GVLeQFVex55xvIbAFyx6eWblsu0wY+OIgUvMF
# AX6CGVVX9Tb2rkZx14QQEIdNMaEvaSgistzhSuWIxFxu/2Y4y1H+Xv/ECa/QXHgE
# kefV0e3ft++sGpeYqMp8Z/kOnI7/6GdXtMSt4y1LX2I75uNn/0eemDc8KTR7thJt
# FMWTH3sVnBFakLizc16lF9FdCH9YwCPsmaxh5VmiGLhMXnJbYkyslmrAdzLMlli0
# PYeWejlkQmR2JlwRrEc6hubA7TpnUn1zbemz08YiEZqrWwosQDP0OhzmsuRhYa14
# OuxwqECnaQhz+hiUf0iPoGQ6qqBYg0SQS0Lxk0bUxqT6HejrlqPSJAqZ3Fbshloc
# 7ly7KgyL4q1h9d4giDexUhtLYQvyRS2wMZ0So2oCr+KypOLWNeot7qIqnWeLVI92
# 89b0bTcJOxgXrxv/K4hBHBt2gEJd6Yw0kJLR2isJFjhvZYADLieDtIA1wSCsGBl/
# nfn5B8tTmEbOsqMilsxptq5ZvkUpZQqQyw9xcWRdFY7iego+bgpaUXKmo6lsn8o4
# 1VF4iXEdBF6AA4HMiFEHuCv0gNDWxzYyA6BD7FUZbiirgcPSZ8CLCLIuyRmuRpDs
# mhqdiME1xH1FLbpjEBVtwG0uK0VPMIgSDll1AgMBAAGjggHcMIIB2DAOBgNVHQ8B
# Af8EBAMCAYYwEAYJKwYBBAGCNxUBBAMCAQAwHQYDVR0OBBYEFGtepTTDBcViSiFa
# jqtzYGLUrGOFMFQGA1UdIARNMEswSQYEVR0gADBBMD8GCCsGAQUFBwIBFjNodHRw
# Oi8vd3d3Lm1pY3Jvc29mdC5jb20vcGtpb3BzL0RvY3MvUmVwb3NpdG9yeS5odG0w
# GQYJKwYBBAGCNxQCBAweCgBTAHUAYgBDAEEwEgYDVR0TAQH/BAgwBgEB/wIBADAf
# BgNVHSMEGDAWgBTZQSmwDw9jbO9p1/XNKZ6kSGow5jBwBgNVHR8EaTBnMGWgY6Bh
# hl9odHRwOi8vd3d3Lm1pY3Jvc29mdC5jb20vcGtpb3BzL2NybC9NaWNyb3NvZnQl
# MjBJRCUyMFZlcmlmaWVkJTIwQ29kZSUyMFNpZ25pbmclMjBQQ0ElMjAyMDIxLmNy
# bDB9BggrBgEFBQcBAQRxMG8wbQYIKwYBBQUHMAKGYWh0dHA6Ly93d3cubWljcm9z
# b2Z0LmNvbS9wa2lvcHMvY2VydHMvTWljcm9zb2Z0JTIwSUQlMjBWZXJpZmllZCUy
# MENvZGUlMjBTaWduaW5nJTIwUENBJTIwMjAyMS5jcnQwDQYJKoZIhvcNAQEMBQAD
# ggIBAF1uIjzPBctfyCUkSH/xDbZQwJSFYE7jpn0U+HA5HeZ2WpFUuRg6if8xzNTC
# uMOHHdf31I8fk9J+WQahO+c71lYczlgVVik7s1i4H6Z9VIYAZnCIY4BJaTSLYHu+
# f2cSUkmaiJfG6B8flh0GytSBO3QAU1eTOapOCT5LUfFvW7/QcKoQdVk+TYD/p4ld
# hu2lEzkVzPTSOKxSX0FFmBJ5s4NXzlsHM696rILd/Q+ccLFEk2ExvzE/+wH9Ujul
# /auF5JXvOpRK/y+f98gxuVd5pUiWmqirxI/0EkyMT8KhVcnGeRlBEzUVruQ33LO2
# 9F46HFKA+ClnH9eX+OTDIQVUlMF8GnexOB8hz+maq/Z6G1qQvYASPvwSY49CiHEl
# PfDJf4/vwYDbm0ukC/OPdEwwd3zPXxm65WL7rQwDMak4BIfUvw2Wvd9lFmdA76nL
# J7YMK9iYdoh91SBgmqfuejHEZW/z35FoROHW2AIO/A2kUJIbu+XkDhqSj7Z/HjT2
# v1NaNcLs6J/UhDlknMHhF/wa8GIdiO8yYemV52nUUZEt1JEVWkLf84qlljpq8ipm
# nv7yk/9ZA/3TcN2Cu8BPpbjE84HFc9ri0aSw3dK6olqIVgdI3J4G5+fyKx66Nbgh
# sFJscPgE+psXepn7ucb13938bb8vHiQf1wKYF+axl1KQea6QMIIHnjCCBYagAwIB
# AgITMwAAAAeHozSje6WOHAAAAAAABzANBgkqhkiG9w0BAQwFADB3MQswCQYDVQQG
# EwJVUzEeMBwGA1UEChMVTWljcm9zb2Z0IENvcnBvcmF0aW9uMUgwRgYDVQQDEz9N
# aWNyb3NvZnQgSWRlbnRpdHkgVmVyaWZpY2F0aW9uIFJvb3QgQ2VydGlmaWNhdGUg
# QXV0aG9yaXR5IDIwMjAwHhcNMjEwNDAxMjAwNTIwWhcNMzYwNDAxMjAxNTIwWjBj
# MQswCQYDVQQGEwJVUzEeMBwGA1UEChMVTWljcm9zb2Z0IENvcnBvcmF0aW9uMTQw
# MgYDVQQDEytNaWNyb3NvZnQgSUQgVmVyaWZpZWQgQ29kZSBTaWduaW5nIFBDQSAy
# MDIxMIICIjANBgkqhkiG9w0BAQEFAAOCAg8AMIICCgKCAgEAsvDArxmIKOLdVHpM
# SWxpCFUJtFL/ekr4weslKPdnF3cpTeuV8veqtmKVgok2rO0D05BpyvUDCg1wdsoE
# tuxACEGcgHfjPF/nZsOkg7c0mV8hpMT/GvB4uhDvWXMIeQPsDgCzUGzTvoi76YDp
# xDOxhgf8JuXWJzBDoLrmtThX01CE1TCCvH2sZD/+Hz3RDwl2MsvDSdX5rJDYVuR3
# bjaj2QfzZFmwfccTKqMAHlrz4B7ac8g9zyxlTpkTuJGtFnLBGasoOnn5NyYlf0xF
# 9/bjVRo4Gzg2Yc7KR7yhTVNiuTGH5h4eB9ajm1OCShIyhrKqgOkc4smz6obxO+Hx
# KeJ9bYmPf6KLXVNLz8UaeARo0BatvJ82sLr2gqlFBdj1sYfqOf00Qm/3B4XGFPDK
# /H04kteZEZsBRc3VT2d/iVd7OTLpSH9yCORV3oIZQB/Qr4nD4YT/lWkhVtw2v2s0
# TnRJubL/hFMIQa86rcaGMhNsJrhysLNNMeBhiMezU1s5zpusf54qlYu2v5sZ5zL0
# KvBDLHtL8F9gn6jOy3v7Jm0bbBHjrW5yQW7S36ALAt03QDpwW1JG1Hxu/FUXJbBO
# 2AwwVG4Fre+ZQ5Od8ouwt59FpBxVOBGfN4vN2m3fZx1gqn52GvaiBz6ozorgIEjn
# +PhUXILhAV5Q/ZgCJ0u2+ldFGjcCAwEAAaOCAjUwggIxMA4GA1UdDwEB/wQEAwIB
# hjAQBgkrBgEEAYI3FQEEAwIBADAdBgNVHQ4EFgQU2UEpsA8PY2zvadf1zSmepEhq
# MOYwVAYDVR0gBE0wSzBJBgRVHSAAMEEwPwYIKwYBBQUHAgEWM2h0dHA6Ly93d3cu
# bWljcm9zb2Z0LmNvbS9wa2lvcHMvRG9jcy9SZXBvc2l0b3J5Lmh0bTAZBgkrBgEE
# AYI3FAIEDB4KAFMAdQBiAEMAQTAPBgNVHRMBAf8EBTADAQH/MB8GA1UdIwQYMBaA
# FMh+0mqFKhvKGZgEByfPUBBPaKiiMIGEBgNVHR8EfTB7MHmgd6B1hnNodHRwOi8v
# d3d3Lm1pY3Jvc29mdC5jb20vcGtpb3BzL2NybC9NaWNyb3NvZnQlMjBJZGVudGl0
# eSUyMFZlcmlmaWNhdGlvbiUyMFJvb3QlMjBDZXJ0aWZpY2F0ZSUyMEF1dGhvcml0
# eSUyMDIwMjAuY3JsMIHDBggrBgEFBQcBAQSBtjCBszCBgQYIKwYBBQUHMAKGdWh0
# dHA6Ly93d3cubWljcm9zb2Z0LmNvbS9wa2lvcHMvY2VydHMvTWljcm9zb2Z0JTIw
# SWRlbnRpdHklMjBWZXJpZmljYXRpb24lMjBSb290JTIwQ2VydGlmaWNhdGUlMjBB
# dXRob3JpdHklMjAyMDIwLmNydDAtBggrBgEFBQcwAYYhaHR0cDovL29uZW9jc3Au
# bWljcm9zb2Z0LmNvbS9vY3NwMA0GCSqGSIb3DQEBDAUAA4ICAQB/JSqe/tSr6t1m
# CttXI0y6XmyQ41uGWzl9xw+WYhvOL47BV09Dgfnm/tU4ieeZ7NAR5bguorTCNr58
# HOcA1tcsHQqt0wJsdClsu8bpQD9e/al+lUgTUJEV80Xhco7xdgRrehbyhUf4pkeA
# hBEjABvIUpD2LKPho5Z4DPCT5/0TlK02nlPwUbv9URREhVYCtsDM+31OFU3fDV8B
# mQXv5hT2RurVsJHZgP4y26dJDVF+3pcbtvh7R6NEDuYHYihfmE2HdQRq5jRvLE1E
# b59PYwISFCX2DaLZ+zpU4bX0I16ntKq4poGOFaaKtjIA1vRElItaOKcwtc04CBrX
# SfyL2Op6mvNIxTk4OaswIkTXbFL81ZKGD+24uMCwo/pLNhn7VHLfnxlMVzHQVL+b
# Ha9KhTyzwdG/L6uderJQn0cGpLQMStUuNDArxW2wF16QGZ1NtBWgKA8Kqv48M8Hf
# FqNifN6+zt6J0GwzvU8g0rYGgTZR8zDEIJfeZxwWDHpSxB5FJ1VVU1LIAtB7o9PX
# bjXzGifaIMYTzU4YKt4vMNwwBmetQDHhdAtTPplOXrnI9SI6HeTtjDD3iUN/7ygb
# ahmYOHk7VB7fwT4ze+ErCbMh6gHV1UuXPiLciloNxH6K4aMfZN1oLVk6YFeIJEok
# uPgNPa6EnTiOL60cPqfny+Fq8UiuZzGCGuwwghroAgEBMHEwWjELMAkGA1UEBhMC
# VVMxHjAcBgNVBAoTFU1pY3Jvc29mdCBDb3Jwb3JhdGlvbjErMCkGA1UEAxMiTWlj
# cm9zb2Z0IElEIFZlcmlmaWVkIENTIEVPQyBDQSAwMwITMwAHYLnwMwCRWO6z6AAA
# AAdguTANBglghkgBZQMEAgEFAKCBuDAZBgkqhkiG9w0BCQMxDAYKKwYBBAGCNwIB
# BDAcBgorBgEEAYI3AgELMQ4wDAYKKwYBBAGCNwIBFTAvBgkqhkiG9w0BCQQxIgQg
# Kld7dFLdvZygPQIm94QeWCWq09RhnYWpKs5R8/oLpjgwTAYKKwYBBAGCNwIBDDE+
# MDygNoA0AFAAeQB0AGgAbwBuACAAMwAuADEANQAuADAAcgBjADMAIAAoADgAYQA4
# AGUAYgAwAGIAKaECgAAwDQYJKoZIhvcNAQEBBQAEggGAJQwRxzcwPQPdlkdhSFXO
# MV46At+2FpehWNsJfy2IlrTuNp0QR2AzRJ9YlKYtDsBOgRjrX+cgHVZYcLmhyVML
# N0DZJRXxtj31H59WdLRxSmLS36AMbRUZ7UOTx2cKEdaokhxOgDIycw9A1f+Kl++1
# hs263dcZoJqV8m+1qXZEo4pl/gruOWTbq1B0hzOhJ/fv9zsXa7ISQs5bV7Ve1VF7
# IlHcSLG4NgA3YT9VUY1dL8jOdu74vy6V+HE//8sGAHjMnIQUXnlRI8xLMcoQf0+M
# LSkMHjhxadGDtJjiirv4K6j078kP0ZBqEFNWiQ88GvtEfmpRKZq19HowzvpyuIEj
# GywZh08OrSo+vcQoyXbt8pZxyvve9tdHZvMKOWvQNmuJ/HlIFrJrvSJC4BAdU+eh
# KpR37cucAjprzotOcsmsVSvmUYeFKjs8DHcvNX6j949GkgsTFJ8IyCTUuuz+YKho
# ySF3wC3gqgOaZk2mdBwbPbyTORXvxfsPTcw8Be/z16LOoYIYETCCGA0GCisGAQQB
# gjcDAwExghf9MIIX+QYJKoZIhvcNAQcCoIIX6jCCF+YCAQMxDzANBglghkgBZQME
# AgEFADCCAWIGCyqGSIb3DQEJEAEEoIIBUQSCAU0wggFJAgEBBgorBgEEAYRZCgMB
# MDEwDQYJYIZIAWUDBAIBBQAEIHlkZH8dgLg582n2mbn3iKfynV3nwJYTNNoTiqQJ
# b/RpAgZqqUs2rjIYEzIwMjYxMDAyMTk1ODA0LjI2OVowBIACAfSggeGkgd4wgdsx
# CzAJBgNVBAYTAlVTMRMwEQYDVQQIEwpXYXNoaW5ndG9uMRAwDgYDVQQHEwdSZWRt
# b25kMR4wHAYDVQQKExVNaWNyb3NvZnQgQ29ycG9yYXRpb24xJTAjBgNVBAsTHE1p
# Y3Jvc29mdCBBbWVyaWNhIE9wZXJhdGlvbnMxJzAlBgNVBAsTHm5TaGllbGQgVFNT
# IEVTTjo3QTAwLTA1RTAtRDk0NzE1MDMGA1UEAxMsTWljcm9zb2Z0IFB1YmxpYyBS
# U0EgVGltZSBTdGFtcGluZyBBdXRob3JpdHmggg8hMIIHgjCCBWqgAwIBAgITMwAA
# AAXlzw//Zi7JhwAAAAAABTANBgkqhkiG9w0BAQwFADB3MQswCQYDVQQGEwJVUzEe
# MBwGA1UEChMVTWljcm9zb2Z0IENvcnBvcmF0aW9uMUgwRgYDVQQDEz9NaWNyb3Nv
# ZnQgSWRlbnRpdHkgVmVyaWZpY2F0aW9uIFJvb3QgQ2VydGlmaWNhdGUgQXV0aG9y
# aXR5IDIwMjAwHhcNMjAxMTE5MjAzMjMxWhcNMzUxMTE5MjA0MjMxWjBhMQswCQYD
# VQQGEwJVUzEeMBwGA1UEChMVTWljcm9zb2Z0IENvcnBvcmF0aW9uMTIwMAYDVQQD
# EylNaWNyb3NvZnQgUHVibGljIFJTQSBUaW1lc3RhbXBpbmcgQ0EgMjAyMDCCAiIw
# DQYJKoZIhvcNAQEBBQADggIPADCCAgoCggIBAJ5851Jj/eDFnwV9Y7UGIqMcHtfn
# lzPREwW9ZUZHd5HBXXBvf7KrQ5cMSqFSHGqg2/qJhYqOQxwuEQXG8kB41wsDJP5d
# 0zmLYKAY8Zxv3lYkuLDsfMuIEqvGYOPURAH+Ybl4SJEESnt0MbPEoKdNihwM5xGv
# 0rGofJ1qOYSTNcc55EbBT7uq3wx3mXhtVmtcCEr5ZKTkKKE1CxZvNPWdGWJUPC6e
# 4uRfWHIhZcgCsJ+sozf5EeH5KrlFnxpjKKTavwfFP6XaGZGWUG8TZaiTogRoAlqc
# evbiqioUz1Yt4FRK53P6ovnUfANjIgM9JDdJ4e0qiDRm5sOTiEQtBLGd9Vhd1Mad
# xoGcHrRCsS5rO9yhv2fjJHrmlQ0EIXmp4DhDBieKUGR+eZ4CNE3ctW4uvSDQVeSp
# 9h1SaPV8UWEfyTxgGjOsRpeexIveR1MPTVf7gt8hY64XNPO6iyUGsEgt8c2PxF87
# E+CO7A28TpjNq5eLiiunhKbq0XbjkNoU5JhtYUrlmAbpxRjb9tSreDdtACpm3rkp
# xp7AQndnI0Shu/fk1/rE3oWsDqMX3jjv40e8KN5YsJBnczyWB4JyeeFMW3JBfdeA
# KhzohFe8U5w9WuvcP1E8cIxLoKSDzCCBOu0hWdjzKNu8Y5SwB1lt5dQhABYyzR3d
# xEO/T1K/BVF3rV69AgMBAAGjggIbMIICFzAOBgNVHQ8BAf8EBAMCAYYwEAYJKwYB
# BAGCNxUBBAMCAQAwHQYDVR0OBBYEFGtpKDo1L0hjQM972K9J6T7ZPdshMFQGA1Ud
# IARNMEswSQYEVR0gADBBMD8GCCsGAQUFBwIBFjNodHRwOi8vd3d3Lm1pY3Jvc29m
# dC5jb20vcGtpb3BzL0RvY3MvUmVwb3NpdG9yeS5odG0wEwYDVR0lBAwwCgYIKwYB
# BQUHAwgwGQYJKwYBBAGCNxQCBAweCgBTAHUAYgBDAEEwDwYDVR0TAQH/BAUwAwEB
# /zAfBgNVHSMEGDAWgBTIftJqhSobyhmYBAcnz1AQT2ioojCBhAYDVR0fBH0wezB5
# oHegdYZzaHR0cDovL3d3dy5taWNyb3NvZnQuY29tL3BraW9wcy9jcmwvTWljcm9z
# b2Z0JTIwSWRlbnRpdHklMjBWZXJpZmljYXRpb24lMjBSb290JTIwQ2VydGlmaWNh
# dGUlMjBBdXRob3JpdHklMjAyMDIwLmNybDCBlAYIKwYBBQUHAQEEgYcwgYQwgYEG
# CCsGAQUFBzAChnVodHRwOi8vd3d3Lm1pY3Jvc29mdC5jb20vcGtpb3BzL2NlcnRz
# L01pY3Jvc29mdCUyMElkZW50aXR5JTIwVmVyaWZpY2F0aW9uJTIwUm9vdCUyMENl
# cnRpZmljYXRlJTIwQXV0aG9yaXR5JTIwMjAyMC5jcnQwDQYJKoZIhvcNAQEMBQAD
# ggIBAF+Idsd+bbVaFXXnTHho+k7h2ESZJRWluLE0Oa/pO+4ge/XEizXvhs0Y7+KV
# Yyb4nHlugBesnFqBGEdC2IWmtKMyS1OWIviwpnK3aL5JedwzbeBF7POyg6IGG/Xh
# hJ3UqWeWTO+Czb1c2NP5zyEh89F72u9UIw+IfvM9lzDmc2O2END7MPnrcjWdQnrL
# n1Ntday7JSyrDvBdmgbNnCKNZPmhzoa8PccOiQljjTW6GePe5sGFuRHzdFt8y+bN
# 2neF7Zu8hTO1I64XNGqst8S+w+RUdie8fXC1jKu3m9KGIqF4aldrYBamyh3g4nJP
# j/LR2CBaLyD+2BuGZCVmoNR/dSpRCxlot0i79dKOChmoONqbMI8m04uLaEHAv4qw
# KHQ1vBzbV/nG89LDKbRSSvijmwJwxRxLLpMQ/u4xXxFfR4f/gksSkbJp7oqLwliD
# m/h+w0aJ/U5ccnYhYb7vPKNMN+SZDWycU5ODIRfyoGl59BsXR/HpRGtiJquOYGmv
# A/pk5vC1lcnbeMrcWD/26ozePQ/TWfNXKBOmkFpvPE8CH+EeGGWzqTCjdAsno2jz
# TeNSxlx3glDGJgcdz5D/AAxw9Sdgq/+rY7jjgs7X6fqPTXPmaCAJKVHAP19oEjJI
# BwD1LyHbaEgBxFCogYSOiUIr0Xqcr1nJfiWG2GwYe6ZoAF1bMIIHlzCCBX+gAwIB
# AgITMwAAAFhlzes/odf80gAAAAAAWDANBgkqhkiG9w0BAQwFADBhMQswCQYDVQQG
# EwJVUzEeMBwGA1UEChMVTWljcm9zb2Z0IENvcnBvcmF0aW9uMTIwMAYDVQQDEylN
# aWNyb3NvZnQgUHVibGljIFJTQSBUaW1lc3RhbXBpbmcgQ0EgMjAyMDAeFw0yNTEw
# MjMyMDQ2NTVaFw0yNjEwMjIyMDQ2NTVaMIHbMQswCQYDVQQGEwJVUzETMBEGA1UE
# CBMKV2FzaGluZ3RvbjEQMA4GA1UEBxMHUmVkbW9uZDEeMBwGA1UEChMVTWljcm9z
# b2Z0IENvcnBvcmF0aW9uMSUwIwYDVQQLExxNaWNyb3NvZnQgQW1lcmljYSBPcGVy
# YXRpb25zMScwJQYDVQQLEx5uU2hpZWxkIFRTUyBFU046N0EwMC0wNUUwLUQ5NDcx
# NTAzBgNVBAMTLE1pY3Jvc29mdCBQdWJsaWMgUlNBIFRpbWUgU3RhbXBpbmcgQXV0
# aG9yaXR5MIICIjANBgkqhkiG9w0BAQEFAAOCAg8AMIICCgKCAgEAnXg0pHaQ7PVA
# lln+HZZrJFcLoKbekhW1yL+QNBUgFFUsjZIKaqqN4oIJsJM3ps0rJNSO7ndCNRuZ
# DX2Wgur3Ak77eXrloBXqZmO6ZVXeDNRCLldW4A0/NfjzJ7XXkdEhjr81ghXEpR7z
# C+wbaNN+sPSxzLAZBeibDFP7Xws5wX0ZtIsN1a2+Xq5bvWp3kRMytwskTjunRgeL
# ZL/tBp237JVdRPFAQ9jYRKpCqUBo/v1xjBLRCV3PalKjnGfb3MN4U7jVyqifFHSh
# cnW5CERRoBmUa6sygDzFSr8e3g93TPNLFUivUE0GmLfbX5ceD1Gt1FcZ6x/JLVAT
# zk5+BWHbMxwJIVkVPTqSSMjQ6KTKdcnq3pH0c4AFJp/glvcpq0U9fzZIjJGGvdpi
# shlRl77RQtUhSjxHvCn3LC/xqQQwOHSQDsGh6NX2D0RfsSyEtTAByAae+2w1HByT
# DTcmlTNLEuQLeCj1gNBdIWj0WOYyDtjjQ/8iTWY6ey1vb9qHljIj5HgIndT5P9MY
# k2Vg2e7hKUZNBNbA/hsgBsuoZ+IX89WvjEN9abF91S4OJVuinmKsLO/MLbnl7iku
# D0dN6oA0YewyDQncs12sM9HOtu72QA/TZlefvW8r9xtMXAYoQlcGjsk8W4Uc7cfq
# VqbIPjdoc8ZxBzLcXcVyP4p5cyLwvkMCAwEAAaOCAcswggHHMB0GA1UdDgQWBBRy
# jU3Fer4VxXJ+hjPcRJnxnRIJsDAfBgNVHSMEGDAWgBRraSg6NS9IY0DPe9ivSek+
# 2T3bITBsBgNVHR8EZTBjMGGgX6BdhltodHRwOi8vd3d3Lm1pY3Jvc29mdC5jb20v
# cGtpb3BzL2NybC9NaWNyb3NvZnQlMjBQdWJsaWMlMjBSU0ElMjBUaW1lc3RhbXBp
# bmclMjBDQSUyMDIwMjAuY3JsMHkGCCsGAQUFBwEBBG0wazBpBggrBgEFBQcwAoZd
# aHR0cDovL3d3dy5taWNyb3NvZnQuY29tL3BraW9wcy9jZXJ0cy9NaWNyb3NvZnQl
# MjBQdWJsaWMlMjBSU0ElMjBUaW1lc3RhbXBpbmclMjBDQSUyMDIwMjAuY3J0MAwG
# A1UdEwEB/wQCMAAwFgYDVR0lAQH/BAwwCgYIKwYBBQUHAwgwDgYDVR0PAQH/BAQD
# AgeAMGYGA1UdIARfMF0wUQYMKwYBBAGCN0yDfQEBMEEwPwYIKwYBBQUHAgEWM2h0
# dHA6Ly93d3cubWljcm9zb2Z0LmNvbS9wa2lvcHMvRG9jcy9SZXBvc2l0b3J5Lmh0
# bTAIBgZngQwBBAIwDQYJKoZIhvcNAQEMBQADggIBAHvrxIiVF1iHcXvxrJTCD8eO
# tbPUbK9x+Lz70iYehh+G0UoOMcMf04QD6tQPTeZ5HhGETkcn0raDJ5NpfbRBuKEH
# 31rxbZK97o12KRDNJ3Nu4ePaUIpH/TcWz8PLVOCECywSxbEgEG20kyydGc46c591
# tXzpfkJDckjoYrypaerdeQLRQH9LaoTYZfdAzMo+Dy0O1DzFJkF5YnsmAM8lt9r1
# NtXdFjdbFMCbV5dau64mV22s186A8Umi+l239+Ue0cbJQIykWhIlhhWhxQgoksqH
# z7kp2GFZAAeySTmIOQOWyXOA8JA8TISJyn3JDOgStv583P3V0QSALT6JXDCW26FV
# 208VGJMzkv0S22iOTZJ/oamTpk8RzD8oWT8pfbe1q/k/bxPiXYRbzps96a5YOko7
# n0Vdo61DOJhL/mhk01Y348gq6vhG/VTcdGHh1rCkwOM05B35AZZq9AtPpfRzJinr
# HzzGRx+r6fD3ccYMPMMX/Nwd2irzrph172fQcSf1fMwvwIhmfH4GWJJ+mf1HA6uX
# oAOVByckguXvlj8gPi7T2ES6RU8+QssfqTNTJKjsBheWKWv2W4ESVen2L7lCz7i7
# 9FhA+0kp0yXJnYwdzWS0ovTINULINmzVyMcSUm5WuVf8YZ33cAud2Opr6N1+RuLZ
# DavDvjiehlI5dH+GEy56MYIHQzCCBz8CAQEweDBhMQswCQYDVQQGEwJVUzEeMBwG
# A1UEChMVTWljcm9zb2Z0IENvcnBvcmF0aW9uMTIwMAYDVQQDEylNaWNyb3NvZnQg
# UHVibGljIFJTQSBUaW1lc3RhbXBpbmcgQ0EgMjAyMAITMwAAAFhlzes/odf80gAA
# AAAAWDANBglghkgBZQMEAgEFAKCCBJwwEQYLKoZIhvcNAQkQAg8xAgUAMBoGCSqG
# SIb3DQEJAzENBgsqhkiG9w0BCRABBDAcBgkqhkiG9w0BCQUxDxcNMjYxMDAyMTk1
# ODA0WjAvBgkqhkiG9w0BCQQxIgQgW/Z/4bLSSMXuZq3fcZiA8MDAdUfzT7HGTI7O
# +w+VeU4wgbkGCyqGSIb3DQEJEAIvMYGpMIGmMIGjMIGgBCDFIlS7sgfQ+wAo1cWb
# Wz+WN69VBds58hbran919aLocTB8MGWkYzBhMQswCQYDVQQGEwJVUzEeMBwGA1UE
# ChMVTWljcm9zb2Z0IENvcnBvcmF0aW9uMTIwMAYDVQQDEylNaWNyb3NvZnQgUHVi
# bGljIFJTQSBUaW1lc3RhbXBpbmcgQ0EgMjAyMAITMwAAAFhlzes/odf80gAAAAAA
# WDCCA14GCyqGSIb3DQEJEAISMYIDTTCCA0mhggNFMIIDQTCCAikCAQEwggEJoYHh
# pIHeMIHbMQswCQYDVQQGEwJVUzETMBEGA1UECBMKV2FzaGluZ3RvbjEQMA4GA1UE
# BxMHUmVkbW9uZDEeMBwGA1UEChMVTWljcm9zb2Z0IENvcnBvcmF0aW9uMSUwIwYD
# VQQLExxNaWNyb3NvZnQgQW1lcmljYSBPcGVyYXRpb25zMScwJQYDVQQLEx5uU2hp
# ZWxkIFRTUyBFU046N0EwMC0wNUUwLUQ5NDcxNTAzBgNVBAMTLE1pY3Jvc29mdCBQ
# dWJsaWMgUlNBIFRpbWUgU3RhbXBpbmcgQXV0aG9yaXR5oiMKAQEwBwYFKw4DAhoD
# FQCdZHkb26ercF2O62vCdZUfUSvEXKBnMGWkYzBhMQswCQYDVQQGEwJVUzEeMBwG
# A1UEChMVTWljcm9zb2Z0IENvcnBvcmF0aW9uMTIwMAYDVQQDEylNaWNyb3NvZnQg
# UHVibGljIFJTQSBUaW1lc3RhbXBpbmcgQ0EgMjAyMDANBgkqhkiG9w0BAQsFAAIF
# AO5qMxAwIhgPMjAyNjEwMDIxMzQxMzZaGA8yMDI2MTAwMzEzNDEzNlowdDA6Bgor
# BgEEAYRZCgQBMSwwKjAKAgUA7mozEAIBADAHAgEAAgIYkzAHAgEAAgIS2zAKAgUA
# 7muEkAIBADA2BgorBgEEAYRZCgQCMSgwJjAMBgorBgEEAYRZCgMCoAowCAIBAAID
# B6EgoQowCAIBAAIDAYagMA0GCSqGSIb3DQEBCwUAA4IBAQAEgellXh/A0YIWcKyZ
# mgkDmYRXjGUHPnd2smx8liWo6EP/6v/KVjgzq4c0HtKOUBAz99rXZDHOtgrQ/Y8D
# 8Oo+z6Sx7fLtcxn3k4UFa1zWnqACZA5ctzbiN7/fY19ZeHoIZYxrHP7bZsBRxoA8
# pbhRLfLYDob/y6eqm6vznuPHJnUR5IRvQGE5A914561SpK9Jzvg4zuXDbrAUpX25
# nk6N1URO6rguPbBk4xin6IKiKGBb5M9jWN83sLG4Zttr16Uf6XSnrxKZ2UXsiXSZ
# Hl7asPTYE5N2kkjXLklDHPasy4PS1H2e3AMCncwH+ZK6kP2kAcGp26BnS0mBG2GF
# y0mhMA0GCSqGSIb3DQEBAQUABIICAJZ7Pj8wvFtUyYCoKz+1NQwhbF98FZAAUYWS
# xFlfrLrqS0CT8QhRBLuK0xibSy50nQeWn8nDuSqn3a1cG2Swi790A3lr7BNFBawd
# KvYYvyBcwa3/th2tDvWwTx2Mtc+lPa4Rdf44+5FtNwG9v4gmbU1YGG2F3sBA43x2
# 3yuhzo/YSzjIHA27VVtH95yfeJGGhEYz/P6odI4ai1s4iVuVGKGcEpYg9EKzerET
# frfQM3cQGEmcyDKvzdIc9KAZrQh5C9nce8eW5vgRKEQqHqB7DyIROCs+mRvbVD14
# 9EaxShlsgMnE6jDVxxjoP5oMFHMhWy4B2ljHaXjvAxQOwIP4OZj/MyknOMjmpOqI
# q94mmgvDqe1hi7fEPknnAXdxe+EKF4Rx7Tw/niW96pcUbEAibvThat81pAr/eBZd
# nu7Dn4NQtA2DdfUykagZ0VwU5pXv/ONxzHXr8sm73MxOwOwVVKsW05LHrRvMtK3k
# TNGUXqJbe6hcMuugZtBNJ7WZ5iMvL6HRz1iw+VP6qJJnA7ClPGGKhoJMMoVMa//e
# poH85HBDG+HliGC6QE0ih+n6gG4k7bznelk0CFTrP+nV4LECCIMXMBg5KnsI37sN
# nrTFrcXk75SBNooxAqqBMziVmnuzRRU9H5Qqcc+YJJQmS0k5WqNG/59bHxkTeyja
# pvQfn+2Z
# SIG # End signature block
