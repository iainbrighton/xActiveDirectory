configuration MSFT_xADDomain_Integration 
{
    param
    (
        [Parameter(Mandatory = $true)]
        [System.Management.Automation.PSCredential]
        $DomainAdministratorCredential,

        [Parameter(Mandatory = $true)]
        [System.Management.Automation.PSCredential]
        $SafemodeAdministratorPassword,
        
        [Parameter()]
        [System.String]
        $DomainName = 'test.local'
    )

    Import-DscResource -ModuleName xActiveDirectory

    node 'localhost'
    {

        LocalConfigurationManager
        {
            RebootNodeIfNeeded = $true;
            ConfigurationMode = 'ApplyOnly';
            DebugMode = 'ForceModuleImport';
        }

        xADDomain Integration_Test
        {
            DomainName = $ConfigurationData.NonNodeData.xActiveDirectory.DomainName;
            DomainNetBIOSName = $ConfigurationData.NonNodeData.xActiveDirectory.DomainNetBIOSName;
            DomainAdministratorCredential = $DomainAdministratorCredential;
            SafemodeAdministratorPassword = $SafemodeAdministratorPassword;
        }

    }

}
