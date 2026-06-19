function Save-AzureFailureState {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '', Justification = "Writes a state file but does not change Azure state.")]
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, Position = 0)]
        [string] $Path
    )

    trap {
        throw $_
    }

    if (-not $script:tracerOutput -or $script:tracerOutput.Count -eq 0) {
        Write-PSFMessage -Level Warning -Message "No trace output found to save. Run Invoke-AzureFailureExperiment before saving the state."
    }

    Write-PSFMessage -Level Verbose -Message "Saving {0} trace entries to {1}" -StringValues $script:tracerOutput.Count, $Path

    $state = [PSCustomObject]@{
        apiVersion = $script:APIVersion
        savedAt    = Get-Date
        trace      = @($script:tracerOutput)
    }

    $state | Export-Clixml -Path $Path -Depth 5

    Write-PSFMessage -Level Verbose -Message "State saved to {0}" -StringValues $Path
}
