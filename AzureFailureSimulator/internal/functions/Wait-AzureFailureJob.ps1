function Wait-AzureFailureJob {
    param(
        [Parameter(Mandatory=$true)]
        [object[]]$Jobs,

        [Parameter(Mandatory=$true)]
        [string]$Activity
    )

    $waitStartTime = Get-Date
    do {
        $ProgressCount = $Jobs.Count - ($Jobs | Where-Object { $_.State -ne "Completed" }).Count
        $progressPercent = $ProgressCount / $Jobs.Count * 100
        $elapsedTime = (Get-Date) - $waitStartTime
        Write-Progress -Id 1 -Activity $Activity -Status ("{0:N0}% [{1}/{2}] Elapsed Time: {3:hh\:mm\:ss}" -f $progressPercent, $ProgressCount, $Jobs.Count, $elapsedTime) -PercentComplete $progressPercent
        Start-Sleep -Seconds 1
    }
    while ($Jobs.state -contains "Running")
    Write-Progress -Id 1 -Completed
}