function Import-AzureFailureState {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '', Justification = "Loads in-memory state but does not change Azure state.")]
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, Position = 0)]
        [string] $Path,

        [Parameter(Mandatory = $false, Position = 1)]
        [string] $TraceOutputPath
    )

    trap {
        throw $_
    }

    if (-not (Test-Path -Path $Path)) {
        throw "State file not found at $Path"
    }

    Write-PSFMessage -Level Verbose -Message "Importing state from {0}" -StringValues $Path
    $state = Import-Clixml -Path $Path

    Write-PSFMessage -Level Verbose -Message "Validating API Version"
    Test-APIVersion -APIVersion $state.apiVersion

    # The trace alone is not enough to restore. The experiment configuration
    # (selectors, steps, branches) must be imported beforehand using
    # Import-AzureFailureExperiment. Warn if it has not been loaded yet.
    if (-not $script:Steps -or $script:Steps.Count -eq 0 -or -not $script:Branches -or $script:Branches.Count -eq 0) {
        Write-PSFMessage -Level Warning -Message "No experiment configuration found in the current session. Import the experiment configuration with Import-AzureFailureExperiment before running Restore-AzureFailureExperiment."
    }

    $script:tracerOutput = @($state.trace)
    Write-PSFMessage -Level Verbose -Message "Imported {0} trace entries from {1}" -StringValues $script:tracerOutput.Count, $Path

    if ($TraceOutputPath) {
        Write-PSFMessage -Level Verbose -Message "Setting trace output path to {0}" -StringValues $TraceOutputPath
        $script:TraceOutputPath = $TraceOutputPath
    }
}
