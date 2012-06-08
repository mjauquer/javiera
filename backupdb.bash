#! /bin/bash

#=======================================================================
#
# backupdb.bash (See description below).
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
#  DESCRIPTION: Keep up to date a backup database.
#
# REQUIREMENTS: shellsql <http://sourceforge.net/projects/shellsql/>
#               getoptx
#               backupdb.flib
#               pathname.flib
#         BUGS: --
#        NOTES: Any suggestion is welcomed at auq..r@gmail.com (fill in
#               the dots).
#

source ~/code/bash/backupdb/backupdb.flib
source ~/code/bash/backupdb/getoptx/getoptx.bash
source ~/code/bash/backupdb/pathname/pathname.flib

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
	Usage: backupdb.sh [OPTIONS] PATH...
	
	Collect and store in a backup database metadata about files in 
	the directories listed in PATH...

	 -r
	 -R
	--recursive    Do all actions recursively.
	EOF
}

#-----------------------------------------------------------------------
# BEGINNING OF MAIN CODE
#-----------------------------------------------------------------------

# Parse command line options.
find_opts[0]="-maxdepth 1"
while getoptex "r recursive R" "$@"
do
	case "$OPTOPT" in
		r)            find_opts[0]="-depth"
			      ;;
		recursive)    find_opts[0]="-depth"
		              ;;
		R)            find_opts[0]="-depth"
		              ;;
	esac
done
shift $(($OPTIND-1))

# Check for command line correctness.
[[ $# -eq 0 ]] && usage && exit
[[ $# -gt 1 ]] && rm_subtrees pathnames "$@" || pathnames=$@

# Setup a connection to the database and change problematic pathnames.
handle=$(shmysql user=$BACKUPDB_USER password=$BACKUPDB_PASSWORD \
	dbname=$BACKUPDB_DBNAME) 
if [ $? -ne 0 ]
then
	echo "backupdb.sh: Unable to establish connection to db." 1>&2
	exit 1
fi
chpathn -rp "$@"

# Search in PATH... for file's metadata and insert/update it in the
# database.
for file in $(find ${pathnames[@]} ${find_opts[@]} -type f)
do
	file=$(readlink -f $file)
	is_backedup $handle backedup $(hostname) $file
	if [ $? -ne 0 ]
	then
		echo "backupdb.sh: error in is_backedup ()." 1>&2
		exit 1
	fi
	if [ $backedup == "true" ]
	then
		is_insync $handle insync $(hostname) $file
		if [ $? -ne 0 ]
		then
			echo "backupdb.sh: error in is_insync ()." 1>&2
			exit 1
		fi
		if [ $insync == "true" ]
		then
			continue
		else
			update_file $handle $(hostname) $file 
			if [ $? -ne 0 ]
			then
				echo "backupdb.sh: error in update_file ()." 1>&2
				exit 1
			fi
		fi
	else
		insert_file $handle $(hostname) $file 
		if [ $? -ne 0 ]
		then
			echo "backupdb.sh: error in insert_file ()." 1>&2
			exit 1
		fi
	fi
done

# Search in db for metadata whose file don't exist in PATH... anymore
# and delete it from the database.
tobedel=
ind=0
shsql $handle "SELECT id, pathname FROM file;" | (
	while row=$(shsqlline)
	do
		eval set $row
		if [[ ! -a "$2" ]]
		then
			tobedel[$ind]=$1
			ind=$(($ind+1))
		fi
	done
	for id in ${tobedel[@]}
	do
		delete_file $handle $id
		if [ $? -ne 0 ]
		then
			echo "backupdb: error in delete_file ()." 1>&2
			exit 1
		fi
	done
)
shsqlend $handle
