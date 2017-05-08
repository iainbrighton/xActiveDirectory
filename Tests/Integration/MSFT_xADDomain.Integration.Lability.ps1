<#
    .SYNOPSIS
        Creates a virtualised AD controller and Nano Server infrastructure
        for a Hyper-Converged 
#>
configuration MSFT_xADDomain_Lability_Setup
{
    Import-DscResource -ModuleName PSDesiredStateConfiguration;

    node $AllNodes.NodeName
    {

        LocalConfigurationManager
        {
            RebootNodeIfNeeded = $true;
            ConfigurationMode = 'ApplyOnly';
            DebugMode = 'ForceModuleImport';
            # CertificateID = '';
        }

        ## Needs something to satisfy Lability's hunger for a .mof file!
        Script 'Lability'
        {
            GetScript = { return @{ result = $true; } }
            TestScript = { return $true; }
            SetScript = { }
        } #end script
    }

}
