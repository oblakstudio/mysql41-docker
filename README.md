# oblakstudio/mysql41

[![MySQL Version](https://img.shields.io/badge/MySQL-4.1.11-00758F?logo=mysql&logoColor=white)](https://hub.docker.com/r/oblakstudio/mysql41)
[![Docker Image Version](https://img.shields.io/docker/v/oblakstudio/mysql41?sort=semver&logo=docker&logoColor=white&label=image&color=2496ED)](https://hub.docker.com/r/oblakstudio/mysql41/tags)
[![Docker Pulls](https://img.shields.io/docker/pulls/oblakstudio/mysql41?logo=docker&logoColor=white&color=2496ED)](https://hub.docker.com/r/oblakstudio/mysql41)
[![Docker Image Size](https://img.shields.io/docker/image-size/oblakstudio/mysql41/latest?logo=docker&logoColor=white&label=size&color=2496ED)](https://hub.docker.com/r/oblakstudio/mysql41/tags)
[![Release](https://img.shields.io/github/actions/workflow/status/oblakstudio/mysql41-docker/release.yml?branch=master&logo=githubactions&logoColor=white&label=release)](https://github.com/oblakstudio/mysql41-docker/actions/workflows/release.yml)
![Platform](https://img.shields.io/badge/platform-linux%2F386-2496ED?logo=docker&logoColor=white)
![Base](https://img.shields.io/badge/base-Debian%20Sarge%203.1-A81D33?logo=debian&logoColor=white)
![Maintenance](https://img.shields.io/maintenance/yes/2026)

---

Legacy **MySQL 4.1** (circa 2005) packaged for modern container workflows.

The image is built on **Debian Sarge (3.1)**, which ships MySQL 4.1 (`4.1.11a`) as the
`mysql-server-4.1` package — pulled from `archive.debian.org`. (Sarge is the last Debian stable
to carry 4.1; Etch moved to 5.0.) It is `linux/386` and runs natively on amd64 hosts via
Docker's multi-arch support. The entrypoint mirrors the official `mysql` image contract
(env-driven first-run init, `/docker-entrypoint-initdb.d`), adapted to MySQL 4.1's SQL dialect.

> [!WARNING]
> This is **end-of-life software** (4.1 last released in 2008) with known, unpatched security
> issues. It exists to resurrect legacy applications and data that still require MySQL 4.1 —
> run it on **trusted networks only**, never expose it to the public internet.

## Tags

The wrapped MySQL is a fixed upstream (4.1.11); image releases are versioned independently
with semantic versioning (driven by [semantic-release](https://semantic-release.gitbook.io/)).

| Tag | Description |
| --- | --- |
| `latest` | Newest image release |
| `4.1.11` | Wrapped upstream MySQL version (constant) |
| `X.Y.Z` | Exact image release (e.g. `1.0.0`) |
| `X.Y`, `X` | Moving image major.minor / major (e.g. `1.0`, `1`) |

All tags are MySQL 4.1.11 on Debian Sarge, `linux/386`.

## Quick start

```bash
docker run --rm -d --name mysql41 \
  -e MYSQL_ROOT_PASSWORD=secret \
  -p 3306:3306 \
  oblakstudio/mysql41
```

On amd64 hosts you can add `--platform=linux/386` (Docker usually infers it automatically).

## Environment variables

First-run initialization is controlled by these (same names as the official image):

| Variable | Description |
| --- | --- |
| `MYSQL_ROOT_PASSWORD` | Password for `root`. One of this / `ALLOW_EMPTY` / `RANDOM` is **required**. |
| `MYSQL_ALLOW_EMPTY_PASSWORD` | Set to any value to allow an empty root password (insecure). |
| `MYSQL_RANDOM_ROOT_PASSWORD` | Generate a random root password and print it to the log. |
| `MYSQL_DATABASE` | Name of a database to create on first run. |
| `MYSQL_USER` / `MYSQL_PASSWORD` | Create this user (both required) with full rights on `MYSQL_DATABASE`. |

Each variable also accepts a `*_FILE` form (e.g. `MYSQL_ROOT_PASSWORD_FILE`) for Docker secrets.

## Initialization scripts

Files placed in `/docker-entrypoint-initdb.d/` run **once, on first start** (empty data dir):

- `*.sql` — piped into the server
- `*.sql.gz` — decompressed and piped in
- `*.sh` — sourced

```bash
docker run -d -e MYSQL_ROOT_PASSWORD=secret \
  -v ./seed.sql:/docker-entrypoint-initdb.d/seed.sql \
  oblakstudio/mysql41
```

## Data persistence

The data directory is `/var/lib/mysql` (declared as a volume). Mount a named volume to persist
data; the entrypoint detects an existing data directory and skips re-initialization.

```bash
docker run -d -e MYSQL_ROOT_PASSWORD=secret -v mysql41data:/var/lib/mysql oblakstudio/mysql41
```

## Connecting — password hashing modes

MySQL 4.1 can store passwords in two formats, controlled by `old_passwords` in
[`my.cnf`](my.cnf). This image **defaults to `old_passwords = 1`** (the legacy pre-4.1 16-byte
hash) so it behaves like older 4.x servers and the data sources these images typically
resurrect.

> [!NOTE]
> With `old_passwords = 1`, modern clients (MySQL 8 CLI, some PHP/`mysqlnd` builds) may refuse
> to connect with a *secure auth* error because they expect the newer hash. Pass
> `--skip-secure-auth`:
>
> ```bash
> mysql -h127.0.0.1 -uroot -psecret --skip-secure-auth -e 'SELECT VERSION();'
> ```
>
> Note that MySQL 8's CLI dropped the pre-4.1 protocol entirely — use the **MariaDB client** (or
> an older `mysql` client) for `old_passwords = 1` accounts.

To use MySQL 4.1's native **41-byte SHA1 hash** instead (the format modern
`mysql_native_password` clients understand, so `--skip-secure-auth` is **not** needed), set
`old_passwords = 0` in `my.cnf` before first-run init.

### Character sets

MySQL 4.1 introduced real charset/collation support; the server defaults to **latin1**
(`latin1_swedish_ci`). When restoring a legacy dump that declares `DEFAULT CHARSET=latin1` and
carries no `SET NAMES`, restore with `--default-character-set=latin1` to preserve bytes exactly:

```bash
mysql -h127.0.0.1 -uroot -psecret --default-character-set=latin1 mydb < dump.sql
```

## Configuration

Server settings live in [`my.cnf`](my.cnf) (baked in at `/etc/mysql/my.cnf`). It binds
`0.0.0.0` so the server is reachable across the Docker network and points the socket, PID, and
datadir at the container paths. Override it by mounting your own file at the same path.

## Building from source

```bash
make build    # docker build --platform=linux/386 -t oblakstudio/mysql41 .
make run      # run locally for smoke testing (MYSQL_ROOT_PASSWORD=root)
make shell    # open a shell in the built image
make push     # publish :latest and :4.1.11 to Docker Hub
make help     # list all targets
```

Releases are automated in two stages:

- [`release.yml`](.github/workflows/release.yml) — on pushes to `master`,
  [semantic-release](https://semantic-release.gitbook.io/) derives the next image version from
  [Conventional Commits](https://www.conventionalcommits.org/) and cuts a GPG-signed **GitHub
  Release**.
- [`docker_build.yml`](.github/workflows/docker_build.yml) — when that release is published,
  `docker/metadata-action` + `docker/build-push-action` build with Buildx + QEMU and push the semver
  tags (plus `:latest` and `:4.1.11`) to Docker Hub, then `peter-evans/dockerhub-description` syncs
  this README into the Docker Hub repository description.

## How it works

MySQL 4.1 predates modern apt/yum repositories, so it **cannot be installed from current distro
package sources**. The image is based on `debian/eol:sarge-slim`, whose `sources.list` already
points at `archive.debian.org`, where `apt-get install mysql-server-4.1` resolves to
`4.1.11a-4sarge8`. Sarge's apt (0.5.x) does not do GPG secure-apt, so the unsigned archive repo
works as-is; a `policy-rc.d` returning `exit 101` keeps the package's postinst from auto-starting
the service during the build.

## Credits & License

Built and maintained by [Oblak Studio](https://oblak.studio). MySQL is a trademark of Oracle
Corporation; this image merely packages the long-released 4.1 server. The Dockerfile, entrypoint,
and workflows in this repository are released under the **MIT license**.
