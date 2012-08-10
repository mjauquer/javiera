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
# REQUIREMENTS: javiera-core.bash
#               getoptx.bash
#         BUGS: --
#        NOTES: Any suggestion is welcomed at auq..r@gmail.com (fill in
#               the dots).

source ~/projects/javiera/shell-scripts/functions/javiera-core.bash
source ~/projects/javiera/getoptx/getoptx.bash
source ~/code/bash/chpathn/chpathn.flib

usage () {

#       USAGE: usage
#
# DESCRIPTION: Print a help message to stdout.
	
	cat <<- EOF
	Usage: dir2tar TAR_NAME pathname...
	dir2tar --listed-in TEXT_FILE TAR_NAME

	Create a tar archive named NAME and include in it the
	files founded in pathname...
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

predict_pathname_inside_archive () {

#       USAGE: predict_pathname_inside_archive PATHNAME
#
# DESCRIPTION: Predict the future path of the file pointed by PATHNAME
#              inside the archive file to be created. Store it in the
#              'suffixes' array and its sha1 fingerprint in the 'sha1s'
#              array.
#
#  PARAMETERS: PATHNAME The unix pathname of the file being processed.

	local suffix
	sha1s+=( $(sha1sum $1 | cut -c1-40) )
	suffix=${1#$prefix}
	suffixes+=( $suffix )
}

#-----------------------------------------------------------------------
# BEGINNING OF MAIN CODE
#-----------------------------------------------------------------------

# Variables declaration.
declare progname        # The name of this script.
declare -a file_systems # An array with the uuid fingerprints that
                        # correspond to file systems that have been 
			# found during this shell script session.
declare -a mount_points # An array with the mount points that correspond
                        # to file systems that have been found during
			# this shell script session.
declare user            # A mysql user name.
declare pass            # A mysql password.
declare db              # A mysql database.

db=$JAVIERA_DBNAME
pass=$JAVIERA_PASSWORD
progname=$(basename $0)
user=$JAVIERA_USER

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
declare -a pathnames # A list of the pathnames of the files and
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

# Create a temporal directory.
declare tempdir        # The pathname of a temporal directory where the
                       # files and directories will be processed.
tempdir=$(readlink -f $(mktemp -d tmp.XXX))
chmod 755 $tempdir
if [ ! -d $tempdir ]
then
	error_exit "$LINENO: Coudn't create a temporal directory."
fi

# Copy the files and directories to be processed to the temporal
# directory.
declare -a sha1s     # See comments in predict_pathname_inside_archive
                     # function.
declare prefix
declare -a suffixes  # A list of the pathnames of the archived files
                     # inside the archive file. 

for pathname in ${pathnames[@]}
do
	prefix=${pathname%/*}
	if [ -d $pathname ]
	then
		for file in $(find $pathname -type f)
		do
			predict_pathname_inside_archive $file
		done
	elif [ -f $pathname ]
	then
		predict_pathname_inside_archive $pathname
	fi
	dest=$tempdir/$(basename $pathname)
	if ! cp -r $pathname $dest
	then
		error_exit "$LINENO: Error after calling mv command."
	fi
done
unset -v dest
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
declare version  # The version of the tar utility.
declare tarsha1  # The sha1 fingerprint of the newly created tar file.

pathnames=( $(find $(ls)) )
tar -cf $1 ${pathnames[@]}
if [ $? -ne 0 ]
then
	error_exit "$LINENO: Error after calling tar utility."
fi
tarfile=$(readlink -f $1)

# Insert in the database metadata about the created tar file.
if ! javiera $tarfile
then
	error_exit "$LINENO: Error after calling javiera."
fi

# Insert in the database metadata about this tar utility session. 
version="$(tar --version | head -n 1)"; version=\'$version\'
tarsha1=$(sha1sum $tarfile | cut -c1-40); tarsha1=\"$tarsha1\"
mysql --skip-reconnect -u$user -p$pass --skip-column-names -e "

	USE javiera;
	CALL process_output_file (
		'tar',
		$version,
		'cf',
		$tarsha1
	);
"
if [ $? -ne 0 ]
then
	error_exit "$LINENO: Error after calling mysql."
fi
unset -v tarsha1
unset -v version

#-----------------------------------------------------------------------
# Update the backup database with the archive relationships.
#-----------------------------------------------------------------------

# Insert archive relationships between the tar file and the archived
# files.
declare archive_sha1  # The sha1 fingerprint of the created tar file.
declare filesha1      # The sha1 fingerprint of an archived file.

tarsha1=$(sha1sum $tarfile | cut -c1-40); tarsha1=\"$tarsha1\"
for (( ind=0; ind<${#sha1s[@]}; ind++ ))
do
	filesha1=${sha1s[ind]}; filesha1=\"$filesha1\"
	suffix=${suffixes[ind]};  suffix=\"$suffix\"
	
	mysql --skip-reconnect -u$user -p$pass \
		--skip-column-names -e "

		USE javiera;
		CALL process_archived_file (
			$tarsha1,
			$filesha1,
			$suffix
		);
	"
	if [ $? -ne 0 ]
	then
		error_exit "$LINENO: Error after calling mysql."
	fi
done
unset -v filesha1
unset -v ind
unset -v sha1s
unset -v suffix
unset -v suffixes
unset -v tarfile
unset -v tarsha1

# Move tar to the final directory.
declare tarbname   # Archive file's basename.
declare tarabsname # Archive file's absolute name.

tarbname=$(basename $1)
if ! mv $1 ..
then
	error_exit "$LINENO: Error after calling mv command."
fi

if ! cd ..
then
	error_exit "$LINENO: Error after calling cd command."
fi
tarabsname=$(readlink -f $tarbname)

# Update the columns <file_system_id> and <pathname> into table 
# 'file_system_location' the entry related to the new archive file.

declare file_sys # The uuid fingerprint of the file system where
	         # the file pointed by PATHNAME is located.             
declare old_path # The pathname of the archive file before it was moved
                 # (when it was under de temporary directory), relative
		 # to the mount point of the file system where it was located.
declare new_path # The final pathname of the archive file.

process_fstab
if ! get_file_system_location file_sys old_path ${tempdir}/${tarbname}
then
	error_exit "$LINENO: Error after calling get_matching_fs...()."
fi

file_sys=\'$file_sys\'
old_path=\'$old_path\'

if ! get_file_system_location file_sys new_path $tarabsname
then
	error_exit "$LINENO: Error after calling get_matching_fs...()."
fi

file_sys=\'$file_sys\'
new_path=\'$new_path\'

mysql --skip-reconnect -u$user -p$pass \
	--skip-column-names -e "

	USE javiera;
	SELECT fs_location.id INTO @fs_loc_id
		FROM file_system_location AS fs_location
		INNER JOIN file_system AS fs
		ON fs_location.file_system_id = fs.id
		WHERE fs_location.pathname = $old_path;
	UPDATE file_system_location SET
		file_system_id = (SELECT id
					FROM file_system
					WHERE uuid = $file_sys),
		pathname = $new_path
	WHERE
		file_system_location.id = @fs_loc_id
	;
	"
if [ $? -ne 0 ]
then
	error_exit "$LINENO: Error after calling mysql."
fi

unset -v file_sys
unset -v newpath
unset -v pathname
unset -v oldpath
unset -v tarabsname
unset -v tarbname

# Remove the temporary directory.
rm -r $tempdir
if [ $? -ne 0 ]
then
	error_exit "$LINENO: Error after calling rm command."
fi
unset -v tempdir
