# oblakstudio/mysql40

[![MySQL Version](https://img.shields.io/badge/MySQL-4.0.24-00758F?logo=mysql&logoColor=white)](https://hub.docker.com/r/oblakstudio/mysql40)
[![Docker Image Version](https://img.shields.io/docker/v/oblakstudio/mysql40?sort=semver&logo=docker&logoColor=white&label=image&color=2496ED)](https://hub.docker.com/r/oblakstudio/mysql40/tags)
[![Docker Pulls](https://img.shields.io/docker/pulls/oblakstudio/mysql40?logo=docker&logoColor=white&color=2496ED)](https://hub.docker.com/r/oblakstudio/mysql40)
[![Docker Image Size](https://img.shields.io/docker/image-size/oblakstudio/mysql40/latest?logo=docker&logoColor=white&label=size&color=2496ED)](https://hub.docker.com/r/oblakstudio/mysql40/tags)
[![Build & Publish](https://img.shields.io/github/actions/workflow/status/oblakstudio/mysql40/build.yml?branch=main&logo=githubactions&logoColor=white&label=build)](https://github.com/oblakstudio/mysql40/actions/workflows/build.yml)
![Platform](https://img.shields.io/badge/platform-linux%2F386-2496ED?logo=docker&logoColor=white)
![Base](https://img.shields.io/badge/base-Debian%20Sarge%203.1-A81D33?logo=debian&logoColor=white)
![Maintenance](https://img.shields.io/maintenance/yes/2026)

---

Legacy **MySQL 4.0** (circa 2003) packaged for modern container workflows.

The image is built on **Debian Sarge (3.1)** — the last Debian release to ship MySQL 4.0
(`4.0.24`) — pulled from `archive.debian.org`. It is `linux/386` and runs natively on amd64
hosts via Docker's multi-arch support. The entrypoint mirrors the official `mysql` image
contract (env-driven first-run init, `/docker-entrypoint-initdb.d`), adapted to MySQL 4.0's
SQL dialect.

> [!WARNING]
> This is **end-of-life software** (last released in 2008) with known, unpatched security
> issues. It exists to resurrect legacy applications and data that still require MySQL 4.0 —
> run it on **trusted networks only**, never expose it to the public internet.

## Tags

| Tag | Description |
| --- | --- |
| `latest`, `4.0.24` | MySQL 4.0.24 on Debian Sarge, `linux/386` |

## Quick start

```bash
docker run --rm -d --name mysql40 \
  -e MYSQL_ROOT_PASSWORD=secret \
  -p 3306:3306 \
  oblakstudio/mysql40
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
  oblakstudio/mysql40
```

## Data persistence

The data directory is `/var/lib/mysql` (declared as a volume). Mount a named volume to persist
data; the entrypoint detects an existing data directory and skips re-initialization.

```bash
docker run -d -e MYSQL_ROOT_PASSWORD=secret -v mysql40data:/var/lib/mysql oblakstudio/mysql40
```

## Connecting — old password hashing caveat

> [!NOTE]
> MySQL 4.0 predates the 4.1 authentication protocol and uses the **old 16-byte password hash**.
> Modern clients (MySQL 8 CLI, some PHP/`mysqlnd` builds) may refuse to connect with a
> *secure auth* error.

Pass `--skip-secure-auth` (CLI) or enable `old_passwords` on the client side:

```bash
mysql -h127.0.0.1 -uroot -psecret --skip-secure-auth -e 'SELECT VERSION();'
```

This is inherent to running MySQL 4.0, not a defect of the image.

## Configuration

Server settings live in [`my.cnf`](my.cnf) (baked in at `/etc/mysql/my.cnf`). It binds
`0.0.0.0` so the server is reachable across the Docker network and points the socket, PID, and
datadir at the container paths. Override it by mounting your own file at the same path.

## Building from source

```bash
make build    # docker build --platform=linux/386 -t oblakstudio/mysql40 .
make run      # run locally for smoke testing (MYSQL_ROOT_PASSWORD=root)
make shell    # open a shell in the built image
make push     # publish :latest and :4.0.24 to Docker Hub
make help     # list all targets
```

CI ([`.github/workflows/build.yml`](.github/workflows/build.yml)) builds with Buildx + QEMU and
publishes `:latest` and `:4.0.24` to Docker Hub on pushes to `main` and `v*` tags.

## How it works

MySQL 4.0 predates modern apt/yum repositories, so it **cannot be installed from current distro
package sources**. The image is based on `debian/eol:sarge-slim`, whose `sources.list` already
points at `archive.debian.org`, where `apt-get install mysql-server` resolves to
`4.0.24-10sarge3`. Sarge's apt (0.5.x) does not do GPG secure-apt, so the unsigned archive repo
works as-is; a `policy-rc.d` returning `exit 101` keeps the package's postinst from auto-starting
the service during the build.

## Credits & License

Built and maintained by [Oblak Studio](https://oblak.studio). MySQL is a trademark of Oracle
Corporation; this image merely packages the long-released 4.0 server. The Dockerfile, entrypoint,
and workflows in this repository are released under the **MIT license**.
