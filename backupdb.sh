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
#     REVISION: 03/17/2012
#
#======================================================================= 

#-----------------------------------------------------------------------
# BEGINNING OF MAIN CODE
#-----------------------------------------------------------------------

chpathn -rp "$@"
handle=$(shmysql user=musicb_app password=backup dbname=music_backup) 

#-----------------------------------------------------------------------
# Search in PATH... for file's metadata and insert/update it in the
# database.
#-----------------------------------------------------------------------

for file in $(find "$@" -type f); do
	file=$(readlink -f $file)
	if is_backedup $handle "$file"; then
		if is_insync $handle "$file"; then
			continue
		else
			update_file $handle $file
		fi
	else
		insert_file $handle $file
	fi
done

#-----------------------------------------------------------------------
# Search in db for metadata whose file don't exist in PATH... anymore
# and delete it from the database.
#-----------------------------------------------------------------------

tobedel=
ind=0
shsql $handle "SELECT id, pathname FROM file;" | (
	while row=$(shsqlline); do
		eval set $row
		[[ ! -a "$2" ]] && tobedel[$ind]=$1 && ind=$(($ind+1))
	done
for id in ${tobedel[@]} ; do
	delete_file $handle $id
done
)
shsqlend $handle
