$featureDir = Join-Path $specsDir $branchName
# Git Flow: $featureDir was captured with the short name above (specs/DATA-5200-foo).
# Now update $branchName to the full feature/ prefix so the git checkout block below
# creates the correct branch (feature/DATA-5200-foo) while $featureDir stays correct.
if ($GitFlow -and $ShortName) {
    $branchName = "feature/$ShortName"
}
