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
#               javiera.flib
#               getoptx.bash
#         BUGS: --
#        NOTES: Any suggestion is welcomed at auq..r@gmail.com (fill in
#               the dots).

source ~/code/bash/javiera/shell-scripts/functions/javiera-core.bash
source ~/code/bash/javiera/getoptx/getoptx.bash
source ~/code/bash/chpathn/chpathn.flib


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
	[ -v handle ] && shsqlend $handle
	exit 1
}

#===  FUNCTION =========================================================
#
#       USAGE: predict_newpath FILE
#
# DESCRIPTION: Predict the new pathname of FILE if it would been moved
#              to the temporal directory and store it in the 'newpaths'
#              array, while storing its file id (from the database) in
#              the 'ids' array, for further operation.
#
#  PARAMETERS: FILE  A connection to a database.
#
predict_newpath () {
	local suffix
	local file_id
	if ! get_id $handle file_id $(hostname) $1
	then
		error_exit "$LINENO: Error after calling get_id()."
	fi
	ids+=( $file_id )
	suffix=${1#$prefix}
	suffixes+=( $suffix )
	newpaths+=( $tempdir/$suffix )
}

#-----------------------------------------------------------------------
# BEGINNING OF MAIN CODE
#-----------------------------------------------------------------------

# Variables declaration.
declare progname       # The name of this script.

progname=$(basename $0)

# If no argument were passed, print usage message and exit.
[[ $# -eq 0 ]] && usage && exit

# Parse command line options.
declare txtfile        # The pathname of the file passed as argument to
                       # the --listed-in option.
while getoptex "listed-in:" "$@"
do
	case "$OPTOPT" in
		listed-in) txtfile="$OPTARG"
		            ;;
	esac
done

# If this script was called with the  "listed-in" option, add to the
# list of pathnames to be processed those which are listed in the text
# file specified.
declare -a pathnames   # A list of the pathnames of the files and
                       # directories that have been passed to this script.
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
unset -v line
unset -v txtfile
shift $(($OPTIND-1))

# Add to the list of pathnames to be processed, those which were passed
# as command line arguments.
pathnames+=( ${@:2} )

# Check the existence of the files passed as arguments.
declare -a notfound    # A list of pathnames passed as arguments to this
                       # script and that do not point to existing files or
		       # directories in the filesystem.
for pathname in ${pathnames[@]}
do
	if [ \( ! -d $pathname \) -a \( ! -f $pathname \) ]
	then
		notfound+=("$pathname")
	fi
done
unset -v pathname
if [ ${#notfound[@]} -ne 0 ]
then
	error_exit "$LINENO: The following arguments do not exist as
regular files or directories in the filesystem:
$(for file in ${notfound[@]}; do echo "$file"; done)"
fi
unset -v notfound

# Check if the pathname of the output tar file is a valid one.
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

# Save the corresponding inode of the pathnames passed as arguments to
# this script.
declare -a dir_inodes  # A list of inodes corresponding to every
                       # directory passed as argument.
declare -a file_inodes # A list of inodes corresponding to every file
                       # passed as argument.
for pathname in ${pathnames[@]}
do
	if [ -d "$pathname" ]
	then
		dir_inodes+=($(stat -c %i "$pathname"))
		[ $? -ne 0 ] && error_exit
	elif [ -f "$pathname" ]
	then
		file_inodes+=($(stat -c %i "$pathname"))
		[ $? -ne 0 ] && error_exit
	fi
done
unset -v pathname

# Update the database with data about the files passed as arguments.
declare -a log   # The output of the command javiera --verbose.
declare top_dirs # A list of directories where to find by inode the
                 # files and directories passed as arguments.
log=($(javiera -r --verbose ${pathnames[@]}))
if [ $? -ne 0 ]
then
	error_exit "$LINENO: Error after calling javiera."
fi
if ! read_topdirs top_dirs ${log[@]}
then
	error_exit "$LINENO: Error after a call to read_topdirs()."
fi
unset -v log

# After last command, pathnames might been changed. Use the saved inodes
# to get the corresponding pathnames.
for inode in ${dir_inodes[@]}
do
	pathnames=($(find ${top_dirs[@]} -depth -inum $inode -type d))
done
unset -v inode
unset -v dir_inodes
for inode in ${file_inodes[@]}
do
	pathnames+=($(find ${top_dirs[@]} -depth -inum $inode -type f))
done
unset -v inode
unset -v file_inodes

# Connect to the database.
declare handle # Required by shsql. A connection to the database.
handle=$(shmysql user=$JAVIERA_USER password=$JAVIERA_PASSWORD \
	dbname=$JAVIERA_DBNAME) 
if [ $? -ne 0 ]
then
	error_exit "$LINENO: Error after calling shmysql utility."
fi

# Create a temporal directory.
declare tempdir        # The pathname of a temporal directory where the
                       # files and directories will be processed.
tempdir=$(readlink -f $(mktemp -d tmp.XXX))
chmod 755 $tempdir
if [ ! -d $tempdir ]
then
	error_exit "$LINENO: Coudn't create a temporal directory."
fi

# Move the files and directories to be processed to the temporal
# directory.
declare -a newpaths
declare -a ids       # A list of the file_ids in the database of the
                     # files beeing archived.
declare prefix
declare -a suffixes  # A list of the pathnames of the archived files
                     # inside the archiver file. 
for pathname in ${pathnames[@]}
do
	prefix=${pathname%/*}/
	if [ -d $pathname ]
	then
		for file in $(find $pathname -type f)
		do
			predict_newpath $file
		done
	elif [ -f $pathname ]
	then
		predict_newpath $pathname
	fi
	dest=$tempdir/$(basename $pathname)
	if ! mv $pathname $dest
	then
		error_exit "$LINENO: Error after calling mv command."
	fi

	# After moving the files, update the database using the
	# previously predicted pathnames of the files.
	for (( ind=0; ind<${#ids[@]}; ind++ ))
	do
		if ! shsql $handle $(printf '
			UPDATE path INNER JOIN file
			ON file.path_id = path.id
			SET name="%b"
			WHERE file.id=%b;
			' ${newpaths[ind]} ${ids[ind]})
		then
			error_exit "$LINENO: Error after calling shsql."
		elif ! shsql $handle $(printf '
			UPDATE file SET mtime="%b" WHERE id=%b;
			' $(stat --format='%Y' $dest) ${ids[ind]})
		then
			error_exit "$LINENO: Error after calling shsql."
		fi
	done
	unset -v ind
done
unset -v dest
unset -v newpaths
unset -v pathname
unset -v prefix

# Set the temporal directory as the working directory.
cd $tempdir
if [ $? -ne 0 ]
then
	error_exit "$LINENO: Error after calling cd command."
fi

# Create a tar file.
declare tarfile  # The pathname of the tar file to be created.
pathnames=( $(find $(ls)) )
tar -cf $1 ${pathnames[@]}
if [ $? -ne 0 ]
then
	error_exit "$LINENO: Error after calling tar utility."
fi
tarfile=$(readlink -f $1)

# Update the backup database.
javiera $tarfile
if [ $? -ne 0 ]
then
	error_exit "$LINENO: Error after calling javiera."
fi

#-----------------------------------------------------------------------
# Update the backup database with the archive relationships.
#-----------------------------------------------------------------------

# Get the id of the created tar file.
declare archiver_id    # The id number in the file table of the database
                       # of the created tar file.
get_id $handle archiver_id $(hostname) $tarfile
if [ $? -ne 0 ]
then
	error_exit "$LINENO: Error after calling get_id()."
fi

# Insert archive relationships between the tar file and its content.
for (( ind=0; ind<${#ids[@]}; ind++ ))
do
	insert_archive $handle $archiver_id ${ids[ind]} ${suffixes[ind]}
	if [ $? -ne 0 ]
	then
		error_exit "$LINENO: Error after calling insert_archive()."
	fi
done
unset -v ids
unset -v ind
unset -v tarfile
unset -v suffixes

#-----------------------------------------------------------------------
# Remove the temporary directory.
#-----------------------------------------------------------------------

mv $1 ..
if [ $? -ne 0 ]
then
	error_exit "$LINENO: Error after calling mv command."
fi
cd ..
if [ $? -ne 0 ]
then
	error_exit "$LINENO: Error after calling cd command."
fi
rm -r $tempdir
unset -v tempdir
if [ $? -ne 0 ]
then
	error_exit "$LINENO: Error after calling rm command."
fi

#-----------------------------------------------------------------------
# Update the backup database with this last movement.
#-----------------------------------------------------------------------

# Update the pathname of the tar file.
shsql $handle $(printf '
			UPDATE path
			INNER JOIN file ON file.path_id = path.id
			SET name="%b"
			WHERE file.id=%b;
	' $(readlink -f $1) $archiver_id)
if [ $? -ne 0 ]
then
	error_exit "$LINENO: Error while trying to update the database."
fi

# This will reflect in the database the deletion of the temporal
# directory.
javiera -r .
if [ $? -ne 0 ]
then
	error_exit "$LINENO: Error while trying to update the database."
fi

# Close the connection to the database.
shsqlend $handle
unset -v handle
