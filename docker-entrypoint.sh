#!/bin/bash
# Entrypoint for oblakstudio/mysql41 — mirrors the official `mysql` image contract
# (env-driven first-run init, /docker-entrypoint-initdb.d) adapted to MySQL 4.1's
# SQL dialect (no CREATE USER — added in 5.0; users are created via GRANT).
# Sarge ships bash 2.05b — no `pipefail`; keep to portable constructs.
set -e

MYSQLD=/usr/sbin/mysqld
DATADIR=/var/lib/mysql
SOCKET=/var/run/mysqld/mysqld.sock

log() { echo "[entrypoint] $*"; }
err() { echo "[entrypoint] ERROR: $*" >&2; exit 1; }

# Reads VAR or VAR_FILE (Docker-secret style); they are mutually exclusive.
# Uses eval rather than ${!var} indirection for bash 2.05b compatibility.
file_env() {
	local var="$1" fileVar="${1}_FILE" def="${2:-}"
	local varVal fileVarVal val
	eval "varVal=\${$var:-}"
	eval "fileVarVal=\${$fileVar:-}"
	if [ -n "$varVal" ] && [ -n "$fileVarVal" ]; then
		err "both $var and $fileVar are set (they are exclusive)"
	fi
	val="$def"
	if [ -n "$varVal" ]; then
		val="$varVal"
	elif [ -n "$fileVarVal" ]; then
		val="$(cat "$fileVarVal")"
	fi
	export "$var"="$val"
	unset "$fileVar"
}

# SQL-escape a single-quoted string value (double up backslashes and quotes).
sql_escape() { printf '%s' "$1" | sed -e 's/\\/\\\\/g' -e "s/'/''/g"; }
# Escape an identifier wrapped in backticks.
ident_escape() { printf '%s' "$1" | sed 's/`/``/g'; }

docker_init_database() {
	file_env MYSQL_ROOT_PASSWORD
	file_env MYSQL_DATABASE
	file_env MYSQL_USER
	file_env MYSQL_PASSWORD

	if [ -z "$MYSQL_ROOT_PASSWORD" ] \
		&& [ -z "${MYSQL_ALLOW_EMPTY_PASSWORD:-}" ] \
		&& [ -z "${MYSQL_RANDOM_ROOT_PASSWORD:-}" ]; then
		err "database is uninitialized and no root password is set. Set one of MYSQL_ROOT_PASSWORD, MYSQL_ALLOW_EMPTY_PASSWORD, or MYSQL_RANDOM_ROOT_PASSWORD."
	fi
	if [ -n "${MYSQL_RANDOM_ROOT_PASSWORD:-}" ] && [ -z "$MYSQL_ROOT_PASSWORD" ]; then
		MYSQL_ROOT_PASSWORD="$(head -c 24 /dev/urandom | od -An -tx1 | tr -d ' \n')"
	fi

	log "initializing system tables in $DATADIR"
	mkdir -p "$DATADIR"
	chown -R mysql:mysql "$DATADIR"
	mysql_install_db --user=mysql --datadir="$DATADIR" >/dev/null

	log "starting temporary server for bootstrap"
	"$MYSQLD" --user=mysql --skip-networking --socket="$SOCKET" &
	local pid="$!"

	local i
	for i in $(seq 1 30); do
		if mysqladmin --socket="$SOCKET" ping >/dev/null 2>&1; then
			break
		fi
		[ "$i" = 30 ] && err "temporary server failed to start"
		sleep 1
	done

	# Bootstrap SQL — root currently has no password, connect over the socket.
	local rootpw db user pass
	rootpw="$(sql_escape "$MYSQL_ROOT_PASSWORD")"
	{
		echo "DELETE FROM mysql.user WHERE User='';"
		echo "DELETE FROM mysql.db WHERE Db='test' OR Db='test\\_%';"
		echo "DROP DATABASE IF EXISTS test;"
		# Allow root over TCP from any host (dev container convenience).
		echo "GRANT ALL PRIVILEGES ON *.* TO 'root'@'%' IDENTIFIED BY '${rootpw}' WITH GRANT OPTION;"
		echo "UPDATE mysql.user SET Password=PASSWORD('${rootpw}') WHERE User='root';"

		if [ -n "$MYSQL_DATABASE" ]; then
			db="$(ident_escape "$MYSQL_DATABASE")"
			echo "CREATE DATABASE IF NOT EXISTS \`${db}\`;"
		fi
		if [ -n "$MYSQL_USER" ] && [ -n "$MYSQL_PASSWORD" ]; then
			user="$(sql_escape "$MYSQL_USER")"
			pass="$(sql_escape "$MYSQL_PASSWORD")"
			if [ -n "$MYSQL_DATABASE" ]; then
				db="$(ident_escape "$MYSQL_DATABASE")"
				echo "GRANT ALL PRIVILEGES ON \`${db}\`.* TO '${user}'@'%' IDENTIFIED BY '${pass}';"
			else
				echo "GRANT USAGE ON *.* TO '${user}'@'%' IDENTIFIED BY '${pass}';"
			fi
		elif [ -n "$MYSQL_USER" ] || [ -n "$MYSQL_PASSWORD" ]; then
			log "WARNING: MYSQL_USER and MYSQL_PASSWORD must both be set to create a user; skipping."
		fi
		echo "FLUSH PRIVILEGES;"
	} | mysql --socket="$SOCKET" --user=root

	if [ -n "${MYSQL_RANDOM_ROOT_PASSWORD:-}" ]; then
		log "GENERATED ROOT PASSWORD: $MYSQL_ROOT_PASSWORD"
	fi

	# Process /docker-entrypoint-initdb.d (root password is now set).
	process_init_files

	log "shutting down temporary server"
	mysqladmin --socket="$SOCKET" --user=root --password="$MYSQL_ROOT_PASSWORD" shutdown
	wait "$pid" 2>/dev/null || true
	log "initialization complete"
}

process_init_files() {
	local f
	for f in /docker-entrypoint-initdb.d/*; do
		[ -e "$f" ] || continue
		case "$f" in
			*.sh)
				log "running $f"; . "$f" ;;
			*.sql)
				log "applying $f"; mysql --socket="$SOCKET" --user=root --password="$MYSQL_ROOT_PASSWORD" < "$f" ;;
			*.sql.gz)
				log "applying $f"; gunzip -c "$f" | mysql --socket="$SOCKET" --user=root --password="$MYSQL_ROOT_PASSWORD" ;;
			*)
				log "ignoring $f" ;;
		esac
	done
}

main() {
	# Only run init logic when launching the server.
	if [ "${1:0:6}" != "mysqld" ] && [ "$1" != "$MYSQLD" ]; then
		exec "$@"
	fi

	mkdir -p /var/run/mysqld
	chown -R mysql:mysql /var/run/mysqld "$DATADIR" 2>/dev/null || true

	if [ ! -d "$DATADIR/mysql" ]; then
		docker_init_database
	else
		log "existing data directory found in $DATADIR — skipping initialization"
	fi

	log "starting mysqld"
	exec "$@" --user=mysql
}

main "$@"
