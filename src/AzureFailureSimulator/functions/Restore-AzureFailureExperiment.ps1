function Restore-AzureFailureExperiment {
    [CmdletBinding()]
    param (
        [switch] $RestoreSkipped
    )

    trap {
        throw $_
    }

    if($RestoreSkipped){
        Write-PSFMessage -Level Verbose -Message "Skipped resources will be started during restore."
        $script:RestoreSkipped = $true
    }
    # Go over the steps in reverse order
    foreach($step in ($script:Steps[($script:Steps.count-1)..0])){
        Write-PSFMessage -Level Verbose -Message "Restoring step: $($step.Name)"
        # Go over the branches in reverse order
        foreach($branch in ($step.Branches[($step.Branches.count-1)..0])){
            Write-PSFMessage -Level Verbose -Message "Restoring branch: $($step.Name) > $branch"
            $branchActions = ($script:Branches | Where-Object { $_.StepName -eq $step.Name -and $_.Name -eq $branch }).Actions
            # Go over the actions in reverse order
            foreach($action in ($branchActions[($branchActions.count-1)..0])){
                Write-PSFMessage -Level Verbose -Message "Restoring action: $($step.Name) >  $branch > $($action.Name)"

                $actionDefinition = $script:ActionList[$action.name]
                if ($actionDefinition.RestoreCommand) {
                    $paramRestoreAzureFailureAction = @{
                        Step   = $step.Name
                        Branch = $branch
                    }
                    if ($actionDefinition.Parameters) {
                        $paramRestoreAzureFailureAction["TargetResourceId"] = ($script:Selectors[$action.selectorId].Targets | Where-Object { $_.Type -eq $actionDefinition.TargetType }).ResourceId
                        $paramRestoreAzureFailureAction += $action.Parameters
                    }
                    if ($actionDefinition.SupportsDuration) {
                        $paramRestoreAzureFailureAction["Duration"] = $action.Duration
                    }
                    Write-PSFMessage -Level Verbose -Message "Invoking Restore Command: $($actionDefinition.RestoreCommand) with parameters: $($paramRestoreAzureFailureAction | Out-String)"
                    & $actionDefinition.RestoreCommand @paramRestoreAzureFailureAction
                }
                else {
                    Write-PSFMessage -Level Warning -Message "No restore command defined for action: $($step.Name) >  $branch > $($action.Name). Skipping..."
                }
            }
        }
    }

}