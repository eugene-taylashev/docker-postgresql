#!/bin/sh
set -e

#=============================================================================
#
#  Variable declarations
#
#=============================================================================
SVER="20211122"         #-- Updated by Eugene Taylashev

#-- External variables by docker run
#VERBOSE=1              	#-- 1 - be verbose flag, defined outside of the script
#POSTGRES_ROOT_PASSWORD=""  #-- optional password for user postgres
#POSTGRES_DB=""				#-- additional DB
#POSTGRES_USER=""			#-- additional user with superuser power
#POSTGRES_PASSWORD=""		#-- password for the user POSTGRES_USER

USR="postgres"
DIR_RUN="/run/postgresql"
DIR_DB="/var/lib/postgresql/data"

source /functions.sh  #-- Use common funcations

#=============================================================================
#
#  MAIN()
#
#=============================================================================
dlog '============================================================================='
dlog "[ok] - starting entrypoint.sh ver $SVER"

#-- get additional information
get_container_details
dlog "[ok] - User details (uid,gid):"
id $USR
locale

#-----------------------------------------------------------------------------
# Work with PostgreSQL
#-----------------------------------------------------------------------------

if [ ! -d $DIR_RUN ]; then
    dlog "[ok] -  $DIR_RUN does not exist, creating...."
    mkdir -p $DIR_RUN
    chown -R $USR:$USR $DIR_RUN
else
    dlog "[ok] - $DIR_RUN exists"
fi
chown -R $USR:$USR $DIR_RUN


#-- Create new Database, if needed
if [ ! -d $DIR_DB ]; then
    dlog "[ok] - PostgreSQL data directory not found, creating initial DBs"

    mkdir -p $DIR_DB
    chown -R $USR:$USR $DIR_DB
    chmod 0700 $DIR_DB
    dlog "[ok] - created directory $DIR_DB with right permission"

    PGDATA=$DIR_DB

    #-- create new database
    dlog "[ok] - initializing a new database"
    eval su-exec $USR initdb --locale=en_US.UTF-8 -E UTF8 -D $DIR_DB

	#-- modify the access file
    cat << EOC > "$DIR_DB/pg_hba.conf"
# TYPE  DATABASE        USER            ADDRESS                 METHOD

# "local" is for Unix domain socket connections only
local   all             postgres                                trust
local   all             all                                     md5

# IPv4 connections:
host    all             all             0.0.0.0/0               md5
EOC

	POSTGRES_DB=${POSTGRES_DB:-""}
	POSTGRES_USER=${POSTGRES_USER:-""}
	POSTGRES_PASSWORD=${POSTGRES_PASSWORD:-""}

    TFILE=`mktemp`
    if [ ! -f "$TFILE" ]; then
        return 1
    fi
	chmod 644 $TFILE

    #-- start the server for additional configuration
    eval su-exec $USR pg_ctl -D $DIR_DB -w start

	#-- create a DB if specified
	if [ "z$POSTGRES_DB" != "z" -a "$POSTGRES_DB" != "postgres" ] ; then
		eval su-exec $USR createdb $POSTGRES_DB --no-password
		dlog "[ok] - created a DB '$POSTGRES_DB' with right permission"
	fi

    #-- create a user if specified
    if [ "z$POSTGRES_USER" != "z" -a "$POSTGRES_USER" != "$USR" ] ; then
        eval su-exec $USR createuser  --login \
             --createrole --superuser --inherit "$POSTGRES_USER" \
             --no-password;
        dlog "[ok] - created a user '$POSTGRES_USER' with supervisor permission"

		#-- create a password for the user
		if [ "$POSTGRES_PASSWORD" != "" ] ; then
			echo "ALTER USER \"$POSTGRES_USER\" WITH PASSWORD '$POSTGRES_PASSWORD';" >>$TFILE
			dlog "[ok] - assigned the specified password to user '$POSTGRES_USER'"
		else
			dlog "[not ok] - user '$POSTGRES_USER' has no password assigned"
		fi

		#-- Grant access to the specified DB
		if [ "z$POSTGRES_DB" != "z" -a "$POSTGRES_DB" != "postgres" ] ; then
			echo "REVOKE ALL ON DATABASE \"$POSTGRES_DB\" FROM public;" >>$TFILE
			echo "GRANT CONNECT ON DATABASE \"$POSTGRES_DB\" TO \"$POSTGRES_USER\";" >>$TFILE
			echo "GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO \"$POSTGRES_USER\";" >>$TFILE
			echo "GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO \"$POSTGRES_USER\";" >>$TFILE
			dlog "[ok] - grant access to '$POSTGRES_DB' TO '$POSTGRES_USER'"
		fi
    else 
		dlog "[ok] - no additional user was specified. Use local $USR"
	fi

	#-- create a password for the superuser $USR
	if [ "z$POSTGRES_ROOT_PASSWORD" != "z" ] ; then
		echo "ALTER USER \"$USR\" WITH PASSWORD '$POSTGRES_ROOT_PASSWORD';" >>$TFILE
		dlog "[ok] - assigned the specified password to user $USR"
	else
		dlog "[not ok] - user $POSTGRES_USER has no password assigned"
	fi

	#-- run SQL commands from file $TFILE
	eval su-exec $USR psql -f $TFILE
	rm -f $TFILE

    #-- stop the temporary server
    eval su-exec $USR pg_ctl -D $DIR_DB -w stop

else
    chown -R $USR:$USR $DIR_DB
    dlog "[ok] - data directory $DIR_DB exists, skipping creation"
fi

dlog "[ok] - exec postgres -D $DIR_DB -i -d 0 $@"
exec su-exec $USR postgres -D "$DIR_DB" -i -d 0 $@

dlog "[not ok] - end of the entrypoint.sh"
