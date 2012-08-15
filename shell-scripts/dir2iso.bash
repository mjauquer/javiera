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
#               javiera.flib
#         BUGS: --
#        NOTES: Any suggestion is welcomed at auq..r@gmail.com (fill in
#               the dots).

source ~/.myconf/javiera.cnf || exit 1
source ~/projects/javiera/shell-scripts/functions/javiera-core.bash ||
	exit 1
source ~/projects/javiera/upvars/upvars.bash || exit 1
source ~/code/bash/chpathn/chpathn.flib || exit 1

usage () {
	
#       USAGE: usage
#
# DESCRIPTION: Print a help message to stdout.

	cat <<- EOF
	Usage: dir2iso SOURCE OUTPUT

	Build an iso image file named OUTPUT with files that are under
	SOURCE directory.
	EOF
}

error_exit () {

#       USAGE: error_exit [MESSAGE]
#
# DESCRIPTION: Function for exit due to fatal program error.
#
#   PARAMETER: MESSAGE An optional description of the error.

	echo "${progname}: ${1:-"Unknown Error"}" 1>&2
	[ -v handle ] && shsqlend $handle
	exit 1
}

#-----------------------------------------------------------------------
# BEGINNING OF MAIN CODE
#-----------------------------------------------------------------------

# Variables declaration.
declare progname   # The name of this script.
declare dir_inode  # The inode of the source directory passed as
                   # argument.
declare source_dir # The pathname of the source directory after calling
                   # javiera.
declare label      # The label of the iso file that will be generated.
declare ouput      # The pathname of the output image file.
declare version    # The version of the mkisofs command.
declare options    # The options to be passed to the mkisofs command.
declare outputid   # The file_id number in the database for the created
                   # output image file.
declare user       # A mysql user name.
declare pass       # A mysql password.
declare db         # A mysql database.

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
declare -a log   # The output of the command javiera --verbose.
declare top_dirs # A list of directories where to find by inode the
                 # the files and directories passed as arguments.
log=($(javiera -r --verbose "$@"))
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
# calling javiera, because that script calls chpathn.
source_dir=($(find ${top_dirs[@]} -depth -inum $dir_inode -type d))

# Generate a metadata file in $source_dir/.javiera
if ! mkdir $source_dir/.javiera
then
	error_exit "$LINENO: Coudn't make the .javiera directory."
fi
echo "UUID=$(uuidgen)" >> $source_dir/.javiera/info.txt
if [ $? -ne 0 ]
then
	error_exit "$LINENO: Error after a call to uuidgen."
fi

#-----------------------------------------------------------------------
# Create an iso image file.
#-----------------------------------------------------------------------

# Get the version of the mkisofs command.
version="$(mkisofs --version)"
if [ $? -ne 0 ]
then
	error_exit "$LINENO: error after calling mkisofs."
fi

# Set the options to be passed to the mkisofs command.
options="-iso-level 4 -allow-multidot -allow-lowercase -ldots -r" 

# Make the image file.
mkisofs -V "BACKUPDVD" $options -o $output $source_dir
if [ $? -ne 0 ]
then
	error_exit "$LINENO: error after calling mkisofs."
fi

#-----------------------------------------------------------------------
# Update the backup database with data about the created iso file.
#-----------------------------------------------------------------------

# Insert the new created file into the database.
if ! javiera $output
then
	error_exit "$LINENO: error after calling javiera."
fi

# Insert details of the software and options used to create the file.

version=\'$version\'
options=\'$options\'
isosha1=$(sha1sum $output | cut -c1-40); isosha1=\"$isosha1\"

mysql --skip-reconnect -u$user -p$pass --skip-column-names -e "

	USE javiera;
	CALL process_output_file (
		'mkisofs',
		$version,
		$options,
		$isosha1
	);
"
if [ $? -ne 0 ]
then
	error_exit "$LINENO: Error after calling mysql."
fi
unset -v options
unset -v version

# Insert archive relationships between the iso file and its content.
for file in $(find $source_dir -type f)
do
	filesha1=$(sha1sum $output | cut -c1-40)
	filesha1=\"$filesha1\"
	suffix=${file#$source_dir/}; suffix=\'$suffix\'

	mysql --skip-reconnect -u$user -p$pass \
		--skip-column-names -e "

		USE javiera;
		CALL process_archived_file (
			$isosha1,
			$filesha1,
			$suffix
		);
	"
	if [ $? -ne 0 ]
	then
		error_exit "$LINENO: Error after calling mysql."
	fi
done
unset -v file
unset -v filesha1
unset -v suffix
