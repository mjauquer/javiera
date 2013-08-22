#! /bin/bash

# insert_rip_credits.bash (See description below).
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
#  DESCRIPTION: Burn a dvd from the SOURCE image file. Update the backup
#               database with the pertinent data.
#
# REQUIREMENTS: --
#         BUGS: --
#        NOTES: Any suggestion is welcomed at auq..r@gmail.com (fill in
#               the dots).

source ~/.myconf/javiera.cnf || exit 1

usage () {

#       USAGE: usage
#
# DESCRIPTION: Print a help message to stdout.
	
	cat <<- EOF
	Usage: insert_rip_credits TARGET_DIR RIPPER RIPDATE

	Search TARGET_DIR for flac files and tag them with the nickname
	of the ripper and the date of the rip. This information is
	inserted in the database as well.
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

insert_ripper () {
	
#       USAGE: insert_ripper RIPPER
#
# DESCRIPTION: Insert RIPPER in the table `ripper' of the database.
#
#  PARAMETERS: RIPPER  The ripper's nickname.
	
	local ripper="$1"
	ripper="'$ripper'"

	$mysql_path --skip-reconnect -u$user -p$pass -D$db \
		--skip-column-names -e "

		START TRANSACTION;
		CALL insert_ripper ($ripper);
		COMMIT;
	"
	if [ $? -ne 0 ]
	then
		error_exit "$LINENO: Error after a call to mysql."
	else
		echo "$ripper has been inserted."
	fi
	return 0
}

print_rippers () {
	
#       USAGE: print_rippers
#
# DESCRIPTION: Print the list of the rippers that are registered in the
#              database.
	
	$mysql_path --skip-reconnect -u$user -p$pass -D$db -e "

		SELECT id, name
			FROM ripper
			ORDER BY name
		;
	"
	[[ $? -ne 0 ]] && return 1

	return 0
}

#-----------------------------------------------------------------------
# BEGINNING OF MAIN CODE
#-----------------------------------------------------------------------

declare progname="$0"
declare target_dir="$1"
declare ripper="$2"
declare rip_date="$3"

# If no argument were passed, print usage message and exit.
[[ $# -eq 0 ]] && usage && exit

# Check if ripper exists in the database
ripper_id=$($mysql_path --skip-reconnect -u$user -p$pass -D$db \
	--skip-column-names -e "

	SELECT id
		FROM ripper
		WHERE name = '$ripper'
	;
")
if [ $? -ne 0 ]
then
	error_exit "$LINENO: Error after trying a query to the database."
fi

if [ ! $ripper_id ]
then
	declare option
	printf "\n> '%b' do not exist as a ripper in the database.\n" "$ripper"
	while printf "\n> What do you want to do next?\n>    p) Print a list of registered rippers and quit\n>    i) Insert '%b' in the database and continue\n$ " "$ripper"
	do
		read option
		case $option in
			i|I)  insert_ripper $ripper
			      break
			      ;;
			p|P)  print_rippers
			      exit 0
			      ;;
			  *)  printf "> %b is not a valid option." $option
			      ;;
		esac
	done
	unset -v option
fi

# Search for flac files in target_dir
declare -a flac_files

for file in $(find $target_dir -name '*.flac')
do
	flac_files+=( "$file" )
done

# Check for an already existing RIPPER field in flac files' metadata
declare -a tag
declare conflicts=false

for file in ${flac_files[@]}
do
	tag=( "$(metaflac --show-tag=RIPPER $file)" )
	if [[ ${tag[0]} != "" ]]
	then
		echo "There is at least one 'RIPPER' tag in file: $file"
		conflicts=true
	fi
done
unset -v file

# Check for an already existing RIPDATE field in flac files' metadata
declare -a tag
declare conflicts=false

for file in ${flac_files[@]}
do
	tag=( "$(metaflac --show-tag=RIPDATE $file)" )
	if [[ ${tag[0]} != "" ]]
	then
		echo "There is at least one 'RIPDATE' tag in file: $file"
		conflicts=true
	fi
done
unset -v file

[[ $conflicts == true ]] && unset -v conflicts && exit 1
unset -v conflicts

# Ok, let's tag them
for file in ${flac_files[@]}
do
	metaflac --set-tag="RIPPER=$ripper" $file
	metaflac --set-tag="RIPDATE=$rip_date" $file
done
unset -v file
