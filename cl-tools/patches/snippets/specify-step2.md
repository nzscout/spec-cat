2. **Create the feature branch and spec folder**:

   a. First, check if the user is **already on a matching feature branch**:
      - Run `git rev-parse --abbrev-ref HEAD` to get the current branch name
      - If the current branch ends with the `<short-name>` (matching patterns like `feature/<short-name>`, `<any-prefix>/<short-name>`, or just `<short-name>`), then the branch already exists and the user intends to work on it:
        - **Do NOT create a new branch** — stay on the current branch
        - **Do NOT run `create-new-feature.ps1`**
        - Derive BRANCH_NAME from the current branch (the `<short-name>` portion)
        - Set SPEC_FILE to `specs/<short-name>/spec.md`
        - Create the `specs/<short-name>/` directory if it does not exist
        - Copy `.specify/templates/spec-template.md` to `specs/<short-name>/spec.md` if the spec file does not exist yet
        - Skip to step 3
      - If the current branch does **not** match, proceed with branch creation below

   b. Fetch all remote branches to ensure we have the latest information:

      ```bash
      git fetch --all --prune
      ```

   c. **If a `short-name` was provided (Git Flow mode)**:
      - Run the script with the `-GitFlow` flag to create a `feature/<short-name>` branch and `specs/<short-name>/` folder:

        ```powershell
        .specify/scripts/powershell/create-new-feature.ps1 -Json -GitFlow -ShortName "<short-name>" "<feature description>"
        ```

      - Example: if the user provides `short-name: DATA-5200-Feature-name`, run:

        ```powershell
        .specify/scripts/powershell/create-new-feature.ps1 -Json -GitFlow -ShortName "DATA-5200-Feature-name" "Add user authentication"
        ```

      - This creates git branch `feature/DATA-5200-Feature-name` and spec folder `specs/DATA-5200-Feature-name/`
      - No sequential numbering is applied — the name is used as-is

   d. **If no `short-name` was provided (legacy/sequential mode)**:
      - Check `.specify/init-options.json` for `branch_numbering` value
      - Find the highest feature number across all sources for the short-name:
        - Remote branches: `git ls-remote --heads origin | grep -E 'refs/heads/[0-9]+-<short-name>$'`
        - Local branches: `git branch | grep -E '^[* ]*[0-9]+-<short-name>$'`
        - Specs directories: Check for directories matching `specs/[0-9]+-<short-name>`
      - Determine the next available number (N+1) and run the script:

        ```powershell
        # Sequential (default):
        .specify/scripts/powershell/create-new-feature.ps1 -Json -ShortName "user-auth" "<feature description>"

        # Timestamp mode (if branch_numbering == "timestamp"):
        .specify/scripts/powershell/create-new-feature.ps1 -Json -Timestamp -ShortName "user-auth" "<feature description>"
        ```

   **IMPORTANT**:
   - Always check the current branch first before attempting to create a new one — if it already matches the short-name, reuse it
   - Check all three sources (remote branches, local branches, specs directories) to find the highest number (legacy mode only)
   - Only match branches/directories with the exact short-name pattern (legacy mode only)
   - If no existing branches/directories found with this short-name, start with number 1 (legacy mode only)
   - You must only ever run the create script once per feature, and only if the branch doesn't already exist
   - The JSON is provided in the terminal as output - always refer to it to get the actual content you're looking for
   - The JSON output will contain BRANCH_NAME and SPEC_FILE paths
   - For single quotes in args like "I'm Groot", use escape syntax: e.g 'I'\''m Groot' (or double-quote if possible: "I'm Groot")
