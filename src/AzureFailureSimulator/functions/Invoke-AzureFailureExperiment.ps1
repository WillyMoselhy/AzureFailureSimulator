function Invoke-AzureFailureExperiment {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $false)]
        [string] $LogFolderPath,

        [Parameter(Mandatory = $false, Position = 1)]
        [string] $TraceOutputPath
    )
    trap {
        throw $_
    }

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
                if ($actionDefinition.Parameters) {
                    $paramInvokeAzureFailureAction["TargetResourceId"] = ($script:Selectors[$action.selectorId].Targets | Where-Object { $_.Type -eq $actionDefinition.TargetType }).ResourceId
                    $paramInvokeAzureFailureAction += $action.Parameters
                }
                if ($actionDefinition.SupportsDuration) {
                    $paramInvokeAzureFailureAction["Duration"] = $action.Duration
                }
                Write-PSFMessage -Level Verbose -Message "Invoking Action Command: $($actionDefinition.Command) with parameters: $($paramInvokeAzureFailureAction | Out-String)"
                & $actionDefinition.Command @paramInvokeAzureFailureAction
            }
        }
    }
}