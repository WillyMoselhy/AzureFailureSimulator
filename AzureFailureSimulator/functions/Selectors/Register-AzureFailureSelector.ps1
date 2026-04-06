function Register-AzureFailureSelector {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, Position = 0, ValueFromPipelineByPropertyName = $true)]
        [string] $Id,

        #[Parameter(Mandatory = $true, ParameterSetName = "Query", Position = 2, ValueFromPipelineByPropertyName = $true)]
        #[string] $QueryString,
        # For future use

        #Parameter to accept array of subscription Ids. Parameter name is plural to align with Chaos studio inputs.
        #[Parameter(Mandatory = $true, ParameterSetName = "Query", Position = 3, ValueFromPipelineByPropertyName = $true)]
        #[string[]] $SubscriptionIds,
        # For future use

        #Parameter to accept list of resource Ids. Parameter name is plural to align with Chaos studio inputs.
        [Parameter(Mandatory = $true, ParameterSetName = "List", Position = 2, ValueFromPipelineByPropertyName = $true)]
        [PSCustomObject[]] $Targets,

        #Parameter to accept filter hashtable for VMSS. This will be used only when the target type is VMSS.
        [Parameter(Mandatory = $false, ParameterSetName = "List", Position = 3, ValueFromPipelineByPropertyName = $true)]
        [PSCustomObject] $Filter

    )
    process {

        # Validate Selector Id is unique
        Write-PSFMessage -Level Verbose -Message "Validating selector Id: $($Id)"
        if ($script:Selectors.ContainsKey($Id)) {
            throw "Selector Id: $($Id) is already registered. Selector Ids must be unique."
        }

        # validate target parameter
        # parameter must be an array of hash tables, each hashtable must have an "id" key with a string value
        # the id must be a valid resource Id, Ids must be unique
        Write-PSFMessage -Level Verbose -Message "Validating targets for selector Id: $($Id)"
        if ($Targets.id | Group-Object | Where-Object { $_.Count -gt 1 }) {
            throw "Selector Id: $($Id) - Duplicate target Ids found."
        }

        $targetObjects = @()

        if ($PSCmdlet.ParameterSetName -eq "List") {
            foreach ($target in $Targets) {
                if (-not ($target -is [PSCustomObject])) {
                    throw "Selector Id ($($Id)): Each target must be an Object."
                }
                if (-not $target.id) {
                    throw "Selector Id ($($Id)): Each target must have an 'id' key."
                }
                if (-not ($target.id -is [string])) {
                    throw "Selector Id ($($Id)): The target 'id' key must have a string value."
                }
                if (-not ($target.id -match "^/subscriptions/[0-9a-fA-F-]+/resourceGroups/[^/]+/providers/[^/]+/[^/]+/[^/]+$")) {
                    throw "Selector Id ($($Id)): The 'id' value must be a valid resource Id."
                }
                $targetType = ($target.id -split "/")[6..7] -join "/"
                if (-not ($script:TargetTypes -contains $targetType)) {
                    throw "Selector Id ($($Id)): target ($($target.id)): The target type '$targetType' is not supported. Supported types are: $($script:TargetTypes -join ", ")"
                }
                $targetObjects += [PSCustomObject]@{
                    ResourceID = $target.id
                    Name       = ($target.id -split "/")[-1]
                    Type       = ($target.id -split "/")[6..7] -join "/"
                }
            }
        }
        #Confirm all targets are of the same type
        if ( ($targetObjects.Type | Select-Object -Unique -CaseInsensitive).count -gt 1 ) {
            throw "Selector Id: $($Id) - All target resources must be of the same type."
        }

        # Register filters
        if($Filter){
            Write-PSFMessage -Level Verbose -Message "Validating filter for selector Id: $($Id)"
            if($targetObjects[0].Type -notin ("Microsoft.Compute/virtualMachineScaleSets","Microsoft.DBforPostgreSQL/flexibleServers","Microsoft.ContainerService/managedClusters")){ # TODO: Find a Better way to check if the target type supports filter
                throw "Selector Id: $($Id) - Filter can only be applied when the target type is 'Microsoft.Compute/virtualMachineScaleSets' or 'Microsoft.DBforPostgreSQL/flexibleServers' or 'Microsoft.ContainerService/managedClusters'."
            }
            if($targetObjects[0].Type -eq "Microsoft.ContainerService/managedClusters"){
                $filterZones = $Filter.parameters.zones
                $filterNodePool = $Filter.parameters.nodepool

                if(-not $filterZones -and -not $filterNodePool){
                    throw "Selector Id: $($Id) - AKS filter must have at least one of 'parameters.zones' or 'parameters.nodepool'."
                }

                if($filterZones){
                    $filterZones = [string[]]$filterZones
                    Write-PSFMessage -Level Verbose -Message "Selector Id: $($Id) - Applying AKS filter zones: $($filterZones -join ", ")"
                }
                if($filterNodePool){
                    $filterNodePool = [string[]]$filterNodePool
                    Write-PSFMessage -Level Verbose -Message "Selector Id: $($Id) - Applying AKS filter node pools: $($filterNodePool -join ", ")"
                }

                $selectorFilter = [PSCustomObject]@{
                    Zones    = $filterZones
                    NodePool = $filterNodePool
                }
            }
            else {
                if(-not $Filter.parameters.zones){
                    throw "Selector Id: $($Id) - Filter must have a 'parameters.zones' key."
                }
                $filterZones = [string[]]$Filter.parameters.zones
                Write-PSFMessage -Level Verbose -Message "Selector Id: $($Id) - Applying filter zones: $($filterZones -join ", ")"
                $selectorFilter = $filterZones
            }
        }
        elseif($targetObjects[0].Type -eq "Microsoft.Compute/virtualMachineScaleSets"){
            Write-PSFMessage -Level Warning -Message "Selector Id: $($Id) - No filter applied for VMScaleSet. All instances in the scale set will be targeted."
            $selectorFilter = $null
        }
        else{
            $selectorFilter = $null
        }


        # TODO: Add logic for the Query parameter set
        $script:Selectors[$Id] = [PSCustomObject]@{
            Targets = $targetObjects
            Filter = $selectorFilter
        }
    }

}