function Invoke-AzureFailureExperiment {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSShouldProcess', '', Justification = "This function is a controller that invokes other functions that implement ShouldProcess.")]
    [CmdletBinding(SupportsShouldProcess = $true)]
    param (
        [Parameter(Mandatory = $false)]
        [string] $LogFolderPath,

        [Parameter(Mandatory = $false, Position = 1)]
        [string] $TraceOutputPath
    )
    trap {
        throw $_
    }

    # Reset the trace output in case we are re-invoking the function in the same session.
    $script:tracerOutput = @()

    if ($LogFolderPath) {
        Set-AzureFailureLogConfig -LogFolderPath $LogFolderPath
    }

    if ($TraceOutputPath) {
        $script:TraceOutputPath = $TraceOutputPath
    }

    foreach ($step in $script:Steps) {
        Write-PSFMessage -Level Verbose -Message "Invoking step: $($step.Name)"
        foreach ($branch in $step.Branches) {
            Write-PSFMessage -Level Verbose -Message "Invoking branch: $($step.Name) > $branch"
            $branchActions = ($script:Branches | Where-Object { $_.StepName -eq $step.Name -and $_.Name -eq $branch }).Actions
            foreach ($action in $branchActions) {
                Write-PSFMessage -Level Verbose -Message "Invoking action: $($step.Name) >  $branch > $($action.Name)"

                $actionDefinition = $script:ActionList[$action.name]
                $paramInvokeAzureFailureAction = @{
                    Step   = $step.Name
                    Branch = $branch
                }
                if ($action.SelectorId) {
                    $paramInvokeAzureFailureAction["TargetResourceId"] = ($script:Selectors[$action.selectorId].Targets | Where-Object { $_.Type -eq $actionDefinition.TargetType }).ResourceId
                }
                if ($actionDefinition.Parameters) {
                    $paramInvokeAzureFailureAction += $action.Parameters
                }
                if ($actionDefinition.SupportsDuration) {
                    $paramInvokeAzureFailureAction["Duration"] = $action.Duration
                }
                if ($actionDefinition.SupportsFilter -and $script:Selectors[$action.selectorId].Filter) {
                    $paramInvokeAzureFailureAction["Filter"] = $script:Selectors[$action.selectorId].Filter
                }
                Write-PSFMessage -Level Verbose -Message "Invoking Action Command: $($actionDefinition.Command) with parameters: $($paramInvokeAzureFailureAction | Out-String)"
                try {
                    & $actionDefinition.Command @paramInvokeAzureFailureAction
                }
                catch {
                    Write-PSFMessage -Level Error -Message "Error invoking action: {0} > {1} > {2}." -StringValues $step.Name, $branch, $action.Name -ErrorRecord $_ -Tag Critical, Fail
                    throw # "In try catch you don't need $_ , in trap you need" -Friedrich Weinmann
                }
            }
        }
    }
}