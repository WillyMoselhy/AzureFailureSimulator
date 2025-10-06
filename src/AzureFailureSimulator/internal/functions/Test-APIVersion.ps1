function Test-APIVersion {
    [CmdletBinding()]
    param (
        [string]$APIVersion
    )

    if ($APIVersion -eq $script:APIVersion) {
        # All good, nothing to return.
    }
    else {
        throw "API Version $APIVersion is not supported. Supported version is $script:APIVersion"
    }
}