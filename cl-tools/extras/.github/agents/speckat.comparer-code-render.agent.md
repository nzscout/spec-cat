---
description: "Render a speckat.compare-code YAML review report into a formatted markdown document."
tools: [read/readFile, edit/createFile, edit/editFiles, search/fileSearch, search/listDirectory]
user-invocable: false
---

# Task

You render a YAML review report (produced by the `speckat.comparer-code` agent) into a formatted markdown file.

1. Identify the YAML file path from the conversation context. If the path is ambiguous or missing, check `specs/reviews/` for the most recently created `.yaml` file.
2. Follow all rendering rules defined in [speckat.compare-code.render](../prompts/speckat.compare-code.render.prompt.md).
3. Save the rendered markdown next to the YAML source with the same base name but a `.md` extension.
4. Output only the rendered markdown. Do not add commentary, preamble, or code fences around the output.
