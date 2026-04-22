# Generate branch name
if ($GitFlow -and $ShortName) {
    # Git Flow mode: use the provided short name as-is, no sequential prefix.
    $branchSuffix = $ShortName
    $branchName   = $ShortName
    $featureNum   = ''
} else {
    if ($ShortName) {
        # Use provided short name, just clean it up
        $branchSuffix = ConvertTo-CleanBranchName -Name $ShortName
    } else {
        # Generate from description with smart filtering
        $branchSuffix = Get-BranchName -Description $featureDesc
    }

    # Warn if -Number and -Timestamp are both specified
    if ($Timestamp -and $Number -ne 0) {
        Write-Warning "[specify] Warning: -Number is ignored when -Timestamp is used"
        $Number = 0
    }

    # Determine branch prefix
    if ($Timestamp) {
        $featureNum = Get-Date -Format 'yyyyMMdd-HHmmss'
        $branchName = "$featureNum-$branchSuffix"
    } else {
        # Determine branch number
        if ($Number -eq 0) {
            if ($DryRun -and $hasGit) {
                # Dry-run: query remotes via ls-remote (side-effect-free, no fetch)
                $Number = Get-NextBranchNumber -SpecsDir $specsDir -SkipFetch
            } elseif ($DryRun) {
                # Dry-run without git: local spec dirs only
                $Number = (Get-HighestNumberFromSpecs -SpecsDir $specsDir) + 1
            } elseif ($hasGit) {
                # Check existing branches on remotes
                $Number = Get-NextBranchNumber -SpecsDir $specsDir
            } else {
                # Fall back to local directory check
                $Number = (Get-HighestNumberFromSpecs -SpecsDir $specsDir) + 1
            }
        }

        $featureNum = ('{0:000}' -f $Number)
        $branchName = "$featureNum-$branchSuffix"
    }
}

# GitHub enforces a 244-byte limit on branch names
# Validate and truncate if necessary
$maxBranchLength = 244
if ($branchName.Length -gt $maxBranchLength) {
    if ($GitFlow) {
        Write-Error "[specify] Branch name exceeded GitHub's 244-byte limit: $branchName ($($branchName.Length) bytes). Please use a shorter name."
        exit 1
    }
    # Sequential/timestamp mode: truncate the suffix.
    $prefixLength = $featureNum.Length + 1
    $maxSuffixLength = $maxBranchLength - $prefixLength
    $truncatedSuffix = $branchSuffix.Substring(0, [Math]::Min($branchSuffix.Length, $maxSuffixLength))
    $truncatedSuffix = $truncatedSuffix -replace '-$', ''

    $originalBranchName = $branchName
    $branchName = "$featureNum-$truncatedSuffix"

    Write-Warning "[specify] Branch name exceeded GitHub's 244-byte limit"
    Write-Warning "[specify] Original: $originalBranchName ($($originalBranchName.Length) bytes)"
    Write-Warning "[specify] Truncated to: $branchName ($($branchName.Length) bytes)"
}
