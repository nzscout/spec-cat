2. **Branch creation** (Git Flow override + current-branch reuse):

  This step overrides the default hook-only branch guidance when exact Git Flow naming is required.

  a. First, check if the user is **already on a matching feature branch**:
    - Run `git rev-parse --abbrev-ref HEAD` to get the current branch name
    - If the current branch ends with the `<short-name>` (matching patterns like `feature/<short-name>`, `<any-prefix>/<short-name>`, or just `<short-name>`), then the branch already exists and the user intends to work on it:
      - **Do NOT create a new branch** — stay on the current branch
      - **Do NOT run `create-new-feature.ps1`**
      - Derive `BRANCH_NAME` from the current branch
      - If the user provided `short-name:`, set `SPECIFY_FEATURE_DIRECTORY` to `specs/<short-name>` before continuing to step 3
      - Continue to step 3 so the spec directory and files are created there
    - If the current branch does **not** match, proceed with branch creation below

  b. Fetch all remote branches to ensure the branch check uses current refs:

    ```bash
    git fetch --all --prune
    ```

  c. **If a `short-name` was provided (Git Flow mode)**:
    - Run the script with the `-GitFlow` flag to create a `feature/<short-name>` branch:

      ```powershell
      .specify/scripts/powershell/create-new-feature.ps1 -Json -GitFlow -ShortName "<short-name>" "<feature description>"
      ```

    - Example: if the user provides `short-name: DATA-5200-Feature-name`, run:

      ```powershell
      .specify/scripts/powershell/create-new-feature.ps1 -Json -GitFlow -ShortName "DATA-5200-Feature-name" "Add user authentication"
      ```

    - This creates git branch `feature/DATA-5200-Feature-name`
    - Set `SPECIFY_FEATURE_DIRECTORY` to `specs/<short-name>` before continuing to step 3 so the spec folder matches the Jira-style short name exactly
    - No sequential numbering is applied — the provided short name is used as-is

  d. **If no `short-name` was provided (legacy/sequential mode)**:
    - Check `.specify/init-options.json` for `branch_numbering` value
    - Determine the next available branch number and run the script:

      ```powershell
      # Sequential (default):
      .specify/scripts/powershell/create-new-feature.ps1 -Json -ShortName "user-auth" "<feature description>"

      # Timestamp mode (if branch_numbering == "timestamp"):
      .specify/scripts/powershell/create-new-feature.ps1 -Json -Timestamp -ShortName "user-auth" "<feature description>"
      ```

    - Let step 3 keep its default feature-directory resolution in legacy mode

  **IMPORTANT**:
  - Always check the current branch first before attempting to create a new one — if it already matches the short-name, reuse it
  - You must only ever run the create script once per feature, and only if the branch does not already exist
  - Always include the JSON flag and use the script output as the source of truth for `BRANCH_NAME`
  - If the default `before_specify` hook already created a non-matching branch, switch to the correct Git Flow branch produced by the script and continue with that branch
  - Step 3 remains responsible for creating the spec directory and spec file
  - For single quotes in args like "I'm Groot", use escape syntax: e.g 'I'\''m Groot' (or double-quote if possible: "I'm Groot")
