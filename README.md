# oblakstudio/mysql40

Legacy **MySQL 4.0** (circa 2003) packaged for modern container workflows.

The image is built on **Debian Sarge (3.1)** — the last Debian release to ship MySQL 4.0
(`4.0.24`) — pulled from `archive.debian.org`. It is `linux/386` and runs natively on amd64
hosts via Docker's multi-arch support. The entrypoint mirrors the official `mysql` image
contract (env-driven first-run init, `/docker-entrypoint-initdb.d`), adapted to MySQL 4.0's
SQL dialect.

> Built for resurrecting legacy applications and data that still require MySQL 4.0. This is
> **end-of-life software** with known security issues — use it on trusted networks only.

## Usage

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

MySQL 4.0 predates the 4.1 authentication protocol and uses the **old 16-byte password hash**.
Modern clients (MySQL 8 CLI, some PHP/`mysqlnd` builds) may refuse to connect with a
*secure auth* error. Pass `--skip-secure-auth` (CLI) or enable `old_passwords` on the client
side:

```bash
mysql -h127.0.0.1 -uroot -psecret --skip-secure-auth -e 'SELECT VERSION();'
```

This is inherent to running MySQL 4.0, not a defect of the image.

## Build

```bash
make build    # docker build --platform=linux/386 -t oblakstudio/mysql40 .
make run      # run locally for smoke testing
make push     # publish :latest and :4.0.24 to Docker Hub
```
