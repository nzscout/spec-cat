"""
Tests for Git Flow patches applied to PowerShell scripts (Options 1 + 3).

Option 1 — pwsh subprocess tests:
  Apply CL patches to spec-cat upstream scripts in a temp git repo, then
  invoke the patched scripts through pwsh to verify Git Flow behaviour.

Option 3 — patch anchor CI check:
  TestPatchAnchors verifies every anchor in apply.ps1 still resolves against
  the spec-cat upstream scripts. This is the same check as `apply.ps1 -WhatIf`
  on CI; failing here means an upstream rename has broken a patch definition.

Requires pwsh to be available on PATH (pre-installed on ubuntu-latest runners).
"""

import json
import os
import re
import shutil
import subprocess
from pathlib import Path

import pytest

PROJECT_ROOT = Path(__file__).resolve().parent.parent
SCRIPTS_PS = PROJECT_ROOT / "scripts" / "powershell"
APPLY_PS1 = PROJECT_ROOT / "cl-tools" / "patches" / "apply.ps1"

# Minimal speckit.specify.agent.md stub — just enough to satisfy the two agent patches.
_AGENT_STUB = """\
---
description: test stub
---

1. **Generate a concise short name** (2-4 words) for the branch:
   - placeholder step 1

2. **Create the feature branch** by running the script...

3. **Create the spec file**
"""

pytestmark = pytest.mark.skipif(
    shutil.which("pwsh") is None, reason="pwsh not available"
)


# ---------------------------------------------------------------------------
# Fixtures
# ---------------------------------------------------------------------------

@pytest.fixture(scope="module")
def patched_project(tmp_path_factory: pytest.TempPathFactory) -> Path:
    """
    One-time fixture (module scope): create a minimal git repo, copy the
    spec-cat upstream scripts, apply CL patches, and return the project root.
    """
    root = tmp_path_factory.mktemp("gitflow_ps")

    # Set up a minimal git repo
    for cmd in (
        ["git", "init", "-q"],
        ["git", "config", "user.email", "test@test.com"],
        ["git", "config", "user.name", "Test"],
        ["git", "commit", "--allow-empty", "-m", "init", "-q"],
    ):
        subprocess.run(cmd, cwd=root, check=True, capture_output=True)

    # Copy upstream scripts (what `specify init` would deploy)
    ps_dir = root / ".specify" / "scripts" / "powershell"
    ps_dir.mkdir(parents=True)
    for f in SCRIPTS_PS.glob("*.ps1"):
        shutil.copy(f, ps_dir / f.name)

    # Agent stub for the two speckit.specify patches
    agent_dir = root / ".github" / "agents"
    agent_dir.mkdir(parents=True)
    (agent_dir / "speckit.specify.agent.md").write_text(_AGENT_STUB, encoding="utf-8")

    # Spec template dir (needed by create-new-feature.ps1)
    (root / ".specify" / "templates").mkdir(exist_ok=True)

    # Apply all CL patches
    result = subprocess.run(
        ["pwsh", "-File", str(APPLY_PS1), "-ProjectRoot", str(root)],
        capture_output=True,
        text=True,
    )
    assert result.returncode == 0, (
        f"apply.ps1 failed:\nSTDOUT:\n{result.stdout}\nSTDERR:\n{result.stderr}"
    )

    return root


def _run_ps(cwd: Path, script: Path, *args: str) -> subprocess.CompletedProcess:
    """Run a .ps1 script through pwsh."""
    return subprocess.run(
        ["pwsh", "-NonInteractive", "-File", str(script), *args],
        cwd=str(cwd),
        capture_output=True,
        text=True,
    )


def _invoke_function(common_ps1: Path, expression: str, env: dict | None = None) -> subprocess.CompletedProcess:
    """Dot-source common.ps1 then evaluate an expression, returning stdout."""
    cmd = f'. "{common_ps1}"; {expression}'
    return subprocess.run(
        ["pwsh", "-NonInteractive", "-NoProfile", "-Command", cmd],
        capture_output=True,
        text=True,
        env={**os.environ, **(env or {})},
    )


