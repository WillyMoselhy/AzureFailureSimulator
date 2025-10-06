function Set-AzureFailureLogConfig {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string] $LogFolderPath
    )


    $path = New-Item -ItemType Directory -Path $LogFolderPath -Force

    $dateTime = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"
    $paramSetPSFLoggingProvider = @{
        Name         = 'LogFile'
        InstanceName = 'AzureFailureSimulator'
        FilePath     = "$path\AzureFailureSimulator-$dateTime.txt"
        FileType     = 'TXT'
        Enabled      = $true
        Wait         = $true
    }
    Set-PSFLoggingProvider @paramSetPSFLoggingProvider

}