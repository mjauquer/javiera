#! /bin/sh

source ~/code/bash/lib/backupdb/libbackupdb.sh

#=======================================================================
#
#         FILE: backupdb.sh
#
#        USAGE: backupdb.sh PATH...
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
#     REVISION: 03/29/2012
#
#======================================================================= 

#-----------------------------------------------------------------------
# BEGINNING OF MAIN CODE
#-----------------------------------------------------------------------

handle=$(shmysql user=musicb_app password=backup dbname=music_backup) 
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

for file in $(find "$@" -type f)
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
