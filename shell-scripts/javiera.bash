#! /bin/bash

# javiera.bash (See description below).
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
#               javiera.flib
#               pathname.flib
#         BUGS: --
#        NOTES: Any suggestion is welcomed at auq..r@gmail.com (fill in
#               the dots).
#

source ~/projects/javiera/shell-scripts/functions/javiera-core.bash
source ~/projects/javiera/getoptx/getoptx.bash
source ~/projects/javiera/pathname/pathname.flib
source ~/code/bash/chpathn/chpathn.flib

usage () {

#        NAME: usage
#
#       USAGE: usage
#
# DESCRIPTION: Print a help message to stdout.

	cat <<- EOF
	Usage: javiera.sh [OPTIONS] PATH...
	
	Collect and store in a backup database metadata about files in 
	the directories listed in PATH...

	 -r
	 -R
	--recursive    Do all actions recursively.
	--verbose      Print information about what is beeing done.
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

declare progname               # The name of this script.

declare user=$JAVIERA_USER     # A mysql user name.

declare pass=$JAVIERA_PASSWORD # A mysql password.

declare db=$JAVIERA_DBNAME     # A mysql database.

progname=$(basename $0)

# If no argument was passed, print usage message and exit.
[[ $# -eq 0 ]] && usage && exit

# Parse command line options.
declare -a find_opts  # A list of options to be passed to the find
                      # command.

find_opts[0]="-maxdepth 1"
while getoptex "r recursive R verbose" "$@"
do
	case "$OPTOPT" in
		r)            find_opts[0]="-depth"
			      ;;
		recursive)    find_opts[0]="-depth"
		              ;;
		R)            find_opts[0]="-depth"
		              ;;
		verbose)      verbose=true
	esac
done
shift $(($OPTIND-1))

# Save the corresponding inode of the pathnames passed as arguments to
# this script.
declare -a dir_inodes  # A list of inodes corresponding to every
                       # directory passed as argument.
declare -a file_inodes # A list of inodes corresponding to every file
                       # passed as argument.
for arg
do
	if [ -d "$arg" ]
	then
		dir_inodes+=($(stat -c %i "$arg"))
		[ $? -ne 0 ] && error_exit
	elif [ -f "$arg" ]
	then
		file_inodes+=($(stat -c %i "$arg"))
		[ $? -ne 0 ] && error_exit
	fi
done
unset -v arg

# Look at the pathnames passed as arguments and change those that can be
# problematic ones.
declare -a log   # The output of the command chpathn --verbose.
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

# If the --verbose option was given, print the content of the 'top_dirs'
# array.
if [[ $verbose == true ]]
then
	printf ' -----------\n Javiera log:\n -----------\n'
        printf ' * Top directories:\n'
	for dir in ${top_dirs[@]}
	do
		echo "   $dir"
	done
	unset -v dir
fi

# Get the pathnames of the files passed as arguments after calling to
# chpathn.
declare -a files       # The list of pathnames to be processed by this
                       # script.
for inode in ${dir_inodes[@]}
do
	[[ ${#dir_inodes[@]} -eq 0 ]] && break
	dir=$(find ${top_dirs[@]} -depth -inum $inode -type d)
	files+=($(find $dir ${find_opts[@]} -type f))
done
unset -v dir
unset -v dir_inodes
for inode in ${file_inodes[@]}
do
	[[ ${#file_inodes[@]} -eq 0 ]] && break
	files+=($(find ${top_dirs[@]} -depth -inum $inode -type f))
done
unset -v inode
unset -v file_inodes
unset -v top_dirs

#======================================================================
# Update the database.
#======================================================================

# Setup a connection to the database.
handle=$(shmysql user=$user password=$pass dbname=$db) 
if [ $? -ne 0 ]
then
	error_exit "$LINENO: Unable to establish connection to db."
fi

for file in ${files[@]}
do
	file=$(readlink -f $file)
	if ! is_backedup $handle backedup $(hostname) $file
	then
		error_exit "$LINENO: Error after calling is_backedup()."
	fi
	if [ $backedup == true ]
	then
		if ! is_insync $handle insync $(hostname) $file
		then
			error_exit "$LINENO: Error after calling is_insync()."
		fi
		if [ $insync == true ]
		then
			continue
		else
			if ! update_file $handle $(hostname) $file 
			then
				error_exit "$LINENO: Error after calling update_file()."
			fi
		fi
	elif [ $backedup == false ]
	then
		if ! insert_file $handle $(hostname) $file 
		then
			error_exit "$LINENO: Error after calling insert_file()."
		fi
	fi
done
unset -v file
unset -v backedup
unset -v insync

# Search in db for metadata whose file don't exist in PATH... anymore
# and delete it from the database.
declare tobedel
declare -i ind
shsql $handle "
	SELECT file.id, name AS pathname
	FROM file INNER JOIN path ON file.path_id = path.id;
	" | (
	while row=$(shsqlline)
	do
		eval set $row
		if [[ ! -a "$2" ]]
		then
			tobedel[ind]=$1
			ind=$((ind+1))
		fi
	done
	for id in ${tobedel[@]}
	do
		! delete_file $handle $id
	done
)
unset -v tobedel
unset -v ind

# Close the connection to the database.
shsqlend $handle
