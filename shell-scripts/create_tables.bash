#! /bin/bash

# create_tables.bash <Create tables in javiera db.>
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
# REQUIREMENTS: mysql
#         BUGS: --
#        NOTES: Any suggestion is welcomed at auq..r@gmail.com (fill in
#               the dots).

source ~/.myconf/javiera.cnf || exit 1
source $JAVIERA_HOME/submodules/getoptx/getoptx.bash || exit 1

usage () {

#        NAME: usage
#
#       USAGE: usage
#
# DESCRIPTION: Print a help message to stdout.

	cat <<- EOF
	Usage: create_tables.sh [OPTIONS] 
	
	Create the tables of the 'javiera' database.

	 -h         Print this help.
	--force     Delete any existing table in the database before
	            creating the tables.
	--populate  Populate some tables with predetermined rows.
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

declare progname       # The name of this script.
declare admin_user     # A mysql user name.
declare admin_pass     # A mysql password.
declare db             # A mysql database.
declare -a tabs        # An array with the tables created in
                       # the 'javiera' database.
declare force=false    # Indicates if it is required to delete previously
                       # existing tables.
declare populate=false # Indicates if it is required to populate the tables
                       # with predetermined rows.

progname=$(basename $0)

# Parse the options passed in the command line.

while getoptex "h force populate" "$@"
do
	case "$OPTOPT" in
		h)        usage; exit 0
		          ;;
		force)    force=true
			  ;;
		populate) populate=true
	esac
done
shift $(($OPTIND-1))

if [ $force == true ]
then
	# Get a list of all the tables in the database.
	tables=( $($mysql_path --skip-reconnect -u$admin_user -p$admin_pass \
		-D$db --skip-column-names -e "

		SHOW TABLES;
	") )
	[[ $? -ne 0 ]] && return 1

	# Remove every table in the database.
	for table in ${tables[@]}
	do
		table=\`$table\`
		$mysql_path --skip-reconnect -u$admin_user -p$admin_pass \
			-D$db --skip-column-names -e "
			
			DROP TABLE $table;

		"
		if [ $? -ne 0 ]
		then
			error_exit "$LINENO: Error after trying to drop a table."
		fi
	done
fi

# Create the tables.

$mysql_path --skip-reconnect -u$admin_user -p$admin_pass \
	-D$db --skip-column-names -e "
	
	START TRANSACTION;
	source $JAVIERA_HOME/sql-scripts/create_tables.mysql
	COMMIT;

"
if [ $? -ne 0 ]
then
	error_exit "$LINENO: Error after trying to create tables."
fi

if [ $populate == true ]
then
	$mysql_path --skip-reconnect -u$admin_user -p$admin_pass \
		-D$db --skip-column-names -e "
		
		START TRANSACTION;
		source $JAVIERA_HOME/sql-scripts/populate_tables.mysql
		COMMIT;

	"
	if [ $? -ne 0 ]
	then
		error_exit "$LINENO: Error after trying to populate tables."
	fi
fi
