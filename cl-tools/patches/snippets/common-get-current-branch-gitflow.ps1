        # If no numbered dirs found, use most recently modified dir (Git Flow pattern)
        if (-not $latestFeature) {
            $latest = Get-ChildItem -Path $specsDir -Directory | Sort-Object LastWriteTime -Descending | Select-Object -First 1
            if ($latest) {
                $latestFeature = $latest.Name
            }
        }

        if ($latestFeature) {
            return $latestFeature
        }
    }
