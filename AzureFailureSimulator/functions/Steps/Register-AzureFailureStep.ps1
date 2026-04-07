function Register-AzureFailureStep {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, Position = 0, ValueFromPipelineByPropertyName = $true)]
        [string] $Name,

        [Parameter(Mandatory = $true, Position = 1, ValueFromPipelineByPropertyName = $true)]
        [PSCustomObject[]] $Branches
    )


    process {
        # Validate Step Name is unique
        Write-PSFMessage -Level Verbose -Message "Validating step: $($Name)"
        if ($script:Steps.Name -contains $Name) {
            throw "Step ($($Name)): Already registered. Step Names must be unique."
        }
        # Validate Branches have unique names
        Write-PSFMessage -Level Verbose -Message "Registering branches for step: $($Name)"
        if ($Branches.name | Group-Object | Where-Object { $_.Count -gt 1 }) {
            throw "Step ($($Name)): Duplicate branch names found."
        }

        # Register the branches
        $Branches | Register-AzureFailureBranch -StepName $Name

        $script:Steps += [PSCustomObject]@{
            Name     = $Name
            Branches = [array] $Branches.name
        }

    }

}