# ---------------------------------------------------------------------------
# Option 3 — Patch anchor checks
# ---------------------------------------------------------------------------

class TestPatchAnchors:
    """Verify every anchor in apply.ps1 resolves against spec-cat upstream scripts.

    This reproduces `apply.ps1 -WhatIf` as a pytest assertion so anchor
    breakage shows up in the normal test run instead of a separate CI step.
    """

    def test_all_anchors_resolve(self, patched_project: Path):
        """apply.ps1 -WhatIf must exit 0 (all anchors found) against a fresh copy."""
        # Use a separate fresh copy so patching state doesn't interfere
        fresh = patched_project.parent / "anchor_check"
        if fresh.exists():
            shutil.rmtree(fresh)
        fresh.mkdir()

        for cmd in (
            ["git", "init", "-q"],
            ["git", "config", "user.email", "t@t.com"],
            ["git", "config", "user.name", "T"],
            ["git", "commit", "--allow-empty", "-m", "init", "-q"],
        ):
            subprocess.run(cmd, cwd=fresh, check=True, capture_output=True)

        ps_dir = fresh / ".specify" / "scripts" / "powershell"
        ps_dir.mkdir(parents=True)
        for f in SCRIPTS_PS.glob("*.ps1"):
            shutil.copy(f, ps_dir / f.name)

        agent_dir = fresh / ".github" / "agents"
        agent_dir.mkdir(parents=True)
        (agent_dir / "speckit.specify.agent.md").write_text(_AGENT_STUB, encoding="utf-8")

        result = subprocess.run(
            ["pwsh", "-File", str(APPLY_PS1), "-ProjectRoot", str(fresh), "-WhatIf"],
            capture_output=True,
            text=True,
        )
        assert result.returncode == 0, (
            "One or more patch anchors not found in upstream scripts.\n"
            "An upstream rename may have broken a patch definition.\n"
            f"Output:\n{result.stdout}\n{result.stderr}"
        )
        assert "[WARN]" not in result.stdout, (
            f"Unexpected [WARN] in anchor check output:\n{result.stdout}"
        )


# ---------------------------------------------------------------------------
# Option 1 — Test-FeatureBranch (patched common.ps1)
# ---------------------------------------------------------------------------

class TestTestFeatureBranch:
    def test_accepts_gitflow_branch(self, patched_project: Path):
        """Patched Test-FeatureBranch must accept feature/<name> branches."""
        common = patched_project / ".specify/scripts/powershell/common.ps1"
        res = _invoke_function(common, "Test-FeatureBranch -Branch 'feature/DATA-5200-my-feat' -HasGit $true")
        assert "ERROR" not in res.stdout, res.stdout

    def test_accepts_legacy_sequential(self, patched_project: Path):
        """Patched Test-FeatureBranch still accepts 001-style branches."""
        common = patched_project / ".specify/scripts/powershell/common.ps1"
        res = _invoke_function(common, "Test-FeatureBranch -Branch '001-user-auth' -HasGit $true")
        assert "ERROR" not in res.stdout, res.stdout

    def test_accepts_4digit_sequential(self, patched_project: Path):
        """Patched Test-FeatureBranch accepts 4+ digit sequential prefixes."""
        common = patched_project / ".specify/scripts/powershell/common.ps1"
        res = _invoke_function(common, "Test-FeatureBranch -Branch '1234-big-feature' -HasGit $true")
        assert "ERROR" not in res.stdout, res.stdout

    def test_accepts_timestamp_branch(self, patched_project: Path):
        """Patched Test-FeatureBranch still accepts timestamp branches."""
        common = patched_project / ".specify/scripts/powershell/common.ps1"
        res = _invoke_function(common, "Test-FeatureBranch -Branch '20260319-143022-user-auth' -HasGit $true")
        assert "ERROR" not in res.stdout, res.stdout

    def test_rejects_main(self, patched_project: Path):
        """Patched Test-FeatureBranch rejects 'main'."""
        common = patched_project / ".specify/scripts/powershell/common.ps1"
        res = _invoke_function(common, "Test-FeatureBranch -Branch 'main' -HasGit $true")
        assert "ERROR" in res.stdout, f"expected rejection, got: {res.stdout!r}"

    def test_rejects_bare_shortname(self, patched_project: Path):
        """Patched Test-FeatureBranch rejects plain names with no prefix."""
        common = patched_project / ".specify/scripts/powershell/common.ps1"
        res = _invoke_function(common, "Test-FeatureBranch -Branch 'user-auth' -HasGit $true")
        assert "ERROR" in res.stdout, f"expected rejection, got: {res.stdout!r}"


