# tools/

This directory is for user-managed tools (for example, repositories you `git clone`) that you want to bring into the container environment.

- Repo-relative path: `tools/`
- Container absolute path: `/opt/sandbox/tools`

Because the repository root `.` is mounted to `/opt/sandbox` via `docker-compose.yml`, anything placed under `tools/` on the host becomes available at `/opt/sandbox/tools` inside the container.

Notes:
- `tools/` is not meant to be tracked in Git (it is ignored via `.gitignore`). This `README.md` is tracked only to document the path.
