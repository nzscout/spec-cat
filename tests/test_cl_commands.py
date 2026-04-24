import json
from types import SimpleNamespace

import yaml

from specify_cli.agents import CommandRegistrar
import specify_cli.cl_commands as cl_commands
from specify_cli.cl_commands import _claude_extra_skill_name, _copy_extras, _iter_cl_prompt_extras, _render_claude_extra_skill


class TestClaudeClExtras:
    def test_render_claude_skill_from_agent_backed_prompt(self):
        prompt_path = next(
            path for path in _iter_cl_prompt_extras() if path.name == "speckat.compare-code.prompt.md"
        )

        content = _render_claude_extra_skill(prompt_path)
        frontmatter, _ = CommandRegistrar.parse_frontmatter(content)

        assert frontmatter["name"] == "speckat-compare-code"
        assert frontmatter["user-invocable"] is True
        assert frontmatter["disable-model-invocation"] is False
        assert frontmatter["argument-hint"] == "<team-cl-feature-dir> <team-cp-feature-dir> [canonical-base-branch] [product-doc-path]..."
        assert "# Persona and core behavior" in content
        assert "## User Input" in content

    def test_skill_name_rewrites_dots_to_hyphens(self):
        prompt_path = next(
            path for path in _iter_cl_prompt_extras() if path.name == "speckat.git-commit.prompt.md"
        )

        assert _claude_extra_skill_name(prompt_path) == "speckat-git-commit"

    def test_copy_extras_installs_claude_skills_when_claude_selected(self, tmp_path):
        specify_dir = tmp_path / ".specify"
        specify_dir.mkdir()
        (specify_dir / "init-options.json").write_text(
            json.dumps({"ai": "claude"}), encoding="utf-8"
        )

        copied, updated, missing = _copy_extras(tmp_path, dry_run=False)

        assert missing == 0
        assert copied > 0
        assert updated == 0
        assert (tmp_path / ".claude" / "skills" / "speckat-compare-code" / "SKILL.md").exists()

    def test_apply_patches_tolerates_missing_copilot_agent_for_claude(self, monkeypatch, tmp_path):
        scripts_dir = tmp_path / ".specify" / "scripts" / "powershell"
        scripts_dir.mkdir(parents=True)
        (scripts_dir / "common.ps1").write_text(
            "function Get-FeatureName {}\n(?:feature|feat)/\nGet-FeatureName -Branch\n",
            encoding="utf-8",
        )
        (scripts_dir / "create-new-feature.ps1").write_text(
            "[switch]$GitFlow\n\"feature/$ShortName\"\n",
            encoding="utf-8",
        )

        monkeypatch.setattr(
            cl_commands.subprocess,
            "run",
            lambda *args, **kwargs: SimpleNamespace(returncode=1),
        )

        assert cl_commands._apply_patches(tmp_path, dry_run=False, ai="claude") == 0

    def test_apply_patches_keeps_failure_when_required_scripts_missing(self, monkeypatch, tmp_path):
        monkeypatch.setattr(
            cl_commands.subprocess,
            "run",
            lambda *args, **kwargs: SimpleNamespace(returncode=1),
        )

        assert cl_commands._apply_patches(tmp_path, dry_run=False, ai="claude") == 1