# ---------------------------------------------------------------------------
# Get-FeatureName (new function inserted by patch)
# ---------------------------------------------------------------------------

class TestGetFeatureName:
    def test_strips_feature_prefix(self, patched_project: Path):
        """Get-FeatureName 'feature/DATA-5200-foo' → 'DATA-5200-foo'."""
        common = patched_project / ".specify/scripts/powershell/common.ps1"
        res = _invoke_function(common, "Get-FeatureName -Branch 'feature/DATA-5200-foo'")
        assert res.stdout.strip() == "DATA-5200-foo", res.stdout

    def test_passthrough_for_sequential(self, patched_project: Path):
        """Get-FeatureName '001-user-auth' → '001-user-auth' (unchanged)."""
        common = patched_project / ".specify/scripts/powershell/common.ps1"
        res = _invoke_function(common, "Get-FeatureName -Branch '001-user-auth'")
        assert res.stdout.strip() == "001-user-auth", res.stdout

    def test_env_var_overrides_branch(self, patched_project: Path):
        """SPECIFY_FEATURE env var takes precedence over branch name."""
        common = patched_project / ".specify/scripts/powershell/common.ps1"
        res = _invoke_function(
            common,
            "Get-FeatureName -Branch 'feature/foo'",
            env={**os.environ, "SPECIFY_FEATURE": "override-branch"},
        )
        assert res.stdout.strip() == "override-branch", res.stdout


# ---------------------------------------------------------------------------
# Get-FeatureDir (patched to call Get-FeatureName)
# ---------------------------------------------------------------------------

class TestGetFeatureDir:
    def test_gitflow_branch_strips_prefix(self, patched_project: Path):
        """specs dir for 'feature/DATA-5200-foo' must be specs/DATA-5200-foo."""
        common = patched_project / ".specify/scripts/powershell/common.ps1"
        root = str(patched_project).replace("\\", "/")
        res = _invoke_function(
            common,
            f"Get-FeatureDir -RepoRoot '{root}' -Branch 'feature/DATA-5200-foo'",
        )
        assert res.stdout.strip().endswith("DATA-5200-foo"), (
            f"Expected path ending with DATA-5200-foo, got: {res.stdout.strip()!r}"
        )
        assert "feature" not in res.stdout.strip().split(os.sep)[-1], (
            f"'feature' should not appear in the leaf dir name: {res.stdout.strip()!r}"
        )

    def test_sequential_branch_unchanged(self, patched_project: Path):
        """Sequential branch '001-user-auth' maps to specs/001-user-auth."""
        common = patched_project / ".specify/scripts/powershell/common.ps1"
        root = str(patched_project).replace("\\", "/")
        res = _invoke_function(
            common,
            f"Get-FeatureDir -RepoRoot '{root}' -Branch '001-user-auth'",
        )
        assert res.stdout.strip().endswith("001-user-auth"), res.stdout


# ---------------------------------------------------------------------------
# create-new-feature.ps1 — Git Flow mode
# ---------------------------------------------------------------------------

