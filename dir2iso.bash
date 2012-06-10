#! /bin/bash

# dir2iso.bash (See description below).
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
#  DESCRIPTION: Build an iso image file named OUTPUT with files that are
#               under SOURCE directory.
#
# REQUIREMENTS: shellsql <http://sourceforge.net/projects/shellsql/>
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
	Usage: dir2iso SOURCE OUTPUT

	Build an iso image file named OUTPUT with files that are under
	SOURCE directory.
	EOF
}

#-----------------------------------------------------------------------
# BEGINNING OF MAIN CODE
#-----------------------------------------------------------------------

# Checking for a well-formatted command line.
[[ $# -eq 0 ]] && usage && exit
if [ $# -ne 2 ]
then
	echo "dir2iso: two arguments are required." 1>&2
	exit 1 
elif [ ! -d $1 ]
then
	echo "dir2iso: First arg must be an existing directory." 1>&2
	exit 1
elif [[ ! $2 =~ .*[^/]$ ]]
then
	echo "dir2iso: Second arg must be a regular filename." 1>&2
	exit 1
fi

# Update the backup database before attempting to create an iso file.
input=$1
[[ -a $2 ]] && rm $2
backupdb -r $input
[[ $? -ne 0 ]] && exit 1

#-----------------------------------------------------------------------
# Create an iso file.
#-----------------------------------------------------------------------

# Generate the label of the iso file to be created
handle=$(shmysql user=$BACKUPDB_USER password=$BACKUPDB_PASSWORD \
	dbname=$BACKUPDB_DBNAME) 
if [ $? -ne 0 ]
then
	echo "dir2iso: Unable to establish connection to db." 1>&2
	exit 1
fi
lastid=$(shsql $handle $(printf 'SELECT MAX(id) FROM iso_metadata;'))
lastid=${lastid//\"}
lastid=${lastid:-0}
label=$(shsql $handle $(printf 'SELECT auto_increment FROM 
	information_schema.tables WHERE table_name="iso_metadata" AND
	table_schema="%b";' $BACKUPDB_DBNAME ))
label=${label//\"}
label=${label:-1}
output=$2
version="$(mkisofs --version)"
[[ $? -ne 0 ]] && exit 1
options="-V $label -iso-level 4 -allow-multidot -allow-lowercase \
	-ldots -r" 
mkisofs $options -o $output $input
[[ $? -ne 0 ]] && exit 1

#-----------------------------------------------------------------------
# Update the backup database with data about the created iso file.
#-----------------------------------------------------------------------

output="$(readlink -f $output)"

# Insert the new created file into db. Get its file_id number.
if ! insert_file $handle $(hostname) $output
then
	echo "tar2iso: error in insert_file ()." 1>&2
	exit 1
fi
if ! get_id $handle outputid $(hostname) $output
then
	echo "tar2iso: error in get_id ()." 1>&2
	exit 1
fi

# Insert details of the software and options used to create the file.
shsql $handle $(printf 'UPDATE iso_metadata SET software="%b", 
	used_options="%b" WHERE file_id=%b;' "$version" "$options" \
	$outputid)
[[ $? -ne 0 ]] && 
	echo "tar2iso: error while inserting iso metadata into db." 1>&2

# Insert archive relationships between the iso file and its content.
for file in $(find $input -type f)
do
	file="$(readlink -f $file)"
	if ! get_id $handle fileid $(hostname) $file
	then
		echo "tar2iso: error in get_id ()." 1>&2
		exit 1
	fi
	[[ $fileid == $outputid ]] && continue
	if ! insert_archive $handle $outputid $fileid
	then
		echo "tar2iso: error in insert_archive ()." 1>&2
		exit 1
	fi
done

shsqlend $handle
