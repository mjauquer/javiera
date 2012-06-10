#! /bin/bash

# dir2tar.bash (See description below).
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
#  DESCRIPTION: Create a tar archive named NAME and include in it the
#               files founded in PATH...
#
# REQUIREMENTS: shellsql <http://sourceforge.net/projects/shellsql/>
#               backupdb.flib
#               getoptx.bash
#         BUGS: --
#        NOTES: Any suggestion is welcomed at auq..r@gmail.com (fill in
#               the dots).

source ~/code/bash/backupdb/backupdb.flib
source ~/code/bash/backupdb/getoptx/getoptx.bash


#===  FUNCTION =========================================================
#
#       USAGE: usage
#
# DESCRIPTION: Print a help message to stdout.
#
usage () {
	cat <<- EOF
	Usage: dir2tar TAR_NAME PATH...
	dir2tar --listed-in TEXT_FILE TAR_NAME

	Create a tar archive named NAME and include in it the
	files founded in PATH...
	EOF
}

#-----------------------------------------------------------------------
# BEGINNING OF MAIN CODE
#-----------------------------------------------------------------------

# Parse command line options.
ind=0
while getoptex "listed-in:" "$@"; do
	case "$OPTOPT" in
		listed-in)  while read line
		            do
			    	[[ $line =~ Total:.* ]] && continue
					paths[ind]="$line"
					ind=$((ind+1))
			    done < $(readlink -f $OPTARG)
		            ;;
	esac
done
shift $(($OPTIND-1))

# Checking for a well-formatted command line.
[[ $# -eq 0 ]] && usage && exit
if [[ $1 =~ .*/$ ]]
then
	echo "dir2tar.sh: First arg must be a regular filename." 1>&2
	exit 1
fi

# Update the backup database before attempting to create a tar file.
[[ -a $1 ]] && rm $1
backupdb .

# Create a temporary directory where to work in.
tempdir=$(mktemp -d tmp.XXX)
chmod 755 $tempdir
mv ${paths[@]:-${@:2}} $tempdir
cd $tempdir
pathlist=( $(find $(ls)) )

# Create a tar file.
tar -cf $1 ${pathlist[@]}
[[ $? -ne 0 ]] && exit 1

# Update the backup database with data about the created tar file.
backupdb -r .
[[ $? -ne 0 ]] && exit 1

#-----------------------------------------------------------------------
# Update the backup database with the archive relationships.
#-----------------------------------------------------------------------

# Connect to the database.
handle=$(shmysql user=$BACKUPDB_USER password=$BACKUPDB_PASSWORD \
	dbname=$BACKUPDB_DBNAME) 
if [ $? -ne 0 ]
then
	echo "dir2tar.sh: Unable to establish connection to db." 1>&2
	exit 1
fi

# Separate in two different arrays directories and regular files.
for path in ${pathlist[@]}
do
	path=$(readlink -f $path)
	if [ -f $path ]
	then
		files[$ind1]=$path
		ind1=$((ind1+1))
	fi
done

# Get the id of the created tar file.
tarpath="$(readlink -f $1)"
if ! get_id $handle archiver_id $(hostname) $tarpath
then
	echo "dir2tar.sh: error in get_id ()." 1>&2
	exit 1
fi

# Insert archive relationships between the tar file and its content.
for file in ${files[@]}
do
	# Get the id of the archived file.
	if ! get_id $handle archived_id $(hostname) $file
	then
		echo "dir2tar.sh: error in get_id ()." 1>&2
		exit 1
	fi
	# Insert the archive relationship.
	if ! insert_archive $handle $archiver_id $archived_id
	then
		echo "dir2tar.sh: error in insert_archive ()" 1>&2
		exit 1
	fi
done

#-----------------------------------------------------------------------
# Remove the temporary directory.
#-----------------------------------------------------------------------

mv $1 ..
[[ $? -ne 0 ]] && exit 1
cd ..
[[ $? -ne 0 ]] && exit 1
rm -r $tempdir
[[ $? -ne 0 ]] && exit 1

# Update the backup database with this last movement.
shsql $handle $(printf 'UPDATE file SET pathname="%b" WHERE id=%b;' \
	$(readlink -f $1) $archiver_id)
backupdb -r .
shsqlend $handle
