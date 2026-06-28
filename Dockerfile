# Legacy MySQL 4.0 (circa 2003) packaged for modern container workflows.
#
# MySQL 4.0 predates modern package repositories, so it cannot be installed from
# current distro sources. We base on Debian Sarge (3.1) — the last release to ship
# MySQL 4.0 (4.0.24) — and pull it from archive.debian.org. The debian/eol image is
# already linux/386 with sources.list pointed at the archive.
FROM debian/eol:sarge-slim

# Sarge's apt (0.5.x) does not do GPG secure-apt, so unsigned archive repos are fine.
# Check-Valid-Until is disabled defensively in case apt ever tightens.
RUN echo 'Acquire::Check-Valid-Until "false";' > /etc/apt/apt.conf.d/99no-check-valid

ENV DEBIAN_FRONTEND=noninteractive

# Stop the mysql-server postinst from auto-starting the service during install
# (no init system in a build container — it would error and abort the build).
RUN printf '#!/bin/sh\nexit 101\n' > /usr/sbin/policy-rc.d \
    && chmod +x /usr/sbin/policy-rc.d

# Install MySQL 4.0.24 (mysql-server pulls mysql-client + mysql-common).
RUN apt-get update \
    && apt-get install -y mysql-server \
    && rm -rf /var/lib/apt/lists/*

# The postinst bootstraps a datadir in the image layer; wipe it so first-run init
# happens at runtime against the (possibly volume-mounted) /var/lib/mysql.
RUN rm -rf /var/lib/mysql/* \
    && mkdir -p /var/run/mysqld \
    && chown -R mysql:mysql /var/lib/mysql /var/run/mysqld

COPY my.cnf /etc/mysql/my.cnf
COPY docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh
RUN chmod +x /usr/local/bin/docker-entrypoint.sh \
    && mkdir -p /docker-entrypoint-initdb.d

EXPOSE 3306
VOLUME /var/lib/mysql

ENTRYPOINT ["docker-entrypoint.sh"]
CMD ["mysqld"]
