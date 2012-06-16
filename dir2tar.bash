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
#               files founded in pathname...
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
	Usage: dir2tar TAR_NAME pathname...
	dir2tar --listed-in TEXT_FILE TAR_NAME

	Create a tar archive named NAME and include in it the
	files founded in pathname...
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
	echo "${progname}: ${1:-"Unknown Error"}" 1>&2
	exit 1
}

#-----------------------------------------------------------------------
# BEGINNING OF MAIN CODE
#-----------------------------------------------------------------------

progname=$(basename $0)

# Parse command line options.
declare -a pathnames
while getoptex "listed-in:" "$@"
do
	case "$OPTOPT" in
		listed-in) txtfile="$OPTARG"
		            ;;
	esac
done
if [ "$txtfile" ]
then
	if [ -a $(readlink -f "$txtfile") ]
	then
		while read line
		do
			[[ $line =~ Total:.* ]] && continue
			pathnames+=( "$line" )
		done < $(readlink -f "$txtfile")
	else
            	error_exit "$LINENO: $txtfile not found."
	fi
fi
shift $(($OPTIND-1))

# Add to the list of pathnames to be processed, those which were passed
# as command line arguments.
pathnames+=( ${@:2} )

# Check the existence of the files passed as arguments.
declare -a notfound
for pathname in ${pathnames[@]}
do
	if [ \( ! -d $pathname \) -a \( ! -f $pathname \) ]
	then
		notfound+=("$pathname")
	fi
done
if [ ${#notfound[@]} -ne 0 ]
then
	error_exit "$LINENO: The following arguments do not exist as
regular files or directories in the filesystem:
$(for file in ${notfound[@]}; do echo "$file"; done)"
fi

# Check for a well-formatted pathname of the output tar file.
[[ $# -eq 0 ]] && usage && exit
if [[ $1 =~ .*/$ ]]
then
	error_exit "$LINENO: First arg must be a regular filename."
fi

# Check if the specified output tar file already exists in the working
# directory.
if [ -f $1 ]
then
	error_exit "$LINENO: $1 already exists in $(pwd)."
fi

# Create a temporary directory where to work in.
tempdir=$(mktemp -d tmp.XXX)
chmod 755 $tempdir
mv ${pathnames[@]} $tempdir
cd $tempdir
pathlist=( $(find $(ls)) )

# Create a tar file.
tar -cf $1 ${pathlist[@]}
if [ $? -ne 0 ]
then
	error_exit "$LINENO: Error after calling tar utility."
fi

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
	error_exit "$LINENO: Unable to establish connection to db."
fi

# Separate in two different arrays directories and regular files.
declare -i ind1
for pathname in ${pathlist[@]}
do
	path=$(readlink -f $pathname)
	if [ -f $path ]
	then
		files[ind++]=$path
	fi
done

# Get the id of the created tar file.
tarpath="$(readlink -f $1)"
if ! get_id $handle archiver_id $(hostname) $tarpath
then
	error_exit "$LINENO: Error after calling get_id()."
fi

# Insert archive relationships between the tar file and its content.
for file in ${files[@]}
do
	# Get the id of the archived file.
	if ! get_id $handle archived_id $(hostname) $file
	then
		error_exit "$LINENO: Error after calling get_id()."
	fi
	# Insert the archive relationship.
	if ! insert_archive $handle $archiver_id $archived_id
	then
		error_exit "$LINENO: Error after calling insert_archive()."
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
