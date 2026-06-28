# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What This Project Is

A Docker image that packages **legacy MySQL 4.0** (circa 2003) for use in modern container
workflows, published publicly to Docker Hub as **`oblakstudio/mysql40`**.

The work is almost entirely **shell + Docker**: a Dockerfile, an entrypoint/init script, a
Makefile wrapping the build/run/push flow, and CI to publish images. There is no application
code beyond container plumbing.

## Repository Layout

- `Dockerfile` — `FROM debian/eol:sarge-slim`, installs MySQL 4.0.24 from `archive.debian.org`.
- `docker-entrypoint.sh` — official-`mysql`-style env-driven init, written for **bash 2.05b**
  (Sarge's shell — no `pipefail`, no `${!var}` indirection; use `eval`).
- `my.cnf` — server config; binds `0.0.0.0` and sets the socket/datadir.
- `Makefile` — `build` / `run` / `shell` / `push` / `clean`.
- `.github/workflows/build.yml` — buildx publish to Docker Hub (`linux/386`).

## Key Architectural Constraint

MySQL 4.0 predates modern apt/yum repositories, so it **cannot be installed from current
distro package sources**. The image is based on **Debian Sarge (3.1)** — the last Debian
release to ship MySQL 4.0 — via the `debian/eol:sarge-slim` image, whose `sources.list`
already points at `archive.debian.org`. `apt-get install mysql-server` there resolves to
`4.0.24-10sarge3`. Sarge's apt (0.5.x) does **not** do GPG secure-apt, so unsigned repos work;
a `policy-rc.d` returning `exit 101` keeps the postinst from auto-starting the service during
the build. The image is `linux/386` (32-bit-era release) and runs on amd64 hosts.

## Build & Run

```bash
make build                    # docker build --platform=linux/386 -t oblakstudio/mysql40 .
make run                      # run locally for smoke testing (MYSQL_ROOT_PASSWORD=root)
make shell                    # shell into the image
make push                     # publish :latest and :4.0.24 to Docker Hub
```

Note: MySQL 4.0 uses the pre-4.1 password hash; modern clients may need `--skip-secure-auth`.
See `README.md` for env vars (`MYSQL_ROOT_PASSWORD`, `MYSQL_DATABASE`, etc.) and details.

## Shell Command Safety

`cp`, `mv`, `rm` may be aliased to interactive `-i` mode and will hang an agent waiting for
y/n input. Always use non-interactive forms: `rm -f` / `rm -rf`, `cp -f` / `cp -rf`,
`mv -f`. For network commands use `apt-get -y`, `ssh -o BatchMode=yes`,
`scp -o BatchMode=yes`.

## Git Remote Status

There is currently **no git remote** configured — commits and beads issues are local only.
The `bd dolt push` / `git push` steps in the session protocol below apply once a remote exists.

<!-- BEGIN BEADS INTEGRATION v:1 profile:minimal hash:ca08a54f -->
## Beads Issue Tracker

This project uses **bd (beads)** for issue tracking. Run `bd prime` to see full workflow context and commands.

### Quick Reference

```bash
bd ready              # Find available work
bd show <id>          # View issue details
bd update <id> --claim  # Claim work
bd close <id>         # Complete work
```

### Rules

- Use `bd` for ALL task tracking — do NOT use TodoWrite, TaskCreate, or markdown TODO lists
- Run `bd prime` for detailed command reference and session close protocol
- Use `bd remember` for persistent knowledge — do NOT use MEMORY.md files

## Session Completion

**When ending a work session**, you MUST complete ALL steps below. Work is NOT complete until `git push` succeeds.

**MANDATORY WORKFLOW:**

1. **File issues for remaining work** - Create issues for anything that needs follow-up
2. **Run quality gates** (if code changed) - Tests, linters, builds
3. **Update issue status** - Close finished work, update in-progress items
4. **PUSH TO REMOTE** - This is MANDATORY:
   ```bash
   git pull --rebase
   bd dolt push
   git push
   git status  # MUST show "up to date with origin"
   ```
5. **Clean up** - Clear stashes, prune remote branches
6. **Verify** - All changes committed AND pushed
7. **Hand off** - Provide context for next session

**CRITICAL RULES:**
- Work is NOT complete until `git push` succeeds
- NEVER stop before pushing - that leaves work stranded locally
- NEVER say "ready to push when you are" - YOU must push
- If push fails, resolve and retry until it succeeds
<!-- END BEADS INTEGRATION -->
