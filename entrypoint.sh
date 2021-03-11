#!/bin/sh
set -e

#=============================================================================
#
#  Variable declarations
#
#=============================================================================
SVER="20210310"         #-- Updated by Eugene Taylashev

#-- External variables by docker run
#VERBOSE=1              #-- 1 - be verbose flag, defined outside of the script
#POSTGRES_USER="postgres"
#POSTGRES_PASSWORD=""  #-- if empty for new installation - will be generated randomly
#POSTGRES_DB="postgres"

USR="postgres"
DIR_RUN="/run/postgresql"
DIR_DB="/var/lib/postgresql/data"


#=============================================================================
#
#  Function declarations
#
#=============================================================================
#-----------------------------------------------------------------------------
#  Output debugging/logging message
#------------------------------------------------------------------------------
dlog(){
  MSG="$1"
  local TSMP=$(date -Iseconds)
#  echo "$MSG" >>$FLOG
  [ $VERBOSE -eq 1 ] && echo "$TSMP $MSG"
}
# function dlog


#-----------------------------------------------------------------------------
#  Output error message
#------------------------------------------------------------------------------
derr(){
  MSG="$1"
  local TSMP=$(date -Iseconds)
#  echo "$MSG" >>$FLOG
  echo "$TSMP $MSG"
}
# function derr

#-----------------------------------------------------------------------------
#  Output good or bad message based on return status $?
#------------------------------------------------------------------------------
is_good(){
    STATUS=$?
    MSG_GOOD="$1"
    MSG_BAD="$2"
    
    if [ $STATUS -eq 0 ] ; then
        dlog "${MSG_GOOD}"
    else
        derr "${MSG_BAD}"
    fi
}
# function is_good

#-----------------------------------------------------------------------------
#  Output important parametrs of the container 
#------------------------------------------------------------------------------
get_container_details(){
    
    if [ $VERBOSE -eq 1 ] ; then
        echo '[ok] - getting container details:'
        echo '---------------------------------------------------------------------'

        #-- for Linux Alpine
        if [ -f /etc/alpine-release ] ; then
            OS_REL=$(cat /etc/alpine-release)
            echo "Alpine $OS_REL"
            apk -v info | sort
        fi

        uname -a
        ip address
        echo '---------------------------------------------------------------------'
    fi
}
# function get_container_details


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

    #-- start the server for additional configuration
    eval su-exec $USR pg_ctl -D $DIR_DB -w start

    #-- create a user, not 
    if [ "z$POSTGRES_USER" != "z" -a "$POSTGRES_USER" != "$USR" ] ; then
        eval su-exec $USR createuser --createdb --login \
             --createrole --superuser --inherit "$POSTGRES_USER" \
             --no-password;
        dlog "[ok] - created a user $POSTGRES_USER with supervisor permission"

		#-- create a DB
		if [ "z$POSTGRES_DB" != "z" ] ; then
			eval su-exec $USR createdb $POSTGRES_DB --owner="$POSTGRES_USER" --no-password
			dlog "[ok] - created a DB $POSTGRES_DB with right permission"
		else 
			dlog "[not ok] - user $POSTGRES_USER has no directory to access"
		fi

		#-- create a password for the user
		if [ "z$POSTGRES_PASSWORD" != "z" ] ; then
			TMP=./temp1.sql
			echo "ALTER USER $POSTGRES_USER WITH PASSWORD '$POSTGRES_PASSWORD';" >$TMP
			eval su-exec $USR psql -f $TMP
			rm $TMP
			dlog "[ok] - assigned the specified password to user $POSTGRES_USER"
		else
			dlog "[not ok] - user $POSTGRES_USER has no password assigned"
		fi

    else 
		dlog "[ok] - no user was specified. Use local $USR"
	fi


    #-- stop the temporary server
    eval su-exec $USR pg_ctl -D $DIR_DB -w stop

else
    chown -R $USR:$USR $DIR_DB
    dlog "[ok] - data directory $DIR_DB exists, skipping creation"
fi

dlog "[ok] - exec postgres -D $DIR_DB -i -d 0 $@"
exec su-exec $USR postgres -D "$DIR_DB" -i -d 0 $@

dlog "[not ok] - end of the entrypoint.sh"