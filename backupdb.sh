#! /bin/sh

source ~/code/bash/backupdb/libbackupdb.sh
source ~/code/bash/backupdb/getoptx.bash
source ~/code/bash/backupdb/libpathn.sh

#=======================================================================
#
#         FILE: backupdb.sh
#
#        USAGE: backupdb.sh [OPTIONS] PATH...
#
#  DESCRIPTION: Store metadata from audio files in music_backup
#               database.
#
#      OPTIONS: See function 'usage' below.
# REQUIREMENTS: shellsql <http://sourceforge.net/projects/shellsql/>
#               upvars.sh
#               libbackupdb.sh
#         BUGS: --
#        NOTES: --
#       AUTHOR: Marcelo Auquer, auquer@gmail.com
#      CREATED: 03/07/2012
#     REVISION: 04/01/2012
#
#======================================================================= 

#===  FUNCTION =========================================================
#
#        NAME: usage
#
#       USAGE: usage
#
# DESCRIPTION: Print a help message to stdout.
#
#=======================================================================
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

#-----------------------------------------------------------------------
# Parse command line options.
#-----------------------------------------------------------------------

find_opts[0]="-maxdepth 1"
while getoptex "r recursive R" "$@"; do
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

#-----------------------------------------------------------------------
# Check for command line correctness.
#-----------------------------------------------------------------------

[[ $# -eq 0 ]] && usage && exit
[[ $# -gt 1 ]] && rm_subtrees pathnames "$@" || pathnames=$@

#-----------------------------------------------------------------------
# Setup a connection to the database and change problematic pathnames.
#-----------------------------------------------------------------------

handle=$(shmysql user=$BACKUPDB_USER password=$BACKUPDB_PASSWORD \
	dbname=$BACKUPDB_DBNAME) 
if [ $? -ne 0 ]
then
	echo "backupdb.sh: Unable to establish connection to db." 1>&2
	exit 1
fi
chpathn -rp "$@"

#-----------------------------------------------------------------------
# Search in PATH... for file's metadata and insert/update it in the
# database.
#-----------------------------------------------------------------------

echo "$(find ${pathnames[@]} ${find_opts[@]} -type f)"
for file in $(find ${pathnames[@]} ${find_opts[@]} -type f)
do
	file=$(readlink -f $file)
	if ! is_backedup $handle backedup $(hostname) $file
	then
		echo "backupdb.sh: error in is_backedup ()." 1>&2
		exit 1
	fi
	if [ $backedup == "true" ]
	then
		if ! is_insync $handle insync $(hostname) $file
		then
			echo "backupdb.sh: error in is_insync ()." 1>&2
			exit 1
		fi
		if [ $insync == "true" ]
		then
			continue
		else
			if ! update_file $handle $(hostname) $file 
			then
				echo "backupdb.sh: error in update_file ()." 1>&2
				exit 1
			fi
		fi
	else
		if ! insert_file $handle $(hostname) $file 
		then
			echo "backupdb.sh: error in insert_file ()." 1>&2
			exit 1
		fi
	fi
done

#-----------------------------------------------------------------------
# Search in db for metadata whose file don't exist in PATH... anymore
# and delete it from the database.
#-----------------------------------------------------------------------

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
		if ! delete_file $handle $id
		then
			echo "backupdb: error in delete_file ()." 1>&2
			exit 1
		fi
	done
)
shsqlend $handle
