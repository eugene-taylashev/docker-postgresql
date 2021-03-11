# Another PostgreSQL Docker image running on Alpine Linux

Docker has an [official image](https://hub.docker.com/_/postgres/) maintained by the [PostgreSQL Docker Community](https://github.com/docker-library/postgres). This variation is inspired by [onjin](https://github.com/onjin/docker-alpine-postgres).

## Intro

Brief description:
* The image uses Alpine:latest and related PostgreSQL packages. As compiled now they are v3.13.2 and v13.2.
* Non-privileged user id ``postgres`` is used to run the service. The user's UID/GID is adjustable. Default is 70. As compiled: ``uid=1002, gid=1002``
* Environment Variables have different usage then in the offical image:
  * ``POSTGRES_USER`` - This optional variable will create the specified user with superuser power.
  * ``POSTGRES_PASSWORD`` - manadatory password for ``POSTGRES_USER``
  * ``POSTGRES_DB`` - This variable will create the specified database and grant access to this database to ``POSTGRES_USER``
* Volume structure: ``/var/lib/postgresql`` - directory for configuration files and databases

## Usage

## Creating a new instance
It will create a new DB in the specified volume:
```
docker run -d \
  --name pgsql \
  -e VERBOSE=1 \
  -e POSTGRES_USER=eugene \
  -e POSTGRES_PASSWORD="Hard2Gue$$Password" \
  -e POSTGRES_DB=syslog \
  -p 5432:5432 \
  -v /data/postgresql:/var/lib/postgresql \
  etaylashev/postgresql
```
The ``entrypoint.sh`` script creates the following ``pg_hba.conf`` file:
```
# TYPE  DATABASE        USER            ADDRESS                 METHOD

# "local" is for Unix domain socket connections only
local   all             postgres                                trust
local   all             all                                     md5

# IPv4 connections:
host    all             all             0.0.0.0/0               md5
```

To logon as the default superuser ``postgres`` to the running container without a password:
```
docker exec -it <container_name> /usr/bin/psql -U postgres postgres
```

To logon as the created user to the specified DB with password:
```
docker exec -it <container_name> /usr/bin/psql -W -U <user_name> <created_db>
```

## Running an existing DB
To run the exitsting DB:
```
docker run -d \
  --name pgsql \
  -e VERBOSE=1 \
  -p 5432:5432 \
  -v /data/postgresql:/var/lib/postgresql \
  etaylashev/postgresql
```

To run it like a pod:
```
apiVersion: v1
kind: Pod
metadata:
  name: pgsql
  namespace: default
  labels:
    app: postgresql
    purpose: database
spec:
  volumes:
    - name: "pgsql-data"
      hostPath:
        path: "/data/postgresql/"
  containers:
    - name: pgsql
      image: etaylashev/postgresql
      env: 
        - name: VERBOSE
          value: "1"
      volumeMounts:
        - name: "pgsql-data"
          mountPath: "/var/lib/postgresql"
      ports:
        - containerPort: 5432
          protocol: TCP
```

## Backup DBs
See [documentation](https://www.postgresql.org/docs/13/backup.html). There are at least two options to backup:

1) Stop the container and backup related files from the volume:
```
tar czf my_pgsql-$(date "+%Y%m%d").tgz /data/postgresql/
```

2) Or backup DBs from the running container into a SQL file using ``pg_dump`` for a database or ``pg_dumpall`` for all:
```
docker exec  <container_name> /bin/sh -c "/sbin/su-exec postgres /usr/bin/pg_dumpall -w " >/backup/my_dbs.sql
```


## Restore DBs
See [documentation](https://www.postgresql.org/docs/13/backup.html)
1) Resotre files in the volume while the container is not ranning
2) Or run:
```
docker exec  <container_name> /bin/sh -c "/sbin/su-exec postgres /usr/bin/psql --set ON_ERROR_STOP=on -w " </backup/my_dbs.sql
```

