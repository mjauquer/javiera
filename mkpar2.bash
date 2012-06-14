#! /bin/bash

# mkpar2.bash <Functions for the backupdb.bash script.>
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
# along with this program.  If not, see <http://www.gnu.org/licenses/>.
#
# REQUIREMENTS: shellsql <http://sourceforge.net/projects/shellsql/>
#               par2cmdline
#               backupdb.flib
#         BUGS: --
#        NOTES: Any suggestion is welcomed at auq..r@gmail.com (fill in
#               the dots).

source ~/code/bash/backupdb/backupdb.flib

#===  FUNCTION =========================================================
#
#       USAGE: usage
#
# DESCRIPTION: Print a help message to stdout.
#
usage () {
	cat <<- EOF
	Usage: mkpar2 PATH...

	Create par2 parity files for every file specified in PATH... 
	Update the backup database with the pertinent data.
	EOF
}

#===  FUNCTION =========================================================
#
#       USAGE: error_exit [MESSAGE]
#
# DESCRIPTION: Function for exit due to fatal program error.
#
#   PARAMETER: MESSAGE An optional description of the error.
#
error_exit () {
	echo "${PROGNAME}: ${1:-"Unknown Error"}" 1>&2
	exit 1
}

#-----------------------------------------------------------------------
# BEGINNING OF MAIN CODE
#-----------------------------------------------------------------------

PROGNAME=$(basename $0)

# Check for command line correctness.
[[ $# -eq 0 ]] && usage && exit
declare -a NOTFILES
for ARG
do
	if [ ! -f "$(readlink -f "$ARG")" ]
	then
		NOTFILES+=( "$ARG" )
	fi
done
if [ ${#NOTFILES} -ne 0 ]
then
	error_exit "$LINENO: Only regular files can be passed as arguments.
The following arguments are not regular files:
$(for notfile in ${NOTFILES[@]}; do echo "$notfile"; done)"
fi

# Check if there are par2 files in the current working directory.
declare -a FOUND_PAR2
FOUND_PAR2="$(find . -regex '.*par2')"
if [ "$FOUND_PAR2" ]
then
	error_exit "$LINENO: Refuse to run if there are par2 files in the working directory."
fi

# Store the inodes of the files passed as arguments.
declare -a INODES
for ARG
do
	INODES+=($(stat -c %i "$ARG"))
done

# For every file in PATH..., insert/update file's metadata in the db.
backupdb "$@" .
if [ $? -ne 0 ]
then
	error_exit "$LINENO: Error after calling backupdb script."
fi

# Get the pathnames of the files passed as arguments, after calling to
# chpathn.
declare -a FILES
for (( i=0; i<${#INODES[@]}; i++ )) 
do
	FILES+=($(find /home/marce/ -depth -inum ${INODES[i]} -type f))
done

# Create parity files.

BLOCKSIZE=262144
BLOCKCOUNT=8 #1587
OUTPUTINFO=par2info.txt
par2 create -s${BLOCKSIZE} -c${BLOCKCOUNT} par2file ${FILES[@]} > $OUTPUTINFO
if [ $? -ne 0 ]
then
	error_exit "$LINENO: Error after calling par2 utility"
fi
SOFTW="$(head -n 1 < $OUTPUTINFO)"

#----------------------------------------------------------------------
# Update the database.
#----------------------------------------------------------------------

# Setup a connection to the database.
HANDLE=$(shmysql user=$BACKUPDB_USER password=$BACKUPDB_PASSWORD \
	dbname=$BACKUPDB_DBNAME) 
if [ $? -ne 0 ]
then
	error_exit "$LINENO: Unable to establish connection to db."
fi

# Insert data in 'par2create' tables.
shsql $HANDLE $(printf 'INSERT INTO par2create (software, blocksize,
	blockcount) VALUES ("%b","%b","%b");' "$SOFTW" $BLOCKSIZE \
	$BLOCKCOUNT)
if [ $? -ne 0 ]
then
	error_exit "$LINENO: Error while trying to update the database."
fi

# Insert data in 'par2create_target' table.
SESSIONID=$(shsql $HANDLE "SELECT LAST_INSERT_ID();")
for FILE in  ${FILES[@]}
do
	get_id $HANDLE FILEID $(hostname) $(readlink -f $FILE)
	if [ $? -ne 0 ]
	then
		error_exit "$LINENO: Error calling get_id()."
	fi
	shsql $HANDLE $(printf 'INSERT INTO par2create_target (session,
		target) VALUES (%b,%b);' $SESSIONID $FILEID)
	if [ $? -ne 0 ]
	then
		error_exit "$LINENO: Error while trying to update the database."
	fi
done

# Insert data in 'par2create_volset' table.

for FILE in $(find . -regex .*par2) ./$OUTPUTINFO
do
	insert_file $HANDLE $(hostname) $(readlink -f $FILE) 
	if [ $? -ne 0 ]
	then
		error_exit "$LINENO: Error while trying to update the database."
	fi
	get_id $HANDLE FILEID $(hostname) $(readlink -f $FILE)
	shsql $HANDLE $(printf 'INSERT INTO par2create_volset (session,
		volume_set) VALUES (%b,%b);' $SESSIONID $FILEID)
	if [ $? -ne 0 ]
	then
		error_exit "$LINENO: Error while trying to update the database."
	fi
done

shsqlend $HANDLE

