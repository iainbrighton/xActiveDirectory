@{
    AllNodes = @(

        @{
            NodeName                    = '*';
            Lability_SwitchName         = 'NAT';
            Lability_ProcessorCount     = 2;
            Lability_StartupMemory      = 4GB;
        }
        @{
            NodeName                    = 'DC';
            IPAddress                   = '10.200.0.10';
            PsDscAllowPlainTextPassword = $true;

            Lability_BootOrder          = 10;
            Lability_Media              = '2016_x64_Standard_EN_Eval';
            Lability_CustomBootstrap    = @'

    ## This requires Server 2012 or later
    $features = @(
        'DNS', 'AD-Domain-Services', 'RSAT-AD-PowerShell', 'RSAT-AD-AdminCenter', 'RSAT-ADDS', 'RSAT-AD-Tools',
        'RSAT-Role-Tools', 'RSAT-DNS-Server' )
    Install-WindowsFeature -Name $features -Verbose;
    
    New-NetIPAddress 10.200.0.10 -AddressFamily IPv4 -DefaultGateway 10.200.0.2 -PrefixLength 24 -InterfaceAlias Ethernet;
    Set-DnsClientServerAddress -InterfaceAlias Ethernet -ServerAddresses 127.0.0.1, 8.8.8.8;
    
    ## Add an artificial sleep as DC promotion sometimes failed due to pending feature installations!
    Start-Sleep -Seconds 30;
    
'@
            # Lability_Media              = '2016_x64_Standard_Core_EN_Eval'; ## Requires CredSSP
        }

    ) #end AllNodes

    NonNodeData = @{
        Lability = @{

            EnvironmentPrefix = 'CI-';

            ## TODO: Ensure Lability ignores host DSC resources when an empty array is specified
            DSCResource = @( )

            Module = @(

                @{ Name = 'GitHubRepository'; RequiredVersion = '1.2.0'; }
                @{ Name = 'Pester'; RequiredVersion = '4.0.3'; }
                @{ Name = 'PoshSpec'; RequiredVersion = '2.1.16'; }
                @{ Name = 'OperationValidation'; RequiredVersion = '1.0.1'; }
                @{ Name = 'PSake'; RequiredVersion = '4.6.0'; }
                @{ Name = 'PSDeploy'; RequiredVersion = '0.1.26'; }
                @{ Name = 'PSReadline'; RequiredVersion = '1.2'; }

                ## https://github.com/devblackops/OVF.Active.Directory (Brandon Olin)
                ## Requires PoshSpec and OperationValidation modules
                @{ Name = 'OVF.Active.Directory'; RequiredVersion = '1.0.0'; } 

            )

        } #end Lability
    } #end NonNodeData
} #end Configuration
