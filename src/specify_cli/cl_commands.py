"""CL-specific speckit wrapper commands.

Provides the ``speckit`` CLI with a single ``speckit init`` command that runs
``specify init --here --force --ai copilot`` and then applies CL patches and
copies extras — all in one step.

Design notes:
- This file is new; it never modifies ``__init__.py`` or any upstream file, so
  it can never produce a merge conflict during upstream syncs.
- Tools are located via ``_find_cl_root()``, which checks two places:
    1. ``specify_cli/cl_pack/``  — present in wheel installs (bundled via
       ``force-include`` in ``pyproject.toml``)
    2. ``<fork-root>/cl-tools/`` — present in source-checkout runs
"""

import shutil
import subprocess
from pathlib import Path

import typer
from rich.console import Console

app = typer.Typer(
    name="speckit",
    help="CL speckit workflow commands.",
    add_completion=False,
)
console = Console()


# ---------------------------------------------------------------------------
# Internals
# ---------------------------------------------------------------------------

def _find_cl_root() -> Path:
    """Locate the CL tools root.

    In a wheel install: ``specify_cli/cl_pack/`` (sibling of this file).
    In a source checkout: ``<fork-root>/cl-tools/``.
    """
    wheel_pack = Path(__file__).parent / "cl_pack"
    if wheel_pack.is_dir():
        return wheel_pack

    source_root = Path(__file__).parent.parent.parent / "cl-tools"
    if source_root.is_dir():
        return source_root

    raise RuntimeError(
        "CL tools directory not found.\n"
        "Expected 'specify_cli/cl_pack/' (wheel install) or 'cl-tools/' "
        "(fork source checkout).\n"
        "Re-install specify-cli from the CL fork: "
        "uv tool install specify-cli --force --from git+https://github.com/your-org/spec-kit.git"
    )


def _apply_patches(project_root: Path, dry_run: bool) -> int:
    patch_script = _find_cl_root() / "patches" / "apply.ps1"
    cmd = ["pwsh", "-File", str(patch_script), "-ProjectRoot", str(project_root)]
    if dry_run:
        cmd.append("-WhatIf")
    return subprocess.run(cmd, cwd=str(project_root)).returncode


def _copy_extras(project_root: Path, dry_run: bool) -> tuple[int, int, int]:
    extras_root = _find_cl_root() / "extras"
    entries = [
        ".github/agents/speckit.comparer-code.agent.md",
        ".github/agents/speckit.comparer-spec.agent.md",
        ".github/agents/speckit.reviewer-code.agent.md",
        ".github/agents/context7.agent.md",
        ".github/prompts/speckit.reconcile-code.prompt.md",
        ".github/prompts/speckit.reconcile-spec.prompt.md",
        ".github/prompts/speckat.bootstrap-worktrees.prompt.md",
        ".github/prompts/speckat.git-commit.prompt.md",
        ".specify/memory/constitution.dotnet.md",
        ".specify/memory/go-constitution.md",
    ]

    copied = skipped = missing = 0
    for entry in entries:
        src = extras_root / Path(entry)
        dst = project_root / Path(entry)

        if not src.exists():
            console.print(f"  [yellow][WARN] source not found: extras/{entry}[/yellow]")
            missing += 1
            continue

        if dst.exists():
            console.print(f"  [dim][SKIP] {entry}[/dim]")
            skipped += 1
            continue

        if dry_run:
            console.print(f"  [cyan][DRY]  {entry} (would copy)[/cyan]")
        else:
            dst.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(src, dst)
            console.print(f"  [green][OK]   {entry}[/green]")
        copied += 1

    return copied, skipped, missing


# ---------------------------------------------------------------------------
# Commands
# ---------------------------------------------------------------------------

