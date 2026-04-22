# Hook-Based Specify Workflow Proposal

**Status**: Proposal (parked)  
**Date**: 2026-04-08  
**Scope**: spec-cat customization of `/speckit.specify` and feature branch creation

## Summary

This proposal describes how spec-cat can reduce or eliminate the current post-init patching workflow used to customize `/speckit.specify` for Git Flow branch naming such as `feature/data-533-feature`.

The current approach works, but it is operationally fragile because it patches generated agent files after `speckit init`. When upstream wording changes, patch anchors drift and the failure appears in user projects during initialization.

The preferred direction is to move customization into first-class extension and command-override mechanisms already supported by Spec Kit, while preserving the ability to follow spec-cat's Git Flow naming and feature-directory rules.

## Current Problem

spec-cat forked from spec-kit to customize the `speckit.specify` workflow so users can:

1. Use Git Flow branch naming like `feature/<short-name>` instead of `NNN-short-name`.
2. Reuse an already matching current branch.
3. Use Jira-style short names directly for the spec directory when desired.

Today this is implemented by:

1. Running `specify init`.
2. Patching the generated `speckit.specify` agent file.
3. Patching supporting PowerShell scripts.

This creates three recurring problems:

1. Upstream template edits can break patch anchors.
2. Breakage is detected late, during `speckit init` in user projects.
3. The fork must keep reconciling text-level changes in generated prompts.

## What Changed Upstream

Recent upstream changes already moved part of the workflow in the right direction:

1. `speckit.specify` now recognizes `before_specify` hooks for branch creation.
2. Core `specify` now supports `SPECIFY_FEATURE_DIRECTORY` as an explicit feature-directory override.
3. Downstream scripts now resolve feature directories using this order:
   - `SPECIFY_FEATURE_DIRECTORY`
   - `.specify/feature.json`
   - branch-name fallback

This means spec-cat no longer needs to patch branch creation into the prompt from scratch. The remaining issue is how to communicate spec-cat-specific branch and feature-directory decisions cleanly into the core `specify` flow.

## Key Finding

Hooks alone are not sufficient today.

The current hook system is primarily a registration and invocation mechanism for AI-visible commands. It can:

1. Tell the agent to execute a hook command.
2. Mark hooks as optional or automatic.
3. Gate hooks with simple config or environment conditions.

It does not currently provide a structured return-value channel from `before_specify` back into core `speckit.specify`.

That means a hook can create or switch the branch, but it cannot reliably tell core `specify`:

1. which feature directory to use for this run,
2. whether the current branch was intentionally reused,
3. whether a Jira short name should map directly to `specs/<short-name>`.

As a result, a pure hooks-only solution is not available without an upstream contract change.

## Design Goals

Any replacement for the current patching approach should:

1. Eliminate post-init regex patching of generated files.
2. Fail in the spec-cat repo during sync or CI, not in user projects during init.
3. Keep spec-cat-specific behavior small and explicit.
4. Minimize divergence from upstream `specify.md`.
5. Preserve Git Flow branch naming and current-branch reuse.
6. Preserve compatibility with future upstream improvements.

## Options

### Option 1: Keep the Current Patching Model

This means retaining:

1. `cl-tools/patches/apply.ps1`
2. anchor-based snippet replacement
3. patch validation tests

Pros:

1. No architectural change.
2. Existing behavior is already implemented.

Cons:

1. Fragile against upstream prompt wording changes.
2. User-facing failures during init.
3. Ongoing maintenance cost is higher than the value of the customization itself.

Assessment: not recommended long term.

### Option 2: Pure Hooks and Extension Scripts Only

This would push everything into the git extension and `before_specify` hooks, with no `speckit.specify` override.

Pros:

1. Cleanest conceptual design.
2. No prompt override to maintain.

Cons:

1. Not fully possible with the current upstream hook contract.
2. Core `specify` has no structured way to consume hook-produced feature-directory decisions.

Assessment: desirable future state, but not achievable today without upstream change.

### Option 3: Hook Plus Thin `speckit.specify` Override

This moves branch creation and Git Flow behavior into an extension command, while keeping a very small override for `speckit.specify` that only adds the missing spec-cat-specific feature-directory behavior.

Pros:

1. Removes post-init patching.
2. Keeps customization explicit and deterministic.
3. Keeps most of the prompt aligned with upstream.
4. Fails in repo CI or sync workflows instead of end-user init.

Cons:

1. Still requires maintaining an override of `speckit.specify`.
2. That override can drift if maintained manually.

Assessment: best practical near-term option.

### Option 4: Upstream Hook Result Contract

This would add a generic mechanism to Spec Kit core so hooks can pass structured context into core commands, for example through a machine-readable file or defined environment variables.

Pros:

1. Would allow spec-cat to rely on hooks only.
2. Would eliminate the need for a `speckit.specify` override.
3. Useful beyond spec-cat.

