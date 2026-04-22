function Get-FeatureDir {
    param([string]$RepoRoot, [string]$Branch)
    $featureName = Get-FeatureName -Branch $Branch
    Join-Path $RepoRoot "specs/$featureName"
}
