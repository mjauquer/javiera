
#! /bin/bash

# javiera-musicbrainz.bash <Music related functions of the javiera.bash script.>
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
# REQUIREMENTS: --
#         BUGS: --
#        NOTES: Any suggestion is welcomed at auq..r@gmail.com (fill in
#               the dots).

limit_mbcon () {

#       USAGE: limit_mbcon
#
# DESCRIPTION: Returns 0 when is safe to connect to musicbrainz.org.

	local now=$(date +%s)
	local recently=$(expr $now - 1)

	while [ $recently -le $MUSICBRAINZ_LTIME ]
	do
		now=$(date +%s)
		recently=$(expr $now - 1)
	done
}

process_artist_mbid () {

#       USAGE: process_artistmbid ARTIST_MBID
#
# DESCRIPTION: Search the database for an artist with MBID. If no artist
#              is found, get data from musicbrainz.org and update the
#              database.
#
#   PARAMETER: ARTIST_MBID A 36 character string used by musicbrainz.org
#                          as an unique identifier.

	local old_pwd=$(pwd)
	local temp_root="/dev/shm/javiera"
	local temp_dir
	local mbid=\'$1\'
	local queried_mbid
	local artist_type
	local artist_name
	local artist_sort
	local comment
	local wget_error
	
	queried_mbid=$($mysql_path --skip-reconnect -u$user -p$pass \
		-D$db --skip-column-names -e "

		SELECT mbid FROM artist WHERE mbid = $mbid;

	")
	[[ $? -ne 0 ]] && echo "Error after querying the database." && return 1

	if [ -z $queried_mbid ]
	then
		[[ ! -d $temp_root ]] && mkdir -p $temp_root
		cd $temp_root
		[[ $? -ne 0 ]] && echo "cd: could not change working directory." && return 1
		temp_dir=$(readlink -f $(mktemp -d tmp.XXX))
		limit_mbcon
		wget --wait=5 -q -O - "http://musicbrainz.org/ws/2/artist/$1" > $temp_dir/artist.xml
		wget_error=$?
		[[ $wget_error -ne 0 ]] && echo "wget: exit status is $wget_error" && return 1
		MUSICBRAINZ_LTIME=$(date +%s)

		artist_type="$(xml sel -N my=http://musicbrainz.org/ns/mmd-2.0# -t -m //my:metadata/my:artist/@type -v . $temp_dir/artist.xml)"
		[[ $? -ne 0 ]] && echo "xml: parsing error." && return 1
		artist_type=\'$artist_type\'

		artist_name="$(xml sel -N my=http://musicbrainz.org/ns/mmd-2.0# -t -m //my:metadata/my:artist/my:name -v . $temp_dir/artist.xml)"
		[[ $? -ne 0 ]] && echo "xml: parsing error." && return 1
		artist_name=\'$artist_name\'

		artist_sort="$(xml sel -N my=http://musicbrainz.org/ns/mmd-2.0# -t -m //my:metadata/my:artist/my:sort-name -v . $temp_dir/artist.xml)"
		[[ $? -ne 0 ]] && echo "xml: parsing error." && return 1
		artist_sort=\'$artist_sort\'

		comment="$(xml sel -N my=http://musicbrainz.org/ns/mmd-2.0# -t -m //my:metadata/my:artist/my:disambiguation -v . $temp_dir/artist.xml)"
		[[ $? -ne 0 ]] && echo "xml: parsing error." && return 1
		comment=\'$comment\'

		rm -r $temp_dir
		[[ $? -ne 0 ]] && echo "rm: could not remove temporal directory." && return 1
		cd $old_pwd
		[[ $? -ne 0 ]] && echo "cd: could not change working directory." && return 1

		$mysql_path --skip-reconnect -u$user -p$pass -D$db \
			--skip-column-names -e "

			START TRANSACTION;
			CALL insert_artist (
				$mbid,
				$artist_type,
				$artist_name,
				$artist_sort,
				$comment
			);
			COMMIT;
		"
		if [ $? -ne 0 ]
		then
			error_exit "$LINENO: Error after calling mysql."
		fi
	fi
}
