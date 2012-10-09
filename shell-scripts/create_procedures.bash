#! /bin/bash

# create_procedures.bash <Create stored procedures in javiera db.>
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
declare -a procedures # An array with the stored procedures created in
                      # the 'javiera' database.

progname=$(basename $0)

#-----------------------------------------------------------------------
# BEGINNING OF MAIN CODE
#-----------------------------------------------------------------------

procedures=( $(mysql --skip-reconnect -u$admin_user -p$admin_pass \
	-D$db --skip-column-names -e "

	START TRANSACTION;
	source ~/projects/javiera/sql-scripts/create_procedures.mysql
	SELECT name FROM procedures WHERE level = 'user';
	COMMIT;

") )
[[ $? -ne 0 ]] && return 1

user=\'$user\'
pass=\'$pass\'

for procedure in ${procedures[@]}
do
	
	mysql --skip-reconnect -u$admin_user -p$admin_pass \
		-D$db --skip-column-names -e "
		
		GRANT EXECUTE ON PROCEDURE $db.$procedure
			TO $user@'%' IDENTIFIED BY $pass;

	"
	[[ $? -ne 0 ]] && return 1
done