class TestCreateNewFeatureGitFlow:
    def test_gitflow_creates_feature_git_branch(self, patched_project: Path):
        """-GitFlow creates git branch feature/<short-name>."""
        script = patched_project / ".specify/scripts/powershell/create-new-feature.ps1"
        res = _run_ps(patched_project, script, "-Json", "-GitFlow", "-ShortName", "DATA-5200-my-feat", "Add feature")
        assert res.returncode == 0, f"script failed:\n{res.stdout}\n{res.stderr}"
        data = json.loads(res.stdout)
        # BRANCH_NAME is the full git branch in GitFlow mode
        assert data["BRANCH_NAME"] == "feature/DATA-5200-my-feat", data

        branches = subprocess.run(
            ["git", "branch"], cwd=patched_project, capture_output=True, text=True
        )
        assert "feature/DATA-5200-my-feat" in branches.stdout, branches.stdout

    def test_gitflow_specs_dir_uses_shortname(self, patched_project: Path):
        """specs/<short-name>/ created — no nested feature/ directory."""
        script = patched_project / ".specify/scripts/powershell/create-new-feature.ps1"
        res = _run_ps(patched_project, script, "-Json", "-GitFlow", "-ShortName", "DP-99-ui-fix", "UI fix")
        assert res.returncode == 0, f"script failed:\n{res.stdout}\n{res.stderr}"
        data = json.loads(res.stdout)
        spec_file = Path(data["SPEC_FILE"])
        assert spec_file.parent.name == "DP-99-ui-fix", (
            f"Expected specs/DP-99-ui-fix, got: {spec_file.parent}"
        )

    def test_gitflow_no_sequential_prefix(self, patched_project: Path):
        """-GitFlow must not prepend a sequential number to the branch name."""
        script = patched_project / ".specify/scripts/powershell/create-new-feature.ps1"
        res = _run_ps(patched_project, script, "-GitFlow", "-ShortName", "DP-42-auth", "Auth feature")
        assert res.returncode == 0, f"script failed:\n{res.stdout}\n{res.stderr}"
        for line in res.stdout.splitlines():
            if line.startswith("BRANCH_NAME:"):
                name = line.split(":", 1)[1].strip()
                assert not re.match(r"^\d{3}-", name), f"unexpected numeric prefix: {name}"

    def test_gitflow_long_name_rejected(self, patched_project: Path):
        """-GitFlow with a name >244 bytes must exit non-zero."""
        script = patched_project / ".specify/scripts/powershell/create-new-feature.ps1"
        long_name = "A-" * 130
        res = _run_ps(patched_project, script, "-GitFlow", "-ShortName", long_name, "Feature")
        assert res.returncode != 0, "Expected non-zero exit for oversized name"


# ---------------------------------------------------------------------------
# create-new-feature.ps1 — Legacy sequential mode still works after patch
# ---------------------------------------------------------------------------

class TestCreateNewFeatureLegacy:
    def test_sequential_mode_unchanged(self, patched_project: Path):
        """Without -GitFlow, sequential branch naming still works."""
        script = patched_project / ".specify/scripts/powershell/create-new-feature.ps1"
        res = _run_ps(patched_project, script, "-Json", "-ShortName", "user-auth", "Add user auth")
        assert res.returncode == 0, f"script failed:\n{res.stdout}\n{res.stderr}"
        data = json.loads(res.stdout)
        assert re.match(r"^\d{3,}-user-auth$", data["BRANCH_NAME"]), (
            f"unexpected branch: {data['BRANCH_NAME']}"
        )

    def test_dryrun_flag_accepted(self, patched_project: Path):
        """Patched script still accepts -DryRun (upstream flag must be preserved)."""
        script = patched_project / ".specify/scripts/powershell/create-new-feature.ps1"
        res = _run_ps(patched_project, script, "-DryRun", "-Json", "-ShortName", "dry-test", "Dry run test")
        assert res.returncode == 0, f"-DryRun flag rejected:\n{res.stdout}\n{res.stderr}"
        data = json.loads(res.stdout)
        assert data.get("DRY_RUN") is True

    def test_timestamp_flag_accepted(self, patched_project: Path):
        """Patched script still accepts -Timestamp (upstream flag must be preserved)."""
        script = patched_project / ".specify/scripts/powershell/create-new-feature.ps1"
        res = _run_ps(patched_project, script, "-Json", "-Timestamp", "-ShortName", "ts-test", "Timestamp test")
        assert res.returncode == 0, f"-Timestamp flag rejected:\n{res.stdout}\n{res.stderr}"
        data = json.loads(res.stdout)
        assert re.match(r"^\d{8}-\d{6}-ts-test$", data["BRANCH_NAME"]), (
            f"unexpected timestamp branch: {data['BRANCH_NAME']}"
        )
