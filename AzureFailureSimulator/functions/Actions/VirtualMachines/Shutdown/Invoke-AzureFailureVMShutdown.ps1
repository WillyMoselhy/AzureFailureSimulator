function Invoke-AzureFailureVMShutdown {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param (
        [Parameter(Mandatory = $true)]
        [string] $Step,

        [Parameter(Mandatory = $true)]
        [string] $Branch,

        [Parameter(Mandatory = $true)]
        [string[]] $TargetResourceId,

        [string] $Duration,
        [bool] $AbruptShutdown = $false,

        [string] $ActionName = "urn:csci:microsoft:virtualMachine:shutdown/1.0"
    )


    if ($AbruptShutdown) {
        Write-PSFMessage -Level Warning -Message "Abrupt Shutdown enabled. This may cause data loss or corruption on the target VM(s)."
    }

    $actionJobs = @()
    foreach ($target in $TargetResourceId) {
        Write-PSFMessage -Level Verbose -Message "Shutting down VM: $target"

        $vmStatus = Get-AzVM -ResourceId $target -Status
        if ( $vmStatus.Statuses[1].Code -eq "PowerState/running") {
            if ($PSCmdlet.ShouldProcess("Virtual Machine", "Shutdown")) {
                $actionJobs += Stop-AzVM -Id $target -Force:$true -SkipShutdown:$AbruptShutdown -AsJob
            }

            $actionStatus = "InProgress"
        }
        else {
            Write-PSFMessage -Level Warning -Message "Step ($Step), Branch ($Branch), Target ($target): VM is not in 'running' state. Current state: $($vmStatus.Statuses[1].DisplayStatus). Skipping shutdown."
            $actionJobs += $false
            $actionStatus = "Skipped"
            $actionMessage = 'VM is not in running state'
        }

        $paramUpdateAzureFailureTrace = @{
            ResourceId        = $target
            Step              = $Step
            Branch            = $Branch
            Action            = $ActionName
            ActionStatus      = $actionStatus
            ActionMessage     = $actionMessage
            ActionTriggerTime = Get-Date
        }
        Update-AzureFailureTrace @paramUpdateAzureFailureTrace
    }
    if ($actionJobs | Where-Object { $_ -ne $false }) {

        Write-PSFMessage -Level Verbose -Message "Waiting for VM shutdown jobs to complete"

        $null = Wait-Job -Job ($actionJobs | Where-Object { $_ -ne $false })

        Write-PSFMessage -Level Verbose -Message "VM shutdown jobs complete"
    }
    for ($i = 0; $i -lt $TargetResourceId.Count; $i++) {
        $actionCompleteTime = if ($actionJobs[$i]) { ($actionJobs[$i] | Receive-Job).EndTime } else { Get-Date }
        $paramUpdateAzureFailureTrace = @{
            ResourceId         = $TargetResourceId[$i]
            Step               = $Step
            Branch             = $Branch
            ActionStatus       = "Success"
            Action             = $ActionName
            ActionCompleteTime = $actionCompleteTime
        }
        Update-AzureFailureTrace @paramUpdateAzureFailureTrace
    }

}