@app.command()
def init(
    project_root: str  = typer.Option(".", "--root", "-r", help="Project root (defaults to CWD)"),
    dry_run: bool      = typer.Option(False, "--dry-run", "-n", help="Preview without writing files"),
    skip_extras: bool  = typer.Option(False, "--skip-extras", help="Skip extras copy (use on re-inits)"),
) -> None:
    """Run specify init then apply CL patches and extras in one step."""
    root = Path(project_root).resolve()

    console.rule("[bold cyan]speckit init[/bold cyan]")

    # Phase 1 — specify init
    console.print()
    console.print("[bold]Phase 1 — specify init --here --force --ai copilot[/bold]")
    specify_cmd = ["specify", "init", "--here", "--force", "--ai", "copilot"]
    if dry_run:
        console.print(f"  [dim][DRY] would run: {' '.join(specify_cmd)}[/dim]")
    else:
        rc = subprocess.run(specify_cmd, cwd=str(root)).returncode
        if rc != 0:
            console.print(f"[red]specify init failed (exit {rc})[/red]")
            raise typer.Exit(rc)

    # Phase 2 — patches
    console.print()
    console.print("[bold]Phase 2 — patches[/bold]")
    rc = _apply_patches(root, dry_run=dry_run)
    if rc != 0:
        console.print("[red]Patch phase failed — see warnings above.[/red]")
        raise typer.Exit(rc)

    # Phase 3 — extras
    console.print()
    if skip_extras:
        console.print("[dim]Phase 3 — extras (skipped via --skip-extras)[/dim]")
    else:
        console.print("[bold]Phase 3 — extras[/bold]")
        copied, skipped, missing = _copy_extras(root, dry_run=dry_run)
        console.print(f"  {copied} copied, {skipped} already existed, {missing} sources missing")

    console.rule("[bold green]Done[/bold green]")


# ---------------------------------------------------------------------------
# verify
# ---------------------------------------------------------------------------

@app.command()
def verify(
    project_root: str = typer.Option(".", "--root", "-r", help="Project root (defaults to CWD)"),
) -> None:
    """Verify that CL patches and extras were correctly applied to this project.

    Checks landmark strings in the deployed PowerShell scripts (confirming
    patches ran) and presence of extra agent/prompt files.  Exits 1 if any
    check fails so the command can be used in CI or as a post-init smoke test.
    """
    root = Path(project_root).resolve()

    console.rule("[bold cyan]speckit verify[/bold cyan]")
    console.print(f"Project root: {root}")
    console.print()

    checks: list[tuple[str, bool, str]] = []

    # --- common.ps1 patch landmarks -----------------------------------------
    common_ps1 = root / ".specify" / "scripts" / "powershell" / "common.ps1"
    if common_ps1.exists():
        text = common_ps1.read_text(encoding="utf-8")
        checks.append((
            "common.ps1 — Get-FeatureName function inserted",
            "function Get-FeatureName" in text,
            str(common_ps1),
        ))
        checks.append((
            "common.ps1 — feature/ branch pattern in Test-FeatureBranch",
            "^feature/" in text,
            str(common_ps1),
        ))
        checks.append((
            "common.ps1 — Get-FeatureDir delegates to Get-FeatureName",
            "Get-FeatureName -Branch" in text,
            str(common_ps1),
        ))
    else:
        for label in (
            "common.ps1 — Get-FeatureName function inserted",
            "common.ps1 — feature/ branch pattern in Test-FeatureBranch",
            "common.ps1 — Get-FeatureDir delegates to Get-FeatureName",
        ):
            checks.append((label, False, f"File not found: {common_ps1}"))

    # --- create-new-feature.ps1 patch landmarks -----------------------------
    create_ps1 = root / ".specify" / "scripts" / "powershell" / "create-new-feature.ps1"
    if create_ps1.exists():
        text = create_ps1.read_text(encoding="utf-8")
        checks.append((
            "create-new-feature.ps1 — -GitFlow switch present",
            "[switch]$GitFlow" in text,
            str(create_ps1),
        ))
        checks.append((
            "create-new-feature.ps1 — feature/ prefix assignment present",
            '"feature/$ShortName"' in text,
            str(create_ps1),
        ))
    else:
        for label in (
            "create-new-feature.ps1 — -GitFlow switch present",
            "create-new-feature.ps1 — feature/ prefix assignment present",
        ):
            checks.append((label, False, f"File not found: {create_ps1}"))

    # --- extra agent / prompt files -----------------------------------------
    extras = [
        ".github/agents/speckit.reviewer-code.agent.md",
        ".github/agents/speckit.comparer-code.agent.md",
        ".github/agents/speckit.comparer-spec.agent.md",
        ".github/agents/context7.agent.md",
    ]
    for rel in extras:
        path = root / rel
        checks.append((f"Extra present: {rel}", path.exists(), str(path)))

    # --- Print results -------------------------------------------------------
    passed = 0
    failed = 0
    for label, ok, detail in checks:
        if ok:
            console.print(f"  [green][PASS][/green] {label}")
            passed += 1
        else:
            console.print(f"  [red][FAIL][/red] {label}")
            console.print(f"         [dim]{detail}[/dim]")
            failed += 1

    console.print()
    if failed == 0:
        console.rule(f"[bold green]All {passed} checks passed[/bold green]")
    else:
        console.rule(f"[bold red]{failed} of {passed + failed} checks failed[/bold red]")
        raise typer.Exit(1)


def main() -> None:
    app()


if __name__ == "__main__":
    main()
