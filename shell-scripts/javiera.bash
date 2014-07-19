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
source $JAVIERA_HOME/shell-scripts/functions/javiera-core.bash ||
	exit 1
source $JAVIERA_HOME/submodules/getoptx/getoptx.bash || exit 1
source ~/code/bash/chpathn/chpathn.flib || exit 1

usage () {

#        NAME: usage
#
#       USAGE: usage
#
# DESCRIPTION: Print a help message to stdout.

	cat <<- EOF
	Syntax: javiera.sh [OPTIONS] PATH...
	
	Collect and store in a backup database metadata about files.
	PATH... is a list of files or directories.

	Options:

	 -r
	 -R
	--recursive    Do all actions recursively.
	--ripdata      Argument of this option is "RIPPER|DATE_OF_RIP".
	               It is invoked in order to add data about an audio
		       flac's ripper. It will be assumed that this data
		       describes each audio file to be found in PATH...
	--update       Search for changes in files' metadata and update
	               the database.
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

if [ ! -d $tmp_root ]
then
	mkdir -p $tmp_root || error_exit "$LINENO: Error after trying to create a temporal directory."
fi

# Parse command line options.

declare -a find_opts # A list of options to be passed to the find
                     # command.
declare ripdata      
declare ripper
declare ripdate
declare update
declare verbose
declare regex="^(.)*\|[0-9]{4}-[0-9]{2}-[0-9]{2}$"

find_opts=( -maxdepth 1 )
while getoptex "r recursive R ripdata: update verbose" "$@"
do
	case "$OPTOPT" in
		r)         find_opts=( -depth )
			   ;;
		recursive) find_opts=( -depth )
		           ;;
		R)         find_opts=( -depth )
		           ;;
		ripdata)   ripdata=true
		           if [[ $OPTARG =~ $regex ]]
			   then
		           	ripper=${OPTARG%\|????-??-??}
				ripdate=${OPTARG#*\|}
			   else
		           	error_exit "$LINENO: Wrong format in ripdata argument."
			   fi
			   ;;
		update)    update=true
		           ;;
		verbose)   verbose=true
	esac
done
shift $(($OPTIND-1))
unset -v regex

# Select from the list of pathname arguments, those that do not need to
# be changed. Store them in the 'files' array.

declare -a files # The list of pathnames to be processed by this script.

declare oldifs   # Stores the content of the IFS variable as it 
                 # was when this script was called.
declare regex="^[0-9A-Za-z./_+]{1}[-0-9A-Za-z./_+]*$"
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
		       # files and directories passed as arguments.
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
	unset -v verbose

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
	unset -v find_opts
	unset -v top_dirs
fi

# Update the database.

if ! process_fstab
then
	error_exit "$LINENO: Error after calling process_fstab()."
fi

declare query_file=$tmp_root/query.mysql
for file in ${files[@]}
do
	file=$(readlink -f $file)
	[[ $? -ne 0 ]] && error_exit "$LINENO: readlink command returned an error."

	> $query_file
	if ! process_file $(hostname) $file $query_file
	then
		error_exit "$LINENO: Error after calling process_file()."
	fi

	$mysql_path --skip-reconnect -u$user -p$pass -D$db \
		--skip-column-names -e "

		START TRANSACTION;
		source $query_file
		COMMIT;
	"
	[[ $? -ne 0 ]] && error_exit "$LINENO: error after querying the database."
done
rm $query_file
[[ $? -ne 0 ]] && error_exit "$LINENO: error after trying to remove ${query_file}."

unset -v file
unset -v files
unset -v ripdata      
unset -v ripper
unset -v ripdate
unset -v update
unset -v verbose
