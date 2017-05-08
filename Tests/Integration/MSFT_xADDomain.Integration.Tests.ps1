#requires -RunAsAdministrator
#requires -Version 5
#requires -Modules Lability

## Also requires that Hyper-V role is installed on the host (requires a reboot)

$script:DSCModuleName      = 'xActiveDirectory'
$script:DSCResourceName    = 'MSFT_xADDomain'

#region HEADER
# Integration Test Template Version: 1.1.1
[String] $script:moduleRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
if ( (-not (Test-Path -Path (Join-Path -Path $script:moduleRoot -ChildPath 'DSCResource.Tests'))) -or `
     (-not (Test-Path -Path (Join-Path -Path $script:moduleRoot -ChildPath 'DSCResource.Tests\TestHelper.psm1'))) )
{
    & git @('clone','https://github.com/PowerShell/DscResource.Tests.git',(Join-Path -Path $script:moduleRoot -ChildPath '\DSCResource.Tests\'))
}

Import-Module (Join-Path -Path $script:moduleRoot -ChildPath 'DSCResource.Tests\TestHelper.psm1') -Force
$TestEnvironment = Initialize-TestEnvironment `
    -DSCModuleName $script:DSCModuleName `
    -DSCResourceName $script:DSCResourceName `
    -TestType Integration
#endregion

# Import the common integration test functions
Import-Module -Name ( Join-Path `
    -Path $PSScriptRoot `
    -ChildPath 'IntegrationTestsCommon.psm1' ) `
    -Force

# Import the Lability module and grab a reference
$lability = Import-Module -Name Lability -Force -PassThru

# Using try/finally to always cleanup even if something awful happens.
try
{
    ##########################################################################
    ##       Ensure the Lability environment is deployed and ready
    ##########################################################################
    
    $password = ConvertTo-SecureString -String 'Passw0rd' -AsPlainText -Force
    ## Credential used for DSC compilation
    $credential = New-Object -TypeName PSCredential @('Administrator', $password)
    ## A different credential is required AFTER machine is domain-joined
    $domainCredential = New-Object -TypeName PSCredential -ArgumentList @('~\Administrator', $password)
    
    # Compile the Lability meta/mof as they're host version specific
    $configurationDataPath = Join-Path -Path $PSScriptRoot -ChildPath "$($script:DSCResourceName).Integration.Lability.psd1";
    $configurationData = ConvertTo-ConfigurationData -ConfigurationData $configurationDataPath;
    Clear-ModulePath -Scope CurrentUser -Force -Verbose -ErrorAction SilentlyContinue;

    $invokeDscCompileParams = @{
        Path = Join-Path -Path $PSScriptRoot -ChildPath "$($script:DSCResourceName).Integration.Lability.ps1";
        ConfigurationName = "$($script:DSCResourceName)_Lability_Setup";
        ConfigurationData = $configurationData;
        OutputPath = $env:TEMP;
    }
    [ref] $null = Invoke-DscCompile @invokeDscCompileParams
    
    $startLabConfigurationParams = @{
        ConfigurationData = $configurationData;
        Credential = $credential;
        Path = $env:TEMP;
        IgnorePendingReboot = $true;
    }
    Start-LabConfiguration @startLabConfigurationParams -Verbose -NoSnapshot | Start-VM -Verbose;
    
    ## Wait for the baseline configuration to complete
    $waitLabBaselineParams = @{
        ConfigurationData = ConvertTo-ConfigurationData -ConfigurationData $configurationDataPath;
        Credential = $domainCredential;
        PreferNodeProperty = 'IPAddress'; ## REQUIRES HOST TO HAVE AN IP ASSIGNED TO vSWITCH NIC!!
    }
    Wait-Lab @waitLabBaselineParams -Verbose;

    ##########################################################################
    ##               Compile and deploy the configuration
    ##########################################################################
        
    # Compile the actual integration 
    $configurationDataFilename = "$($script:DSCResourceName).Integration.Config.psd1";
    $configurationDataPath = Join-Path -Path $PSScriptRoot -ChildPath $configurationDataFilename;
    $configurationData = ConvertTo-ConfigurationData -ConfigurationData $configurationDataPath;
    $invokeDscCompileParams = @{
        Path = Join-Path -Path $PSScriptRoot -ChildPath "$($script:DSCResourceName).Integration.Config.ps1";
        ConfigurationName = "$($script:DSCResourceName)_Integration";
        ConfigurationData = $configurationData;
        OutputPath = $env:TEMP;
        Parameters = @{ DomainAdministratorCredential = $credential; SafemodeAdministratorPassword = $credential; }
    }
    ## TODO: Should use Start-DscConfigurationCompilation as there might be more than one configuration?
    Write-Verbose -Message ("Compiling configuration '{0}'" -f $configurationDataPath) -Verbose;
    $integrationMofFiles = Invoke-DscCompile @invokeDscCompileParams;

    ## Retrieve the active session
    $integrationSession = & $lability { Get-PSSession | Where-Object State -eq 'Opened' -ErrorAction Stop }

    ## Create the LabilityCI folder on the test host
    [ref] $null = Invoke-Command -Session $integrationSession -ScriptBlock {
        New-Item -Path "$env:SystemDrive\LabilityCI\" -ItemType Directory -Force;
    }

    ## Copy the module/SUT to the target host!
    $copyItemToSessionParams = @{
        Path = $script:moduleRoot;
        ToSession = $integrationSession;
        Destination = 'C:\Program Files\WindowsPowerShell\Modules\';
        Recurse = $true;
        Force = $true;
        Exclude = '.git';
    }
    Copy-ItemToSession @copyItemToSessionParams -Verbose;
    
    ## Copy mofs to target host
    $integrationMofFiles | Copy-Item -ToSession $integrationSession -Destination "$env:SystemDrive\LabilityCI" -Verbose -Force;

    ## Deploy the AD configuration before we can test...
    Write-Verbose -Message ('Starting configuration deployment') -Verbose
    Invoke-Command -Session $integrationSession {
        Start-DscConfiguration -Path "$env:SystemDrive\LabilityCI" -Wait -Force;
    }

    ## Now wait for the AD deployment to finish...
    $waitLabParams = @{
        ConfigurationData = ConvertTo-ConfigurationData -ConfigurationData $configurationDataPath;
        Credential = $domainCredential;
        PreferNodeProperty = 'IPAddress'; ### << REQUIRES HOST TO HAVE AN IP ASSIGNED TO VIRTUAL SWITCH TO COMMUNICATE WITH VM!
    }
    Wait-Lab @waitLabParams -Verbose;
    
    ##########################################################################
    ##                  Now run the actual integration test
    ##########################################################################

    ## Refresh the session object as there may have been a reboot etc.
    $integrationSession = & $lability { Get-PSSession | Where-Object State -eq 'Opened' -ErrorAction Stop }

    ## Copy the test file(s) to the target host ### << WOULD LIKE TO USE PSREMOTELY HERE, BUT DREDENTIALS!
    $configurationDataPath | Copy-Item -ToSession $integrationSession -Destination "$env:SystemDrive\LabilityCI\Integration.Tests.psd1" -Verbose -Force
    $integrationTestPath = Join-Path -Path $PSScriptRoot -ChildPath "$($script:DSCResourceName).Integration.PSRemotely.ps1"
    $integrationTestPath | Copy-Item -ToSession $integrationSession -Destination "$env:SystemDrive\LabilityCI\Integration.Tests.ps1" -Verbose -Force

    ## Invoke tests
    Invoke-Command -Session $integrationSession -ScriptBlock {
        
        ## Native Pester tests
        Invoke-Pester -Script @{
            Path = "$env:SystemDrive\LabilityCI\Integration.Tests.ps1";
            Parameters = @{
                Configurationdata = "$env:SystemDrive\LabilityCI\Integration.Tests.psd1";
            }
        }
        
        ## Operation Validation tests
        Invoke-OperationValidation -Module OVF.Active.Directory;
    }
    
}
finally
{
    #region FOOTER

    ## TODO: Remove remote sessions
    ## TODO: Remove Lability configuration, revert to snapshot ;)

    Restore-TestEnvironment -TestEnvironment $TestEnvironment;
    #endregion
}
