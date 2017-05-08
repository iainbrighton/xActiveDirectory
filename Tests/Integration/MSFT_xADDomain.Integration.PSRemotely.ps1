[CmdletBinding()]
param (
    [Parameter(Mandatory)]
    [System.Collections.Hashtable]
    [Microsoft.PowerShell.DesiredStateConfiguration.ArgumentToConfigurationDataTransformationAttribute()]
    $ConfigurationData
)

Describe "xActiveDirectory\xADDomain_Integration_Test" {

    $adDomain = Get-ADDomain;

    It 'should have "<Property>" value of "<Expected>"' -TestCases @(

        @{ Property = 'NetBIOSName'; Expected = $ConfigurationData.NonNodeData.xActiveDirectory.DomainNetBIOSName; };
        @{ Property = 'DNSRoot'; Expected = $ConfigurationData.NonNodeData.xActiveDirectory.DomainName; };
    
    ) -Test {

        param (
            [System.String] $Property,
            [System.Object] $Expected
        )
        
        $adDomain.$Property | Should Be $Expected;
    }
        
}
