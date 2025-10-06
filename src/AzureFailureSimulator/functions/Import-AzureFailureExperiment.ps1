function Import-AzureFailureExperiment {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, Position = 0)]
        [string]$Path


    )


    trap {
        throw $_
    }

    # Cleanup any previous run state
    if ($script:Selectors -or $script:Branches -or $script:Steps) {
        $script:Selectors = @{}
        $script:Steps = @()
        $script:Branches = @()
        $script:tracerOutput = @()
    }



    Write-PSFMessage -Level Verbose -Message "Importing experiment from $Path"
    $experiment = Get-Content -Path $Path | ConvertFrom-Json

    Write-PSFMessage -Verbose -Message "Validating API Version"
    Test-APIVersion -APIVersion $experiment.apiVersion

    #register selectors
    Write-PSFMessage -Level Verbose -Message "Registering {0} selectors" -StringValues $experiment.properties.selectors.Count
    $experiment.properties.selectors | Register-AzureFailureSelector

    #register steps
    Write-PSFMessage -Level Verbose -Message "Registering {0} steps" -StringValues $experiment.properties.steps.Count
    $experiment.properties.steps | Register-AzureFailureStep


}