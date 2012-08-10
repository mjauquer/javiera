#! /bin/bash

# iso2dvd.bash (See description below).
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
# REQUIREMENTS: shellsql <http://sourceforge.net/projects/shellsql/>
#               javiera.flib
#         BUGS: --
#        NOTES: Any suggestion is welcomed at auq..r@gmail.com (fill in
#               the dots).

source ~/projects/javiera/shell-scripts/functions/javiera-core.bash

usage () {

#       USAGE: usage
#
# DESCRIPTION: Print a help message to stdout.

	cat <<- EOF
	Usage: iso2dvd SOURCE "DVD_TYPE" "DVD_TRADEMARK"

	Burn a dvd from the SOURCE image file. Update the backup
	database with the pertinent data.
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

# If no argument was passed, print usage message and exit.
[[ $# -eq 0 ]] && usage && exit

# Variables declaration.
declare progname # This script's name.

declare input    # The pathname of the image file to be burned.

declare version  # The version of the cdrecord command.

declare options  # The options to be passed to the cdrecord command.

declare handle   # A connection to the database.

progname=$(basename $0)

# Checking for a well-formatted command line.
if [ $# -ne 3 ]
then
	error_exit "$LINENO: Three arguments are required."
elif [[ $1 =~ .*/$ ]]
then
	error_exit "$LINENO: First argument must be a regular filename."
fi

#-----------------------------------------------------------------------
# Burn the DVD.
#-----------------------------------------------------------------------

options="-dummy -v -eject speed=4 dev=ATAPI:0,0,0" 
version="$(cdrecord -version)"
if [ $? -ne 0 ]
then
	error_exit "$LINENO: Error after calling cdrecord command."
fi
input=$(readlink -f $1)
if [ $? -ne 0 ]
then
	error_exit "$LINENO: Error after readlink command."
fi
if ! sudo cdrecord $options $input
then
	error_exit "$LINENO: Error after calling cdrecord command."
fi

#-----------------------------------------------------------------------
# Update the backup database.
#-----------------------------------------------------------------------

if [ $? -ne 0 ]
then
	error_exit "$LINENO: Error after calling shmysql utility."
fi
if ! get_id $handle imageid $(hostname) $input
then
	error_exit "$LINENO: Error after calling get_id()."
fi
if ! insert_dvd $handle $imageid $2 $3
then
	error_exit "$LINENO: Error after calling insert_dvd()."
fi
