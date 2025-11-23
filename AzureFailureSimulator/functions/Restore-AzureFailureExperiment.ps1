function Restore-AzureFailureExperiment {
    [CmdletBinding()]
    param (
        [switch] $RestoreSkipped,
        
        [switch] $SkipPaaSRestore
    )

    trap {
        throw $_
    }

    if($RestoreSkipped){
        Write-PSFMessage -Level Verbose -Message "Skipped resources will be started during restore."
        $script:RestoreSkipped = $true
    }
    
    # Define PaaS resource types that can be skipped during restore
    $paasResourceTypes = @(
        "Microsoft.DBforPostgreSQL/flexibleServers"
        "Microsoft.Cache/Redis"
    )
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
                
                # Check if this is a PaaS resource and if PaaS restore should be skipped
                if ($SkipPaaSRestore -and $actionDefinition.TargetType -in $paasResourceTypes) {
                    Write-PSFMessage -Level Warning -Message "Skipping PaaS restore for action: $($step.Name) > $branch > $($action.Name) (TargetType: $($actionDefinition.TargetType))"
                    continue
                }
                
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