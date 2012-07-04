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

source ~/code/bash/backupdb/shell-scripts/functions/backupdb-core.bash
source ~/code/bash/backupdb/upvars/upvars.bash
source ~/code/bash/chpathn/chpathn.flib

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
	[ -v handle ] && shsqlend $handle
	exit 1
}

#===  FUNCTION =========================================================
#
#       USAGE: get_label HANDLE VARNAME 
#
# DESCRIPTION: Generate a label to be assigned to an image file. Store
#              that label in the caller's variable VARNAME.
#
#  PARAMETERS: HANDLE  A connection to the database.
#              VARNAME The name of a caller's variable.
#
get_label () {
	local lastid
	local label
	lastid=$(shsql $1 $(printf 'SELECT MAX(id) FROM iso_metadata;'))
	lastid=${lastid//\"}
	lastid=${lastid:-0}
	label=$(shsql $1 $(printf 'SELECT auto_increment FROM 
		information_schema.tables WHERE
		table_name="iso_metadata" AND
		table_schema="%b";' $BACKUPDB_DBNAME ))
	label=${label//\"}
	label=${label:-1}
	local $2 && upvar $2 $label
}

#-----------------------------------------------------------------------
# BEGINNING OF MAIN CODE
#-----------------------------------------------------------------------

# Variables declaration.
declare progname   # The name of this script.

declare dir_inode  # The inode of the source directory passed as
                   # argument.

declare source_dir # The pathname of the source directory after calling
                   # backupdb.

declare handle     # Required by shsql. A connection to the database.

declare label      # The label of the iso file that will be generated.

declare ouput      # The pathname of the output image file.

declare version    # The version of the mkisofs command.

declare options    # The options to be passed to the mkisofs command.

declare outputid   # The file_id number in the database for the created
                   # output image file.

progname=$(basename $0)

# If no argument were passed, print usage message and exit.
[[ $# -eq 0 ]] && usage && exit

# Check if there already is in the current directory a file whose
# pathname is the specified by OUTPUT.
if [ -a "$2" ]
then
	error_exit "$LINENO: the specified output file already exists."
else
	output=$(readlink -f $2)
fi

# Checking for a well-formatted command line.
if [ $# -ne 2 ]
then
	error_exit "$LINENO: two arguments must be passed."
elif [ ! -d $1 ]
then
	error_exit "$LINENO: first arg must be an existing directory."
elif [[ ! $2 =~ .*[^/]$ ]]
then
	error_exit "$LINENO: second argument must be a regular filename."
fi

# Store the inode of the source directory passed as argument.
dir_inode=$(stat -c %i "$1")

# Update the backup database with the metadata of the files under the
# source directory.
declare -a log   # The output of the command backupdb --verbose.
declare top_dirs # A list of directories where to find by inode the
                 # the files and directories passed as arguments.
log=($(chpathn -rp --verbose "$@"))
if [ $? -ne 0 ]
then
	error_exit "$LINENO: Error after calling chpathn."
fi
if ! read_topdirs top_dirs ${log[@]}
then
	error_exit "$LINENO: Error after a call to read_topdirs()."
fi
unset -v log


# Get the pathname of the source directory passed as argument after
# calling backupdb, because that script calls chpathn.
source_dir=($(find ${top_dirs[@]} -depth -inum $dir_inode -type d))

# Setup a connection to the database.
handle=$(shmysql user=$BACKUPDB_USER password=$BACKUPDB_PASSWORD \
	dbname=$BACKUPDB_DBNAME) 
if [ $? -ne 0 ]
then
	error_exit "$LINENO: error after calling shmysql."
fi

#-----------------------------------------------------------------------
# Create an iso file.
#-----------------------------------------------------------------------

# Generate the label of the iso file to be created
if ! get_label $handle label
then
	error_exit "$LINENO: error after calling get_label()."
fi

# Get the version of the mkisofs command.
version="$(mkisofs --version)"
if [ $? -ne 0 ]
then
	error_exit "$LINENO: error after calling mkisofs."
fi

# Set the options to be passed to the mkisofs command.
options="-V $label -iso-level 4 -allow-multidot -allow-lowercase \
	-ldots -r" 

# Make the image file.
mkisofs $options -o $output $source_dir
if [ $? -ne 0 ]
then
	error_exit "$LINENO: error after calling mkisofs."
fi

#-----------------------------------------------------------------------
# Update the backup database with data about the created iso file.
#-----------------------------------------------------------------------

# Insert the new created file into the database. Get its file_id number.
if ! insert_file $handle $(hostname) $output
then
	error_exit "$LINENO: error after calling insert_file()."
fi
if ! get_id $handle outputid $(hostname) $output
then
	error_exit "$LINENO: error after calling get_id()."
fi

# Insert details of the software and options used to create the file.
shsql $handle $(printf 'UPDATE iso_metadata SET software="%b", 
	used_options="%b" WHERE file_id=%b;' "$version" "$options" \
	$outputid)
if [ $? -ne 0 ]
then
	error_exit "$LINENO: error after calling shsql."
fi

# Insert archive relationships between the iso file and its content.
for file in $(find $source_dir -type f)
do
	file="$(readlink -f $file)"
	if ! get_id $handle fileid $(hostname) $file
	then
		error_exit "$LINENO: error after calling get_id()."
	fi
	[[ $fileid == $outputid ]] && continue
	if ! insert_archive $handle $outputid $fileid
	then
		error_exit "$LINENO: error after calling insert_archive()."
	fi
	unset -v fileid
done
unset -v file

shsqlend $handle
