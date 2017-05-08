<#
    .SYNOPSIS
    Converts a file path into a DSC configuration data hashtable.
#>
function ConvertTo-ConfigurationData
{
    [CmdletBinding()]
    [OutputType([System.Collections.Hashtable])]
    param
    (
        [Parameter(Mandatory = $true)]
        [System.String]
        $ConfigurationData
    )
    process
    {
        $configurationDataContent = Get-Content -Path $ConfigurationData -Raw
        $configurationDataScriptBlock = [System.Management.Automation.ScriptBlock]::Create($configurationDataContent)
        & $configurationDataScriptBlock
    }
}

<#
    .SYNOPSIS
    Compiles a DSC configuration
#>
function Invoke-DscCompile
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true)]
        [System.String]
        $Path,

        [Parameter(Mandatory = $true)]
        [System.String]
        $ConfigurationName,

        [Parameter()]
        [System.Collections.Hashtable]
        $ConfigurationData,

        [Parameter()]
        [System.String]
        $OutputPath = (Get-Location -PSProvider FileSystem).Path,

        [Parameter()]
        [System.Collections.Hashtable]
        $Parameters
    )
    process
    {
        try
        {
            # Dot-source/import the configuration
            . $Path -Verbose -ErrorAction Stop

            if (($PSBoundParameters.ContainsKey('ConfigurationData')) -and
                ($PSBoundParameters.ContainsKey('Parameters')))
            {
                & $ConfigurationName `
                    -OutputPath $OutputPath `
                    -ConfigurationData $configurationData @Parameters
            }
            elseif ($PSBoundParameters.ContainsKey('Parameters'))
            {
                 & $ConfigurationName `
                    -OutputPath $OutputPath @Parameters
            }
            elseif ($PSBoundParameters.ContainsKey('ConfigurationData'))
            {
                & $ConfigurationName `
                     -OutputPath $OutputPath `
                     -ConfigurationData $configurationData
            }
            else
            {
                & $ConfigurationName -OutputPath $OutputPath
            }
        }
        catch
        {
            throw
        }
    } #end process
}

<#
    .SYNOPSIS
    Copies the DSC resource module under test to a remote server/session.
#>
function Copy-ItemToSession
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true)]
        [System.String] $Path,

        [Parameter(Mandatory = $true)]
        [System.String] $Destination,

        [Parameter(Mandatory = $true)]
        [System.Management.Automation.Runspaces.PSSession] $ToSession,

        [Parameter()]
        [System.String[]] $Exclude,

        [Parameter()]
        [System.Management.Automation.SwitchParameter] $Recurse,
        
        [Parameter()]
        [System.Management.Automation.SwitchParameter] $Force
    )
    process
    {
        $null = $PSBoundParameters.Remove('Destination');
        $null = $PSBoundParameters.Remove('ToSession');
        $null = $PSBoundParameters.Remove('Recurse');

        ## If we're copying a directory, make sure the target container exists!
        if (Test-Path -Path $Path -PathType Container)
        {
            $sourcePath = Get-Item -Path $Path;
            $Destination = Join-Path -Path $Destination -ChildPath $sourcePath.Name;
            [ref] $null = Invoke-Command -Session $ToSession -ScriptBlock {
                New-Item -Path $using:Destination -ItemType Directory -Force
            }
        }

        Get-ChildItem @PSBoundParameters -Recurse:$false |
             Copy-Item -ToSession $ToSession -Force:$Force -Recurse:$Recurse -Destination {
                 if ($_.PSIsContainer)
                 {
                     Join-Path -Path $Destination -ChildPath $_.Parent.FullName.Substring($Path.Length)
                 }
                 else
                 {
                     Join-Path -Path $Destination -ChildPath $_.FullName.Substring($Path.Length)
                 }
             }
    }
}

