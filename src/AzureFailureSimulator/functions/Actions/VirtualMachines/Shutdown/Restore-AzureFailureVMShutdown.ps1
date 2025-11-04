function Restore-AzureFailureVMShutdown {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string] $Step,

        [Parameter(Mandatory = $true)]
        [string] $Branch,

        [Parameter(Mandatory = $true)]
        [string[]] $TargetResourceId,

        # These might not be used but added for consistency.
        [string] $Duration,
        [bool] $AbruptShutdown = $false,

        [string] $ActionName = "urn:csci:microsoft:virtualMachine:shutdown/1.0",

        [bool] $RestoreSkipped = $script:RestoreSkipped
    )

    Write-PSFMessage -Level Verbose -Message "Starting VM(s) for Step ($Step), Branch ($Branch), Target(s): $($TargetResourceId -join ', ')"
    $actionJobs = @()
    foreach ($target in $TargetResourceId) {
        $targetTrace = Get-AzureFailureTrace | Where-Object {
            $_.ResourceId -eq $target -and
            $_.Step -eq $Step -and
            $_.Branch -eq $Branch -and
            $_.Action -eq $ActionName
        }
        if ($targetTrace.ActionSkipped -and -not $RestoreSkipped) {
            Write-PSFMessage -Level Verbose -Message "Step ($Step), Branch ($Branch), Target ($target): Action was previously skipped. No instances to start."
            $actionJobs += $false
            continue
        }

        Write-PSFMessage -Level Verbose -Message "Starting VM: $target"

        $actionJobs += Start-AzVM -Id $target -AsJob

        $paramUpdateAzureFailureTrace = @{
            ResourceId               = $target
            Step                     = $Step
            Branch                   = $Branch
            Action                   = $ActionName
            ActionRestoreTriggerTime = Get-Date
        }
        Update-AzureFailureTrace @paramUpdateAzureFailureTrace

    }
    if ($actionJobs | Where-Object { $_ -ne $false }) {

        Write-PSFMessage -Level Verbose -Message "Waiting for VM start jobs to complete"
        $null = Wait-Job -Job ($actionJobs | Where-Object { $_ -ne $false })
        Write-PSFMessage -Level Verbose -Message "VM start jobs complete"
    }
    for ($i = 0; $i -lt $TargetResourceId.Count; $i++) {
        if ($actionJobs[$i]) {
            $paramUpdateAzureFailureTrace = @{
                ResourceId                = $TargetResourceId[$i]
                Step                      = $Step
                Branch                    = $Branch
                Action                    = $ActionName
                ActionRestoreCompleteTime = ($actionJobs[$i] | Receive-Job).EndTime
            }
            Update-AzureFailureTrace @paramUpdateAzureFailureTrace
        }
        else {
            continue
        }
    }
}