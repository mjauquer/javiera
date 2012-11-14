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

declare progname      # The name of this script.
declare admin_user    # A mysql user name.
declare admin_pass    # A mysql password.
declare user          # A mysql user name.
declare pass          # A mysql password.
declare db            # A mysql database.
declare -a tables     # An array with the tables created in
                      # the 'javiera' database.

progname=$(basename $0)

#-----------------------------------------------------------------------
# BEGINNING OF MAIN CODE
#-----------------------------------------------------------------------

# Get a list of all the tables in the database.

tables=( $($mysql_path --skip-reconnect -u$admin_user -p$admin_pass \
	-D$db --skip-column-names -e "

	SHOW TABLES;
") )
[[ $? -ne 0 ]] && return 1

user=\'$user\'
pass=\'$pass\'

# Remove every table in the database.

for table in ${tables[@]}
do
	table=\`$table\`
	$mysql_path --skip-reconnect -u$admin_user -p$admin_pass \
		-D$db --skip-column-names -e "
		
		DROP TABLE $table;

	"
	[[ $? -ne 0 ]] && exit 1
done

# Create the tables.

$mysql_path --skip-reconnect -u$admin_user -p$admin_pass \
	-D$db --skip-column-names -e "
	
	START TRANSACTION;
	source ~/projects/javiera/sql-scripts/create_coretables.mysql
	source ~/projects/javiera/sql-scripts/populate_tables.mysql
	COMMIT;

"
