"""CL-specific speckit wrapper commands.

Provides the ``speckit`` CLI with a single ``speckit init`` command that runs
``specify init --here --force --ai <assistant>`` and then applies CL patches and
copies CL extras — all in one step.

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

    raise FileNotFoundError(
        "Could not locate bundled CL tools (cl_pack in wheel) or cl-tools/ "
        "(fork source checkout).\n"
        "Re-install specify-cli from the CL fork: "
        "uv tool install specify-cli --force --from git+https://github.com/your-org/spec-kit.git"
    )


def _common_ps1_has_gitflow_pattern(text: str) -> bool:
    """Return True when common.ps1 includes the CL Git Flow branch check."""
    return "(?:feature|feat)/" in text or "feature/<feature-name>" in text


def _cl_extras_root() -> Path:
    return _find_cl_root() / "extras"


def _iter_cl_prompt_extras() -> list[Path]:
    prompts_dir = _cl_extras_root() / ".github" / "prompts"
    if not prompts_dir.is_dir():
        return []
    return sorted(path for path in prompts_dir.iterdir() if path.is_file() and path.name.endswith(".prompt.md"))


def _extra_skill_name(prompt_path: Path) -> str:
    prompt_name = prompt_path.name.removesuffix(".prompt.md")
    return prompt_name.replace(".", "-")


def _claude_extra_skill_name(prompt_path: Path) -> str:
    return _extra_skill_name(prompt_path)


def _should_install_skill_extras(project_root: Path, agent_key: str) -> bool:
    from specify_cli import load_init_options

    init_options = load_init_options(project_root)
    selected_ai = init_options.get("ai") if isinstance(init_options, dict) else None
    selected_integration = init_options.get("integration") if isinstance(init_options, dict) else None

    if agent_key == "claude":
        return (
            selected_ai == "claude"
            or selected_integration == "claude"
            or (project_root / ".claude" / "skills").exists()
        )

    if agent_key == "codex":
        return (
            selected_ai == "codex"
            or selected_integration == "codex"
            or (project_root / ".agents" / "skills").exists()
        )

    return False


def _should_install_claude_extras(project_root: Path) -> bool:
    return _should_install_skill_extras(project_root, "claude")


def _should_install_codex_extras(project_root: Path) -> bool:
    return _should_install_skill_extras(project_root, "codex")


def _skill_extras_dir(project_root: Path, agent_key: str) -> Path:
    if agent_key == "claude":
        return project_root / ".claude" / "skills"
    if agent_key == "codex":
        return project_root / ".agents" / "skills"
    raise ValueError(f"Unsupported skill extras agent: {agent_key}")


def _render_skill_extra(prompt_path: Path, agent_key: str) -> str:
    from specify_cli.agents import CommandRegistrar
    from specify_cli.integrations import get_integration

    registrar = CommandRegistrar()
    prompt_text = prompt_path.read_text(encoding="utf-8")
    prompt_frontmatter, prompt_body = registrar.parse_frontmatter(prompt_text)

    sections: list[str] = []
    agent_name = prompt_frontmatter.get("agent") if isinstance(prompt_frontmatter, dict) else None
    if isinstance(agent_name, str) and agent_name and agent_name != "agent":
        agent_path = _cl_extras_root() / ".github" / "agents" / f"{agent_name}.agent.md"
        if agent_path.exists():
            agent_text = agent_path.read_text(encoding="utf-8")
            _, agent_body = registrar.parse_frontmatter(agent_text)
            if agent_body.strip():
                sections.append(agent_body.strip())

    if prompt_body.strip():
        sections.append(prompt_body.strip())

    skill_name = _extra_skill_name(prompt_path)
    description = ""
    if isinstance(prompt_frontmatter, dict):
        description = str(prompt_frontmatter.get("description") or "").strip()
    if not description:
        description = f"CL extra prompt: {skill_name}"

    skill_frontmatter = registrar.build_skill_frontmatter(
        "claude",
        skill_name,
        description,
        f"cl-tools/extras/.github/prompts/{prompt_path.name}",
    )
    skill_content = registrar.render_frontmatter(skill_frontmatter) + "\n" + "\n\n".join(sections).strip() + "\n"

    integration = get_integration(agent_key)
    if integration is None:
        raise ValueError(f"Integration not registered: {agent_key}")
    skill_content = integration.post_process_skill_content(skill_content)

    argument_hint = prompt_frontmatter.get("argument-hint") if isinstance(prompt_frontmatter, dict) else None
    if (
        agent_key == "claude"
        and isinstance(argument_hint, str)
        and argument_hint.strip()
        and hasattr(integration, "inject_argument_hint")
    ):
        skill_content = integration.inject_argument_hint(skill_content, argument_hint.strip())

    return skill_content


def _render_claude_extra_skill(prompt_path: Path) -> str:
    return _render_skill_extra(prompt_path, "claude")


def _render_codex_extra_skill(prompt_path: Path) -> str:
    return _render_skill_extra(prompt_path, "codex")


def _install_skill_extras(project_root: Path, dry_run: bool, agent_key: str) -> tuple[int, int]:
    if not _should_install_skill_extras(project_root, agent_key):
        return 0, 0

    skills_dir = _skill_extras_dir(project_root, agent_key)
    created = updated = 0

    for prompt_path in _iter_cl_prompt_extras():
        skill_name = _extra_skill_name(prompt_path)
        skill_file = skills_dir / skill_name / "SKILL.md"
        is_update = skill_file.exists()
        rel_path = skill_file.relative_to(project_root)

        if dry_run:
            label = "[DRY-U]" if is_update else "[DRY]  "
            console.print(f"  [cyan]{label} {rel_path.as_posix()} (would {'overwrite' if is_update else 'create'})[/cyan]")
        else:
            skill_file.parent.mkdir(parents=True, exist_ok=True)
            skill_file.write_text(_render_skill_extra(prompt_path, agent_key), encoding="utf-8")
            label = "[UP]  " if is_update else "[OK]  "
            console.print(f"  [green]{label} {rel_path.as_posix()}[/green]")

        if is_update:
            updated += 1
        else:
            created += 1

    return created, updated


def _install_claude_extras(project_root: Path, dry_run: bool) -> tuple[int, int]:
    return _install_skill_extras(project_root, dry_run, "claude")


def _install_codex_extras(project_root: Path, dry_run: bool) -> tuple[int, int]:
    return _install_skill_extras(project_root, dry_run, "codex")


def _has_required_script_patches(project_root: Path) -> bool:
    common_ps1 = project_root / ".specify" / "scripts" / "powershell" / "common.ps1"
    create_ps1 = project_root / ".specify" / "scripts" / "powershell" / "create-new-feature.ps1"

    if not common_ps1.exists() or not create_ps1.exists():
        return False

    common_text = common_ps1.read_text(encoding="utf-8")
    create_text = create_ps1.read_text(encoding="utf-8")
    return all((
        "function Get-FeatureName" in common_text,
        _common_ps1_has_gitflow_pattern(common_text),
        "Get-FeatureName -Branch" in common_text,
        "[switch]$GitFlow" in create_text,
        '"feature/$ShortName"' in create_text,
    ))


def _apply_patches(project_root: Path, dry_run: bool, ai: str) -> int:
    patch_script = _find_cl_root() / "patches" / "apply.ps1"
    cmd = ["pwsh", "-File", str(patch_script), "-ProjectRoot", str(project_root)]
    if dry_run:
        cmd.append("-WhatIf")
    rc = subprocess.run(cmd, cwd=str(project_root)).returncode
    if rc == 0 or dry_run or ai == "copilot":
        return rc

    specify_agent = project_root / ".github" / "agents" / "speckit.specify.agent.md"
    if not specify_agent.exists() and _has_required_script_patches(project_root):
        console.print("[yellow]Patch phase skipped Copilot-only agent patches for non-Copilot init.[/yellow]")
        return 0

    return rc


def _copy_extras(project_root: Path, dry_run: bool) -> tuple[int, int, int]:
    extras_root = _cl_extras_root()

    copied = skipped = 0
    for src in sorted(extras_root.rglob("*")):
        if src.is_dir():
            continue
        rel = src.relative_to(extras_root)
        dst = project_root / rel
        is_update = dst.exists()

        if dry_run:
            label = "[DRY-U]" if is_update else "[DRY]  "
            console.print(f"  [cyan]{label} {rel} (would {'overwrite' if is_update else 'copy'})[/cyan]")
        else:
            dst.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(src, dst)
            label = "[UP]  " if is_update else "[OK]  "
            console.print(f"  [green]{label} {rel}[/green]")
        if is_update:
            skipped += 1  # reuse skipped counter as "updated" for summary
        else:
            copied += 1

    claude_created, claude_updated = _install_claude_extras(project_root, dry_run=dry_run)
    copied += claude_created
    skipped += claude_updated

    codex_created, codex_updated = _install_codex_extras(project_root, dry_run=dry_run)
    copied += codex_created
    skipped += codex_updated

    return copied, skipped, 0


# ---------------------------------------------------------------------------
# Commands
# ---------------------------------------------------------------------------

@app.command()
def init(
    project_root: str  = typer.Option(".", "--root", "-r", help="Project root (defaults to CWD)"),
    dry_run: bool      = typer.Option(False, "--dry-run", "-n", help="Preview without writing files"),
    skip_extras: bool  = typer.Option(False, "--skip-extras", help="Skip extras copy (use on re-inits)"),
    ai: str            = typer.Option("copilot", "--ai", help="AI assistant for specify init (copilot, claude, or codex)"),
) -> None:
    """Run specify init then apply CL patches and extras in one step."""
    root = Path(project_root).resolve()

    console.rule("[bold cyan]speckit init[/bold cyan]")

    # Phase 1 — specify init
    console.print()
    console.print(f"[bold]Phase 1 — specify init --here --force --ai {ai}[/bold]")
    specify_cmd = ["specify", "init", "--here", "--force", "--ai", ai]
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
    rc = _apply_patches(root, dry_run=dry_run, ai=ai)
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
        console.print(f"  {copied} new, {skipped} updated")

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
            _common_ps1_has_gitflow_pattern(text),
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

    # --- extra files (derived dynamically from the extras/ folder) ----------
    extras_root = _cl_extras_root()
    for src in sorted(extras_root.rglob("*")):
        if src.is_dir():
            continue
        rel = src.relative_to(extras_root)
        path = root / rel
        checks.append((f"Extra present: {rel}", path.exists(), str(path)))

    # --- Claude skill extras (when Claude skills are present) ----------------
    claude_skills_dir = root / ".claude" / "skills"
    if claude_skills_dir.exists():
        for prompt_path in _iter_cl_prompt_extras():
            skill_name = _claude_extra_skill_name(prompt_path)
            skill_path = claude_skills_dir / skill_name / "SKILL.md"
            checks.append((
                f"Claude extra present: .claude/skills/{skill_name}/SKILL.md",
                skill_path.exists(),
                str(skill_path),
            ))

    # --- Codex skill extras (when Codex skills are present) ------------------
    codex_skills_dir = root / ".agents" / "skills"
    if codex_skills_dir.exists():
        for prompt_path in _iter_cl_prompt_extras():
            skill_name = _extra_skill_name(prompt_path)
            skill_path = codex_skills_dir / skill_name / "SKILL.md"
            checks.append((
                f"Codex extra present: .agents/skills/{skill_name}/SKILL.md",
                skill_path.exists(),
                str(skill_path),
            ))

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
