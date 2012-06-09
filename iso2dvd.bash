#! /bin/bash

#=======================================================================
#
# iso2dvd.bash (See description below).
# Copyright (C) 2012  Marcelo Javier Auquer
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program. If not, see <http://www.gnu.org/licenses/>.
#
#        USAGE: See function usage below.
#
#  DESCRIPTION: Burn a dvd from the SOURCE image file. Update the backup
#               database with the pertinent data.
#
# REQUIREMENTS: shellsql <http://sourceforge.net/projects/shellsql/>
#               backupdb.flib
#         BUGS: --
#        NOTES: Any suggestion is welcomed at auq..r@gmail.com (fill in
#               the dots).
#

source ~/code/bash/backupdb/backupdb.flib

#===  FUNCTION =========================================================
#
#        NAME: usage
#
#       USAGE: usage
#
# DESCRIPTION: Print a help message to stdout.
#
usage () {
	cat <<- EOF
	Usage: iso2dvd SOURCE "DVD_TYPE" "DVD_TRADEMARK"

	Burn a dvd from the SOURCE image file. Update the backup
	database with the pertinent data.
	EOF
}

#-----------------------------------------------------------------------
# BEGINNING OF MAIN CODE
#-----------------------------------------------------------------------

# Checking for a well-formatted command line.
[[ $# -eq 0 ]] && usage && exit
if [ $# -ne 3 ]
then
	echo "dir2iso: three arguments are required." 1>&2
	exit 1 
elif [[ $1 =~ .*/$ ]]
then
	echo "iso2dvd: First arg must be a regular filename." 1>&2
	exit 1
fi

#-----------------------------------------------------------------------
# Burn the DVD.
#-----------------------------------------------------------------------

version="$(cdrecord -version)"
[[ $? -ne 0 ]] && exit 1
options="-dummy -v -eject speed=4 dev=ATAPI:0,0,0" 
input=$(readlink -f $1)
sudo cdrecord $options $(readlink -f $input)
[[ $? -ne 0 ]] && exit 1

#-----------------------------------------------------------------------
# Update the backup database.
#-----------------------------------------------------------------------

handle=$(shmysql user=$BACKUPDB_USER password=$BACKUPDB_PASSWORD \
	dbname=$BACKUPDB_DBNAME) 
if [ $? -ne 0 ]
then
	echo "iso2dvd: Unable to establish connection to db." 1>&2
	exit 1
fi
input=$(readlink -f $1)
if ! get_id $handle imageid $(hostname) $input
then
	echo "iso2dvd: error in get_id ()." 1>&2
	exit 1
fi
if ! insert_dvd $handle $imageid $2 $3
then
	echo "iso2dvd: error in insert_dvd ()." 1>&2
	exit 1
fi
shsqlend $handle
