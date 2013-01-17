#! /bin/bash

# javiera-musicbrainz.bash <musicbrainz.org related functions for the
#                          javiera.bash script.>
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

#       USAGE: process_artist_mbid ARTIST_MBID
#
# DESCRIPTION: Search the database for an artist with the ARTIST_MBID.
#              If no artist is found, get data from musicbrainz.org and
#              update the database.
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
	local xmlns="http://musicbrainz.org/ns/mmd-2.0#"
	
	# Is this artist already in the database?
	queried_mbid=$($mysql_path --skip-reconnect -u$user -p$pass \
		-D$db --skip-column-names -e "

		SELECT mbid FROM artist WHERE mbid = $mbid;

	")
	[[ $? -ne 0 ]] && echo "Error after querying the database." && return 1

	# If it is not, update it.
	if [ -z $queried_mbid ]
	then
		# Query musicbrainz.
		[[ ! -d $temp_root ]] && mkdir -p $temp_root
		cd $temp_root
		[[ $? -ne 0 ]] && echo "cd: could not change working directory." && return 1
		temp_dir=$(readlink -f $(mktemp -d tmp.XXX))
		limit_mbcon
		wget --wait=5 -q -O - "http://musicbrainz.org/ws/2/artist/$1" > $temp_dir/artist.xml
		wget_error=$?
		[[ $wget_error -ne 0 ]] && echo "wget: exit status is $wget_error" && return 1

		MUSICBRAINZ_LTIME=$(date +%s)

		# Parse data.
		if xml el -a $temp_dir/artist.xml | grep -q "metadata/artist/@type"
		then
			artist_type="$(xml sel -N my=$xmlns -t -m //my:metadata/my:artist/@type -v . $temp_dir/artist.xml)"
			[[ $? -ne 0 ]] && echo "xml: parsing error." && return 1
		fi
		artist_type=\'$artist_type\'

		if xml el $temp_dir/artist.xml | grep -q "metadata/artist/name"
		then
			artist_name="$(xml sel -N my=$xmlns -t -m //my:metadata/my:artist/my:name -v . $temp_dir/artist.xml)"
			[[ $? -ne 0 ]] && echo "xml: parsing error." && return 1
		fi
		escape_chars artist_name "$artist_name"; artist_name=\'$artist_name\'

		if xml el $temp_dir/artist.xml | grep -q "metadata/artist/sort-name"
		then
			artist_sort="$(xml sel -N my=$xmlns -t -m //my:metadata/my:artist/my:sort-name -v . $temp_dir/artist.xml)"
			[[ $? -ne 0 ]] && echo "xml: parsing error." && return 1
		fi
		escape_chars artist_sort "$artist_sort"; artist_sort=\'$artist_sort\'

		if xml el $temp_dir/artist.xml | grep -q "metadata/artist/disambiguation"
		then
			comment="$(xml sel -N my=$xmlns -t -m //my:metadata/my:artist/my:disambiguation -v . $temp_dir/artist.xml)"
			[[ $? -ne 0 ]] && echo "xml: parsing error." && return 1
		fi
		escape_chars comment "$comment"; comment=\'$comment\'

		rm -r $temp_dir
		[[ $? -ne 0 ]] && echo "rm: could not remove temporal directory." && return 1
		cd $old_pwd
		[[ $? -ne 0 ]] && echo "cd: could not change working directory." && return 1

		# Update the database.
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
	return 0
}

