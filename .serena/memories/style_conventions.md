# Style & conventions

- Bash scripts use `#!/bin/bash`, `set -e` (not always `-u`/`-o pipefail`).
- Functions are declared with `name() { ... }` and 4-space indentation is common.
- Environment variables are uppercase with underscores.
- Paths resolved via `SCRIPT_DIR`/`PROJECT_ROOT` patterns.
