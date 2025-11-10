function Register-AzureFailureBranch {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, Position = 0)]
        [string] $StepName,

        [Parameter(Mandatory = $true, Position = 1, ValueFromPipelineByPropertyName = $true)]
        [string] $Name,

        [Parameter(Mandatory = $true, Position = 2, ValueFromPipelineByPropertyName = $true)]
        [PSCustomObject[]] $Actions
    )

    process {

        # For each action we need to convert duration to TimeSpan,
        # validate the action name is supported for the selector target type,
        # and validate the parameters are valid for the action.

        $actionObjects = @()
        foreach ($action in $Actions) {
            # Validate action name is supported
            if (-not $script:ActionList[$action.name]) {
                throw "Step ($($StepName)) - Branch ($($Name)): Action ($($action.name)) is not supported. Use Get-AzureFailureActionList to see supported actions."
            }
            $actionDefinition = $script:ActionList[$action.name]
            #Validate and convert Duration to TimeSpan
            try {
                $durationTimeSpan = if ($actionDefinition.SupportsDuration) {
                    [System.Xml.XmlConvert]::ToTimeSpan($action.duration)
                }
                else { [System.Xml.XmlConvert]::ToTimeSpan("PT0S") }
            }
            catch {
                throw "Step ($($StepName)) - Branch ($($Name)) - Action ($($action.name)): Duration ($($action.duration)) is not a valid ISO 8601 duration. Use PT0S for zero duration."
            }

            switch ($action.type) {
                {"continuous" -or "discrete"} {
                    # Validate Selectors
                    if (-not $script:Selectors[$action.selectorId]) {
                        throw "Step ($($StepName)) - Branch ($($Name)) - Action ($($action.name)): SelectorId ($($action.selectorId)) is not registered."
                    }
                    if ($script:Selectors[$action.selectorId].Targets[0].Type -ne $actionDefinition.TargetType) {
                        throw "Step ($($StepName)) - Branch ($($Name)) - Action ($($action.name)): SelectorId ($($action.selectorId)) target type ($($script:Selectors[$action.selectorId].Targets[0].Type)) does not match action target type ($($actionDefinition.TargetType))."
                    }

                    #Validate Parameters
                    $providedParams = @{}
                    $action.parameters | ForEach-Object { $providedParams[$_.key] = $_.value }

                    foreach ($actionDefinitionParameter in $actionDefinition.Parameters) {
                        if ($actionDefinitionParameter.Required -and -not $providedParams.ContainsKey($actionDefinitionParameter.Name)) {
                            throw "Step ($($StepName)) - Branch ($($Name)) - Action ($($action.name)): Missing required parameter ($($actionDefinitionParameter.Name))."
                        }
                        if ($providedParams.ContainsKey($actionDefinitionParameter.Name)) {
                            switch ($actionDefinitionParameter.Type) {
                                "string" {
                                    $providedParams[$actionDefinitionParameter.Name] = [string]$providedParams[$actionDefinitionParameter.Name]
                                }
                                "bool" {
                                    $providedParams[$actionDefinitionParameter.Name] = [bool]$providedParams[$actionDefinitionParameter.Name]
                                }
                                default {
                                    throw "Step ($($StepName)) - Branch ($($Name)) - Action ($($action.name)): Parameter ($($actionDefinitionParameter.Name)) has unsupported type ($($actionDefinitionParameter.Type)). Supported types are 'string' and 'bool'."
                                }
                            }
                        }
                    }
                    $actionObjects += [PSCustomObject]@{
                        Name       = $action.name
                        Duration   = $durationTimeSpan
                        SelectorId = $action.selectorId
                        Parameters = $providedParams
                    }
                }
                "delay" {
                    $actionObjects += [PSCustomObject]@{
                        Name     = $action.name
                        Duration = $durationTimeSpan
                    }
                }
                default {
                    throw "Step ($($StepName)) - Branch ($($Name)) - Action ($($action.name)): Type ($($action.type)) is not supported. Supported types are 'continuous', 'discrete', and 'delay'."
                }
            }


        }
        $script:Branches += [PSCustomObject]@{
            StepName = $StepName
            Name     = $Name
            Actions  = $ActionObjects
        }
    }
}