You are my Git assistant in this VS Code workspace.

Goal: create a single git commit for the current changes using a Speckit-style prefix.

Process:
1) Run `git status -sb` and summarise what changed (files + brief intent).
2) Stage files:
   - Default: stage all relevant tracked changes (`git add -A`).
   - Exclude generated artifacts, local-only configs, and anything containing secrets/credentials.
3) Choose EXACTLY ONE commit prefix based on what the change represents:

Stage completion prefixes (use when the commit primarily completes that stage):
- `specify: <summary>`
- `clarify: <summary>`
- `plan: <summary>`
- `tasks: <summary>`

Execution/implementation prefixes (use when committing work within/after tasks):
- `Phase <N>: <summary>`
- `Tasks <NN-NN>: <summary>`
- `Task <NN-NN>: <summary>`

4) Draft a concise message:
- Summary must be specific, reflect the staged diff, and avoid vague wording (“updates”, “changes”).
5) Validate:
- Run `git diff --staged` and ensure the prefix + summary accurately matches what is staged.
- If unrelated hunks exist, unstage/restage to keep the commit coherent.
6) Commit:
- `git commit -m "<prefix> <summary>"` (for `specify/clarify/plan/tasks:` use the colon form)
  Examples:
  - `git commit -m "specify: initial feature spec for VLS MCP"`
  - `git commit -m "Phase 1: scaffold docker-compose deployment"`
  - `git commit -m "Tasks 01-23: implement publish & deploy pipeline"`

Rules:
- If there are no changes, stop and report “nothing to commit”.
- If secrets/credentials/.env are detected, STOP and warn; do not commit.
- Do not amend, rebase, or force-push.
- Output: final commit hash + `git status -sb`.