process_recording_mbid () {

#       USAGE: process_recording_mbid RECORDING_MBID
#
# DESCRIPTION: Search the database for a recording with the RECORDING_MBID
#              If no recording is found, get data from musicbrainz.org
#              and update the database.
#
#   PARAMETER: RECORDING_MBID A 36 character string used by musicbrainz.org
#                          as an unique identifier.

	local old_pwd=$(pwd)
	local temp_root="/dev/shm/javiera"
	local temp_dir
	local mbid=\'$1\'
	local -a artists
	local -a artist_ids
	local recording_id
	local queried_mbid
	local recording_name
	local recording_length
	local comment
	local wget_error
	
	# Is this recording already in the database?
	queried_mbid=$($mysql_path --skip-reconnect -u$user -p$pass \
		-D$db --skip-column-names -e "

		SELECT mbid FROM recording WHERE mbid = $mbid;

	")
	[[ $? -ne 0 ]] && echo "Error after querying the database." && return 1

	# If it is not, update it.
	if [ -z $queried_mbid ]
	then
		# Query musicbrainz.
		[[ ! -d $temp_root ]] && mkdir -p $temp_root
		cd $temp_root
		[[ $? -ne 0 ]] && echo "cd: could not change working directory." && return 1
		temp_dir=$(readlink -f $(mktemp -d tmp.XXX))
		limit_mbcon
		wget --wait=5 -q -O - "http://musicbrainz.org/ws/2/recording?query=rid:$1" > $temp_dir/rec.xml
		wget_error=$?
		[[ $wget_error -ne 0 ]] && echo "wget: exit status is $wget_error" && return 1
		MUSICBRAINZ_LTIME=$(date +%s)

		xml ed $temp_dir/rec.xml | sed -e 's/ xmlns.*=".*"//g' | sed -e 's/ext://g' > $temp_dir/recording.xml

		# Parse data.
		if xml el $temp_dir/recording.xml | grep -q "metadata/recording-list/recording/title"
		then
			recording_name="$(xml sel -t -m //metadata/recording-list/recording/title -v . $temp_dir/recording.xml)"
			[[ $? -ne 0 ]] && echo "xml: parsing error." && return 1
		fi
		escape_chars recording_name "$recording_name"; recording_name=\'$recording_name\'

		if xml el $temp_dir/recording.xml | grep -q "metadata/recording-list/recording/length"
		then
			recording_length="$(xml sel -t -m //metadata/recording-list/recording/length -v . $temp_dir/recording.xml)"
			[[ $? -ne 0 ]] && echo "xml: parsing error." && return 1
		fi
		escape_chars recording_length "$recording_length"; recording_length=\'$recording_length\'

		if xml el $temp_dir/recording.xml | grep -q "metadata/recording-list/recording/disambiguation"
		then
			comment="$(xml sel -t -m //metadata/recording-list/recording/disambiguation -v . $temp_dir/recording.xml)"
			[[ $? -ne 0 ]] && echo "xml: parsing error." && return 1
		fi
		escape_chars comment "$comment"; comment=\'$comment\'

		# Insert recording.
		$mysql_path --skip-reconnect -u$user -p$pass -D$db \
			--skip-column-names -e "

			START TRANSACTION;
			CALL insert_recording (
				$mbid,
				$recording_name,
				$recording_length,
				$comment
			);
			COMMIT;
		"
		if [ $? -ne 0 ]
		then
			error_exit "$LINENO: Error after calling mysql."
		fi
		recording_id=$($mysql_path --skip-reconnect -u$user -p$pass \
			-D$db --skip-column-names -e "

			SELECT id FROM recording WHERE mbid = $mbid;

		")
		[[ $? -ne 0 ]] && echo "Error after querying the database." && return 1
		recording_id=\'$recording_id\'

		# Insert artist-recording relationships.
		if xml el -a $temp_dir/recording.xml | grep -q "metadata/recording-list/recording/artist-credit/name-credit/artist/@id"
		then
			artists=( $(xml sel -t -m //metadata/recording-list/recording/artist-credit/name-credit/artist/@id -n -v . $temp_dir/recording.xml) )
			[[ $? -ne 0 ]] && echo "xml: parsing error." && return 1
			for artist in ${artists[@]}
			do
				process_artist_mbid $artist
				[[ $? -ne 0 ]] && echo "Error after calling to process_artist_mbid()." && return 1
				artist=\'$artist\'
				artist_ids+=( $($mysql_path --skip-reconnect -u$user -p$pass \
					-D$db --skip-column-names -e "

					SELECT id FROM artist WHERE mbid = $artist;

				") )
				[[ $? -ne 0 ]] && echo "Error after querying the database." && return 1
			done
			for artist_id in ${artist_ids[@]}
			do
				artist_id=\'$artist_id\'
				$mysql_path --skip-reconnect -u$user -p$pass -D$db \
					--skip-column-names -e "

					START TRANSACTION;
					CALL link_artist_to_recording (
						$artist_id,
						'is credited for',
						$recording_id
					);
					COMMIT;
				"
				if [ $? -ne 0 ]
				then
					error_exit "$LINENO: Error after calling mysql."
				fi
			done
		fi

		# Delete temporal directory.
		rm -r $temp_dir
		[[ $? -ne 0 ]] && echo "rm: could not remove temporal directory." && return 1
		cd $old_pwd
		[[ $? -ne 0 ]] && echo "cd: could not change working directory." && return 1
	fi
	return 0
}

process_release_mbid () {

#       USAGE: process_release_mbid release_MBID
#
# DESCRIPTION: Search the database for a release with the
#              release_MBID. If no release is found, get
#              data from musicbrainz.org and update the database.
#
#   PARAMETER: release_MBID A 36 character string used by musicbrainz.org
#                          as an unique identifier.

	local old_pwd=$(pwd)
	local temp_root="/dev/shm/javiera"
	local temp_dir
	local mbid=\'$1\'
	local queried_mbid
	local -a artists
	local -a artist_ids
	local -a recordings
	local -a recording_ids
	local release_id
	local release_name
	local release_status
	local release_group
	local release_group_id
	local comment
	local wget_error
	
	# Is this release already in the database?
	queried_mbid=$($mysql_path --skip-reconnect -u$user -p$pass \
		-D$db --skip-column-names -e "

		SELECT mbid FROM \`release\` WHERE mbid = $mbid;

	")
	[[ $? -ne 0 ]] && echo "Error after querying the database." && return 1

	# If it is not, update it.
	if [ -z $queried_mbid ]
	then
		# Query musicbrainz.
		[[ ! -d $temp_root ]] && mkdir -p $temp_root
		cd $temp_root
		[[ $? -ne 0 ]] && echo "cd: could not change working directory." && return 1
		temp_dir=$(readlink -f $(mktemp -d tmp.XXX))
		limit_mbcon
		wget --wait=5 -q -O - "http://musicbrainz.org/ws/2/release?query=reid:$1" > $temp_dir/rel.xml
		wget_error=$?
		[[ $wget_error -ne 0 ]] && echo "wget: exit status is $wget_error" && return 1
		MUSICBRAINZ_LTIME=$(date +%s)

		xml ed $temp_dir/rel.xml | sed -e 's/ xmlns.*=".*"//g' | sed -e 's/ext://g' > $temp_dir/release.xml

		# Parse data.
		if xml el $temp_dir/release.xml | grep -q "metadata/release-list/release/status"
		then
			release_status="$(xml sel -t -m //metadata/release-list/release/status -v . $temp_dir/release.xml)"
			[[ $? -ne 0 ]] && echo "xml: parsing error." && return 1
		fi
		release_status=\'$release_status\'

		if xml el $temp_dir/release.xml | grep -q "metadata/release-list/release/title"
		then
			release_name="$(xml sel -t -m //metadata/release-list/release/title -v . $temp_dir/release.xml)"
			[[ $? -ne 0 ]] && echo "xml: parsing error." && return 1
		fi
		escape_chars release_name "$release_name"; release_name=\'$release_name\'

		if xml el -a $temp_dir/release.xml | grep -q "metadata/release-list/release/release-group/@id"
		then
			release_group="$(xml sel -t -m //metadata/release-list/release/release-group/@id -v . $temp_dir/release.xml)"
			[[ $? -ne 0 ]] && echo "xml: parsing error." && return 1
		fi
		process_release_group_mbid $release_group
		[[ $? -ne 0 ]] && echo "Error after calling to process_release_group_mbid()." && return 1
		release_group=\'$release_group\'
		release_group_id=$($mysql_path --skip-reconnect -u$user -p$pass \
			-D$db --skip-column-names -e "

			SELECT id FROM release_group WHERE mbid = $release_group;

		")
		[[ $? -ne 0 ]] && echo "Error after querying the database." && return 1
		release_group_id=\'$release_group_id\'

		if xml el $temp_dir/release.xml | grep -q "metadata/release-list/release/disambiguation"
		then
			comment="$(xml sel -t -m //metadata/release-list/release/disambiguation -v . $temp_dir/release.xml)"
			[[ $? -ne 0 ]] && echo "xml: parsing error." && return 1
		fi
		escape_chars comment "$comment"; comment=\'$comment\'

		# Insert release.
		$mysql_path --skip-reconnect -u$user -p$pass -D$db \
			--skip-column-names -e "

			START TRANSACTION;
			CALL insert_release (
				$mbid,
				$release_status,
				$release_name,
				$release_group_id,
				$comment
			);
			COMMIT;
		"
		if [ $? -ne 0 ]
		then
			error_exit "$LINENO: Error after calling mysql."
		fi
		release_id=$($mysql_path --skip-reconnect -u$user -p$pass \
			-D$db --skip-column-names -e "

			SELECT id FROM \`release\` WHERE mbid = $mbid;

		")
		[[ $? -ne 0 ]] && echo "Error after querying the database." && return 1
		release_id=\'$release_id\'

		# Insert artist-release relationships.
		if xml el -a $temp_dir/release.xml | grep -q "metadata/release-list/release/artist-credit/name-credit/artist/@id"
		then
			artists=( $(xml sel -t -m //metadata/release-list/release/artist-credit/name-credit/artist/@id -n -v . $temp_dir/release.xml) )
			[[ $? -ne 0 ]] && echo "xml: parsing error." && return 1
			for artist in ${artists[@]}
			do
				process_artist_mbid $artist
				[[ $? -ne 0 ]] && echo "Error after calling to process_artist_mbid()." && return 1
				artist=\'$artist\'
				artist_ids+=( $($mysql_path --skip-reconnect -u$user -p$pass \
					-D$db --skip-column-names -e "

					SELECT id FROM artist WHERE mbid = $artist;

				") )
				[[ $? -ne 0 ]] && echo "Error after querying the database." && return 1
			done
			for artist_id in ${artist_ids[@]}
			do
				artist_id=\'$artist_id\'
				$mysql_path --skip-reconnect -u$user -p$pass -D$db \
					--skip-column-names -e "

					START TRANSACTION;
					CALL link_artist_to_release (
						$artist_id,
						'is credited for',
						$release_id
					);
					COMMIT;
				"
				if [ $? -ne 0 ]
				then
					error_exit "$LINENO: Error after calling mysql."
				fi
			done
		fi

		# Insert recording-release relationship.
		limit_mbcon
		wget --wait=5 -q -O - "http://musicbrainz.org/ws/2/release/$1?inc=recordings" > $temp_dir/rel2.xml
		wget_error=$?
		[[ $wget_error -ne 0 ]] && echo "wget: exit status is $wget_error" && return 1
		MUSICBRAINZ_LTIME=$(date +%s)

		xml ed $temp_dir/rel2.xml | sed -e 's/ xmlns.*=".*"//g' | sed -e 's/ext://g' > $temp_dir/release2.xml

		if xml el -a $temp_dir/release2.xml | grep -q "metadata/release/medium-list/medium/track-list/track/recording/@id"
		then
			recordings="$(xml sel -t -m //metadata/release/medium-list/medium/track-list/track/recording/@id -n -v . $temp_dir/release2.xml)"
			[[ $? -ne 0 ]] && echo "xml: parsing error." && return 1
			for recording in ${recordings[@]}
			do
				process_recording_mbid $recording
				[[ $? -ne 0 ]] && echo "Error after calling to process_recording_mbid()." && return 1
				recording=\'$recording\'
				recording_ids+=( $($mysql_path --skip-reconnect -u$user -p$pass \
					-D$db --skip-column-names -e "

					SELECT id FROM recording WHERE mbid = $recording;

				") )
				[[ $? -ne 0 ]] && echo "Error after querying the database." && return 1
			done
			for recording_id in ${recording_ids[@]}
			do
				recording_id=\'$recording_id\'
				$mysql_path --skip-reconnect -u$user -p$pass -D$db \
					--skip-column-names -e "

					START TRANSACTION;
					CALL link_recording_to_release (
						$recording_id,
						$release_id
					);
					COMMIT;
				"
				if [ $? -ne 0 ]
				then
					error_exit "$LINENO: Error after calling mysql."
				fi
			done
		fi

		# Delete temporal directory.
		rm -r $temp_dir
		[[ $? -ne 0 ]] && echo "rm: could not remove temporal directory." && return 1
		cd $old_pwd
		[[ $? -ne 0 ]] && echo "cd: could not change working directory." && return 1
	fi
	return 0
}

process_release_group_mbid () {

#       USAGE: process_release_group_mbid release_group_MBID
#
# DESCRIPTION: Search the database for a release_group with the
#              RELEASE_GROUP_MBID. If no release_group is found, get
#              data from musicbrainz.org and update the database.
#
#   PARAMETER: RELEASE_GROUP_MBID A 36 character string used by musicbrainz.org
#                          as an unique identifier.

	local old_pwd=$(pwd)
	local temp_root="/dev/shm/javiera"
	local temp_dir
	local mbid=\'$1\'
	local queried_mbid
	local -a artists
	local -a artist_ids
	local release_group_id
	local release_name
	local release_group_type
	local comment
	local wget_error
	
	# Is this release_group already in the database?
	queried_mbid=$($mysql_path --skip-reconnect -u$user -p$pass \
		-D$db --skip-column-names -e "

		SELECT mbid FROM release_group WHERE mbid = $mbid;

	")
	[[ $? -ne 0 ]] && echo "Error after querying the database." && return 1

	# If it is not, update it.
	if [ -z $queried_mbid ]
	then
		# Query musicbrainz.
		[[ ! -d $temp_root ]] && mkdir -p $temp_root
		cd $temp_root
		[[ $? -ne 0 ]] && echo "cd: could not change working directory." && return 1
		temp_dir=$(readlink -f $(mktemp -d tmp.XXX))
		limit_mbcon
		wget --wait=5 -q -O - "http://musicbrainz.org/ws/2/release-group?query=rgid:$1" > $temp_dir/rg.xml
		wget_error=$?
		[[ $wget_error -ne 0 ]] && echo "wget: exit status is $wget_error" && return 1
		MUSICBRAINZ_LTIME=$(date +%s)

		xml ed $temp_dir/rg.xml | sed -e 's/ xmlns.*=".*"//g' | sed -e 's/ext://g' > $temp_dir/release_group.xml

		# Parse data.
		if xml el $temp_dir/release_group.xml | grep -q "metadata/release-group-list/release-group/primary-type"
		then
			release_group_type="$(xml sel -t -m //metadata/release-group-list/release-group/primary-type -v . $temp_dir/release_group.xml)"
			[[ $? -ne 0 ]] && echo "xml: parsing error." && return 1
		fi
		release_group_type=\'$release_group_type\'

		if xml el $temp_dir/release_group.xml | grep -q "metadata/release-group-list/release-group/title"
		then
			release_name="$(xml sel -t -m //metadata/release-group-list/release-group/title -v . $temp_dir/release_group.xml)"
			[[ $? -ne 0 ]] && echo "xml: parsing error." && return 1
		fi
		escape_chars release_name "$release_name"; release_name=\'$release_name\'

		if xml el $temp_dir/release_group.xml | grep -q "metadata/release-group-list/release-group/disambiguation"
		then
			comment="$(xml sel -t -m //metadata/release-group-list/release-group/disambiguation -v . $temp_dir/release_group.xml)"
			[[ $? -ne 0 ]] && echo "xml: parsing error." && return 1
		fi
		escape_chars comment "$comment"; comment=\'$comment\'

		# Update the database.
		$mysql_path --skip-reconnect -u$user -p$pass -D$db \
			--skip-column-names -e "

			START TRANSACTION;
			CALL insert_release_group (
				$mbid,
				$release_group_type,
				$release_name,
				$comment
			);
			COMMIT;
		"
		if [ $? -ne 0 ]
		then
			error_exit "$LINENO: Error after calling mysql."
		fi
		release_group_id=$($mysql_path --skip-reconnect -u$user -p$pass \
			-D$db --skip-column-names -e "

			SELECT id FROM release_group WHERE mbid = $mbid;

		")
		[[ $? -ne 0 ]] && echo "Error after querying the database." && return 1
		release_group_id=\'$release_group_id\'

		# Insert artist-release_group relationships.
		if xml el -a $temp_dir/release_group.xml | grep -q "metadata/release-group-list/release-group/artist-credit/name-credit/artist/@id"
		then
			artists=( $(xml sel -t -m //metadata/release-group-list/release-group/artist-credit/name-credit/artist/@id -n -v . $temp_dir/release_group.xml) )
			[[ $? -ne 0 ]] && echo "xml: parsing error." && return 1
			for artist in ${artists[@]}
			do
				process_artist_mbid $artist
				[[ $? -ne 0 ]] && echo "Error after calling to process_artist_mbid()." && return 1
				artist=\'$artist\'
				artist_ids+=( $($mysql_path --skip-reconnect -u$user -p$pass \
					-D$db --skip-column-names -e "

					SELECT id FROM artist WHERE mbid = $artist;

				") )
				[[ $? -ne 0 ]] && echo "Error after querying the database." && return 1
			done
			for artist_id in ${artist_ids[@]}
			do
				artist_id=\'$artist_id\'
				$mysql_path --skip-reconnect -u$user -p$pass -D$db \
					--skip-column-names -e "

					START TRANSACTION;
					CALL link_artist_to_release_group (
						$artist_id,
						'is credited for',
						$release_group_id
					);
					COMMIT;
				"
				if [ $? -ne 0 ]
				then
					error_exit "$LINENO: Error after calling mysql."
				fi
			done
		fi

		# Delete temporal directory.
		rm -r $temp_dir
		[[ $? -ne 0 ]] && echo "rm: could not remove temporal directory." && return 1
		cd $old_pwd
		[[ $? -ne 0 ]] && echo "cd: could not change working directory." && return 1
	fi
	return 0
}
