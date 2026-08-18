# Token-efficient codebase navigation

- Start repository discovery with `list_projects`/`index_status`, then prefer the codebase-memory-mcp index over broad filesystem reads.
- Use `get_architecture` for structure; `search_graph` or `search_code` for symbols/code; and `trace_path`, `query_graph`, or `detect_changes` for dependencies, call paths, and impact.
- Identify relevant symbols and files in the index before opening source, then use `get_code_snippet` for the smallest useful symbol. Read a whole source file only when whole-file context is genuinely needed.
- Use `check_index_coverage` on evidence paths; fall back to targeted `rg` or source reads for reported gaps, non-code/config text, or insufficient index results.
- Do not re-read unchanged files already inspected. Prefer targeted searches and concise diffs.
- Keep build/test output bounded: save full noisy output to a temporary log when useful, return only relevant failures/warnings or a short tail, and inspect more only as needed. Do not repeat identical output.
- Use normal Codex tools directly for tiny one-off reads when an MCP call would add unnecessary overhead.
