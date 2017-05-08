@{
    AllNodes = @(

        @{
            NodeName = 'localhost';
            PSDscAllowPlainTextPassword = $true;
            IPAddress = '10.200.0.10';
            # CertificateFile = "C:\ProgramData\Lability\Certificates\LabClient.cer";
        }
    )

    NonNodeData = @{

        xActiveDirectory = @{

            DomainName = 'test.local';
            DomainNetBIOSName = 'TEST';
            
        }
    }
}
