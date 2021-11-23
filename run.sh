#!/bin/bash
#--------------------------------------------------------------------------------------------------
# Sample scipt to start new PostgreSQL as a container with the data volume 
#  but they cou be without content to generate default
#
#--------------------------------------------------------------------------------------------------

IMG_NAME=pgsql
IP2RUN=""                #-- set specific IP, sample: "10.1.1.35:" <- notice ':' at the end
VERBOSE=1                #-- 1 - be verbose flag
SVER="20211122"

#-- Check architecture
[[ $(uname -m) =~ ^armv7 ]] && ARCH="armv7-" || ARCH=""

source ./functions.sh #-- Use common functions

stop_container   $IMG_NAME
remove_container $IMG_NAME

docker run -d \
  --name $IMG_NAME \
  -p ${IP2RUN}5432:5432  \
  -v /you_data_dir/pgsql:/var/lib/postgresql \
  -e VERBOSE=${VERBOSE} \
  etaylashev/postgresql:${ARCH}latest
exit 0

