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
#         BUGS: --
#        NOTES: Any suggestion is welcomed at auq..r@gmail.com (fill in
#               the dots).
#

source ~/.myconf/javiera.cnf || exit 1
source ~/projects/javiera/shell-scripts/functions/javiera-core.bash ||
	exit 1
source ~/projects/javiera/submodules/getoptx/getoptx.bash || exit 1
source ~/code/bash/chpathn/chpathn.flib || exit 1

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
	exit 1
}

#-----------------------------------------------------------------------
# BEGINNING OF MAIN CODE
#-----------------------------------------------------------------------

# If no argument was passed, print usage message and exit.

[[ $# -eq 0 ]] && usage && exit

# Enable extended regular expresion handling.

shopt -s extglob 

# Store this script's name in a variable for further use.

declare progname
progname=$(basename $0)

# Create a temporal directory.

[[ ! -d $tmp_root ]] &&
	mkdir -p $tmp_root ||
	error_exit "$LINENO: Error after trying to create a temporal directory."

# Parse command line options.

declare -a find_opts # A list of options to be passed to the find
                     # command.

find_opts=( -maxdepth 1 )
while getoptex "r recursive R verbose" "$@"
do
	case "$OPTOPT" in
		r)         find_opts=( -depth )
			   ;;
		recursive) find_opts=( -depth )
		           ;;
		R)         find_opts=( -depth )
		           ;;
		verbose)   verbose=true
	esac
done
shift $(($OPTIND-1))

# Select from the list of pathname arguments, those that do not need to
# be changed. Store them in the 'files' array.

declare -a files # The list of pathnames to be processed by this script.

declare oldifs   # Stores the content of the IFS variable as it 
                 # was when this script was called.
declare regex    # A regular expresion.

regex="./[[0-9A-z]._+]{1}[-[0-9A-z]._+]*$"

declare -i i=0
for arg
do
	i=i+1
	if [[ "$arg" =~ $regex ]]
	then
		if [ -d "$arg" ] 
		then
			files+=($(find $arg ${find_opts[@]} -type f))
		elif [ -f "$arg" ]
		then
			files+=( "$arg" )
		fi
		set -- "${@:1:$((i-1))}" "${@:$((i+1)):$#}"
		i=i-1
	fi
done

unset -v i
unset regex
unset oldifs

# Call chpathn on the remaining pathnames that need to be changed.

declare -a log         # The output of the command chpathn --verbose.
declare top_dirs       # A list of directories where to find by inode the
		       # the files and directories passed as arguments.
declare -a dir_inodes  # A list of inodes corresponding to every
		       # directory passed as argument.
declare -a file_inodes # A list of inodes corresponding to every file
		       # passed as argument.

if [[ $# > 0 ]]
then

	# Save the corresponding inode of the pathnames passed as arguments that
	# need to be changed.

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

	log=($(chpathn -rp --verbose "$@"))
	if [ $? -ne 0 ]
	then
		error_exit "$LINENO: Error after calling chpathn."
	fi
	if ! read_topdirs top_dirs ${log[@]}
	then
		error_exit "$LINENO: Error after a call to read_topdirs()."
	fi

	# If the --verbose option was given, print the content of the 'top_dirs'
	# array.

	if [[ $verbose == true ]]
	then
		printf ' -----------\n javiera log:\n -----------\n'
		printf ' * Top directories:\n'
		for dir in ${top_dirs[@]}
		do
			echo "$dir"
		done
		unset -v dir
	fi

	# Get the pathnames of the files passed as arguments after calling to
	# chpathn.

	if [[ ${#dir_inodes[@]} -ne 0 ]]
	then
		for inode in ${dir_inodes[@]}
		do
			dir=$(find ${top_dirs[@]} -depth -inum $inode -type d)
			files+=($(find $dir ${find_opts[@]} -type f))
		done
	fi

	unset -v dir
	unset -v dir_inodes

	if [[ ${#file_inodes[@]} -ne 0 ]]
	then
		for inode in ${file_inodes[@]}
		do
			files+=($(find ${top_dirs[@]} -depth -inum $inode -type f))
		done
	fi

	unset -v log
	unset -v inode
	unset -v file_inodes
	unset -v top_dirs
fi

# Update the database.

if ! process_fstab
then
	error_exit "$LINENO: Error after calling process_fstab()."
fi

for file in ${files[@]}
do
	file=$(readlink -f $file)
	[[ $? -ne 0 ]] && return 1
	if ! process_file $(hostname) $file 
	then
		error_exit "$LINENO: Error after calling process_file()."
	fi
done

unset -v file
unset -v files