Cons:

1. Requires upstream design and acceptance.
2. Cannot unblock spec-cat immediately.

Assessment: best long-term direction.

## Recommended Approach

Use Option 3 now, while designing toward Option 4.

That means:

1. Move Git Flow branch creation into an extension-owned command and hook.
2. Replace post-init patching with an install-time `speckit.specify` override.
3. Keep the override as thin as possible.
4. Explore an upstream hook-result contract later so the override can eventually be removed.

## Proposed Architecture

Introduce a spec-cat-specific workflow extension, for example:

```text
extensions/spec-cat-workflow/
  extension.yml
  commands/
    speckit.specify.md
    speckit.git.feature.md
  scripts/
    bash/create-new-feature.sh
    powershell/create-new-feature.ps1
  config-template.yml
```

Responsibilities:

### `speckit.git.feature`

This command becomes the owner of branch behavior for spec-cat:

1. Parse `short-name:` when present.
2. Create or reuse `feature/<short-name>`.
3. Preserve current-branch reuse logic.
4. Fall back to sequential or timestamp mode when no exact short name is provided.
5. Continue to support `GIT_BRANCH_NAME` internally if needed.

### `speckit.specify`

This override stays intentionally thin:

1. Keep the upstream `before_specify` hook model.
2. Keep upstream validation and checklist behavior.
3. Add the spec-cat rule that when a Jira-style short name is provided, the feature directory should resolve to `specs/<short-name>`.
4. Continue using the core `SPECIFY_FEATURE_DIRECTORY` and `.specify/feature.json` mechanisms.

## How to Avoid a Stale Override

The main risk with overriding `speckit.specify` is drift. The mitigation is to avoid hand-maintaining a full copy.

Recommended sync model:

1. Treat upstream `templates/commands/specify.md` as the base document.
2. Keep a very small spec-cat delta that describes only the custom behavior.
3. Generate the spec-cat override from base plus delta.
4. Commit the generated file.
5. Add CI that fails if regeneration changes the checked-in output.

This converts the problem from:

1. user-facing runtime patch failure,

to:

1. repository-facing sync-time drift detection.

That is a much better failure mode.

## Proposed Sync Workflow

When upstream `specify.md` changes:

1. Pull upstream changes into spec-cat.
2. Regenerate the spec-cat `speckit.specify` override from upstream base plus spec-cat delta.
3. Review the diff.
4. Run tests that validate:
   - init installs the override
   - `before_specify` still invokes the hook
   - Git Flow branch naming still works
   - feature directory resolution still works
5. Commit the regenerated override and any required delta updates.

This is still maintenance, but it is controlled maintenance instead of anchor chasing.

## Why This Is Better Than Patching

The proposed model improves reliability because:

1. It removes text-anchor patching from project initialization.
2. It uses first-class extension and command-override mechanisms already supported by the platform.
3. It makes spec-cat customization visible as normal source files instead of patch snippets.
4. It shifts failure detection into repo workflows and CI.

## Long-Term Upstream Improvement

The long-term simplification would be an upstream hook result contract.

Example shape:

1. A hook writes `.specify/hook-context.json`.
2. Core `speckit.specify` reads values such as:
   - `branch_name`
   - `feature_directory`
   - `feature_slug`
3. Core `speckit.specify` uses those values before auto-generating the feature directory.

If that existed, spec-cat could:

1. keep branch logic entirely inside hooks and extension scripts,
2. stop overriding `speckit.specify`,
3. rely on core prompt evolution with minimal or no fork-specific prompt ownership.

## Rollout Plan

### Phase 1

1. Design the new spec-cat workflow extension.
2. Move branch behavior into extension-owned `speckit.git.feature` command and scripts.
3. Add a thin `speckit.specify` override.

### Phase 2

1. Remove `cl-tools/patches/` from the init workflow.
2. Replace patch validation with override-generation validation.
3. Update docs to describe the new extension-based model.

### Phase 3

1. Propose upstream hook-result support.
2. Evaluate whether the `speckit.specify` override can be removed.

## Risks

### Risk: Override Drift

Mitigation:

1. Keep the override thin.
2. Generate it from upstream base plus delta.
3. Add CI checks.

### Risk: Partial Migration Increases Complexity

Mitigation:

1. Do not keep both patching and override systems long term.
2. Migrate in one controlled branch.
3. Remove patch code once the replacement path is validated.

### Risk: Upstream `specify` Semantics Change

Mitigation:

1. Regenerate on every upstream sync.
2. Keep tests focused on behavior, not exact wording.

## Decision

When this work is resumed, spec-cat should move away from post-init patching and toward:

1. extension-owned branch behavior,
2. a thin install-time `speckit.specify` override,
3. eventual upstream support for hook-to-core context handoff.

This is the best balance between maintainability, compatibility with upstream, and preserving spec-cat-specific Git Flow behavior.