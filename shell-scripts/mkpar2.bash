#! /bin/bash

# mkpar2.bash <Functions for the javiera.bash script.>
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
#               javiera.flib
#         BUGS: --
#        NOTES: Any suggestion is welcomed at auq..r@gmail.com (fill in
#               the dots).

source ~/projects/javiera/shell-scripts/functions/javiera-core.bash
source ~/code/bash/chpathn/chpathn.flib

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
	echo "${progname}: ${1:-"Unknown Error"}" 1>&2
	[ -v handle ] && shsqlend $handle
	exit 1
}

#-----------------------------------------------------------------------
# BEGINNING OF MAIN CODE
#-----------------------------------------------------------------------

# If no argument were passed, print usage message and exit.
[[ $# -eq 0 ]] && usage && exit

# Variables declaration.
declare progname=$(basename $0)

declare -a notfiles   # A list of pathnames that do not correspond to
                      # regular files.

declare -a found_par2 # Used if there were par2 files in the current
                      # directory before this script was called.

declare -a inodes     # A list of the inodes of the files whose
                      # pathnames were passed as arguments to this
		      # script.

declare -a files      # A list of the current pathnames of the files
                      # whose pathnames were passed to this script
		      # (needed because may have been changed since this
		      # script was called).

declare blocksize     # The block size of the par2 parity volumes.

declare blockcount    # The number of parity blocks to be build.

declare outputinfo    # The pathname of a text file where the output of
                      # the par2 command will be writen.

declare handle        # Required by shsql. A connection to the database.

declare softw         # The name and version of the par2 command.

declare session_id    # A number assigned by the database to the par2
                      # session.

# Check if all of the arguments are pathnames corresponding to regular
# files.
for arg
do
	if [ ! -f "$(readlink -f "$arg")" ]
	then
		notfiles+=( "$arg" )
	fi
done
unset -v arg

# If any of the pathnames passed is not a regular file, exit with
# message.
if [ ${#notfiles} -ne 0 ]
then
	error_exit "$LINENO: Only regular files can be passed as arguments.
The following arguments are not regular files:
$(for notfile in ${notfiles[@]}; do echo "$notfile"; done)"
fi

# Check if there are par2 files in the current working directory.
found_par2="$(find . -regex '.*par2')"
if [ "$found_par2" ]
then
	error_exit "$LINENO: Refuse to run if there are par2 files in the working directory."
fi

# Store the inodes of the files passed as arguments.
for arg
do
	inodes+=($(stat -c %i "$arg"))
	[ $? -ne 0 ] && error_exit
done
unset -v arg

# Update the database with data about the files passed as arguments.
declare -a log   # The output of the command javiera --verbose.
declare top_dirs # A list of directories where to find by inode the
                 # files and directories passed as arguments.
log=($(javiera -r --verbose "$@" .))
if [ $? -ne 0 ]
then
	error_exit "$LINENO: Error after calling javiera."
fi
if ! read_topdirs top_dirs ${log[@]}
then
	error_exit "$LINENO: Error after a call to read_topdirs()."
fi
unset -v log

# Get the pathnames of the files passed as arguments, after calling to
# chpathn.
for (( i=0; i<${#inodes[@]}; i++ )) 
do
	files+=($(find ${top_dirs[@]} -depth -inum ${inodes[i]} -type f))
done

# Create parity files.

blocksize=262144
blockcount=8 #1587
outputinfo=par2info.txt
par2 create -s${blocksize} -c${blockcount} par2file ${files[@]} > $outputinfo
if [ $? -ne 0 ]
then
	error_exit "$LINENO: Error after calling par2 utility"
fi
softw="$(head -n 1 < $outputinfo)"

#----------------------------------------------------------------------
# Update the database.
#----------------------------------------------------------------------

# Setup a connection to the database.
handle=$(shmysql user=$JAVIERA_USER password=$JAVIERA_PASSWORD \
	dbname=$JAVIERA_DBNAME) 
if [ $? -ne 0 ]
then
	error_exit "$LINENO: Unable to establish connection to db."
fi

# Insert data in 'par2create' tables.
shsql $handle $(printf '
	INSERT INTO par2create (software, blocksize, blockcount)
		VALUES ("%b","%b","%b");
		' "$softw" $blocksize $blockcount)
if [ $? -ne 0 ]
then
	error_exit "$LINENO: Error while trying to update the database."
fi

# Insert data in 'par2create_target' table.
session_id=$(shsql $handle "
	SELECT LAST_INSERT_ID();
	")
for file in  ${files[@]}
do
	get_id $handle file_id $(hostname) $(readlink -f $file)
	if [ $? -ne 0 ]
	then
		error_exit "$LINENO: Error calling get_id()."
	fi
	shsql $handle $(printf '
		INSERT INTO par2create_target (session, target)
			VALUES (%b,%b);
		' $session_id $file_id)
	if [ $? -ne 0 ]
	then
		error_exit "$LINENO: Error after calling shsql."
	fi
done
unset -v file
unset -v file_id

# Insert data in 'par2create_volset' table.

for file in $(find . -regex .*par2) ./$outputinfo
do
	insert_file $handle $(hostname) $(readlink -f $file) 
	if [ $? -ne 0 ]
	then
		error_exit "$LINENO: Error after calling insert_file."
	fi
	get_id $handle file_id $(hostname) $(readlink -f $file)
	if [ $? -ne 0 ]
	then
		error_exit "$LINENO: Error calling get_id()."
	fi
	shsql $handle $(printf '
		INSERT INTO par2create_volset (session, volume_set)
			VALUES (%b,%b);
		' $session_id $file_id)
	if [ $? -ne 0 ]
	then
		error_exit "$LINENO: Error after calling shsql."
	fi
done
unset -v file
unset -v file_id

shsqlend $handle
