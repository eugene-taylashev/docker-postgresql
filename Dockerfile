FROM alpine:latest

ARG BUILD_DATE
ENV USER=postgres
#-- Default UID/GID -> 70
ENV UID=1002
ENV VERBOSE=0 
ENV DIR_DATA=/var/lib/postgresql

#-- Run parameters
#ENV VERBOSE=1              	#-- 1 - be verbose flag, defined outside of the script
#ENV POSTGRES_ROOT_PASSWORD=""  #-- optional password for the superuser postgres
#ENV POSTGRES_DB=""		#-- additional DB
#ENV POSTGRES_USER=""		#-- additional user with superuser power
#ENV POSTGRES_PASSWORD=""	#-- password for the user POSTGRES_USER

LABEL maintainer="Eugene Taylashev" \
    postgresql-version="13.5" \
    alpine-version="3.14.2" \
    build="2021-11-22" \
    org.opencontainers.image.title="alpine-postgresql" \
    org.opencontainers.image.description="Minimal PostgreSQL image based on Alpine Linux" \
    org.opencontainers.image.authors="Eugene Taylashev" \
    org.opencontainers.image.version="v13.5" \
    org.opencontainers.image.url="https://hub.docker.com/r/etaylashev/postgresql" \
    org.opencontainers.image.source="https://github.com/eugene-taylashev/docker-postgresql" \
    org.opencontainers.image.created=$BUILD_DATE

#-- Create a user for PostgreSQL
RUN set -eux; \
    mkdir -p "$DIR_DATA"; \
    addgroup --gid $UID "$USER"; \
    adduser \
      --disabled-password \
      --ingroup "$USER" \
      -H -h "$DIR_DATA" \
      --shell /bin/sh \
      --uid "$UID" \
      "$USER";

#-- Install main packages
RUN set -eux; \
    apk add --no-cache postgresql postgresql-contrib su-exec; \
    rm -f /var/cache/apk/*

#-- Set timezone and locale
RUN set -eux; \
    apk add --no-cache tzdata musl-locales musl-locales-lang; \
    rm -f /var/cache/apk/*

ENV TZ America/Toronto
ENV LANG en_US.UTF-8
ENV LANGUAGE en_US.UTF-8
ENV LC_ALL en_US.UTF-8

RUN set -eux; \
    cp /usr/share/zoneinfo/America/Toronto /etc/localtime; \
    echo "America/Toronto" >  /etc/timezone; \
    apk del tzdata;

COPY ./entrypoint.sh ./functions.sh /

EXPOSE 5432
STOPSIGNAL SIGINT
VOLUME ["$DIR_DATA"]

ENTRYPOINT ["/entrypoint.sh"]
