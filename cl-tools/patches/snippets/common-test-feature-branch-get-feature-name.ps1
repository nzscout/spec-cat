    $hasMalformedTimestamp = ($Branch -match '^[0-9]{7}-[0-9]{6}-') -or ($Branch -match '^(?:\d{7}|\d{8})-\d{6}$')
    $isSequential = ($Branch -match '^[0-9]{3,}-') -and (-not $hasMalformedTimestamp)
    if (-not $isSequential -and $Branch -notmatch '^\d{8}-\d{6}-' -and $Branch -notmatch '^feature/') {
        Write-Output "ERROR: Not on a feature branch. Current branch: $Branch"
        Write-Output "Feature branches should be named like: 001-feature-name, 1234-feature-name, 20260319-143022-feature-name, or feature/<feature-name>"
        return $false
    }
    return $true
}

function Get-FeatureName {
    param([string]$Branch)

    if ($env:SPECIFY_FEATURE) {
        return $env:SPECIFY_FEATURE
    }

    if ($Branch -match '^feature/(.+)$') {
        return $matches[1]
    }

    return $Branch
}
