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
	local recently=$(expr $now - 2)

	while [ $recently -le $MUSICBRAINZ_LTIME ]
	do
		now=$(date +%s)
		recently=$(expr $now - 2)
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
	local art_mbid
	local artmbid
	local art_type
	local art_name
	local art_sort
	local art_comment
	local wget_error
	local xmlns="http://musicbrainz.org/ns/mmd-2.0#"
	
	if echo $1 | grep -q '^[-0123456789abcdef]\{36\}$'
	then
		art_mbid=\'$1\'
	else
		echo "Error: $1 is not a valid mbid."
		return 1
	fi

	# Is this artist already in the database?
	artmbid=$($mysql_path --skip-reconnect -u$user -p$pass \
		-D$db --skip-column-names -e "

		SELECT mbid FROM artist WHERE mbid = $art_mbid;

	")
	[[ $? -ne 0 ]] && echo "Error after querying the database." && return 1

	# If it is not, update it.
	if [ -z $artmbid ]
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
			art_type="$(xml sel -N my=$xmlns -t -m //my:metadata/my:artist/@type -v . $temp_dir/artist.xml)"
			[[ $? -ne 0 ]] && echo "xml: parsing error." && return 1
		fi
		escape_chars art_type "$art_type"
		art_type="${art_type##+([-[[:space:]])}"
		art_type=\'$art_type\'

		if xml el $temp_dir/artist.xml | grep -q "metadata/artist/name"
		then
			art_name="$(xml sel -N my=$xmlns -t -m //my:metadata/my:artist/my:name -v . $temp_dir/artist.xml)"
			[[ $? -ne 0 ]] && echo "xml: parsing error." && return 1
		fi
		escape_chars art_name "$art_name"
		art_name="${art_name##+([-[[:space:]])}"
		art_name=\'$art_name\'

		if xml el $temp_dir/artist.xml | grep -q "metadata/artist/sort-name"
		then
			art_sort="$(xml sel -N my=$xmlns -t -m //my:metadata/my:artist/my:sort-name -v . $temp_dir/artist.xml)"
			[[ $? -ne 0 ]] && echo "xml: parsing error." && return 1
		fi
		escape_chars art_sort "$art_sort"
		art_sort="${art_sort##+([-[[:space:]])}"
		art_sort=\'$art_sort\'

		if xml el $temp_dir/artist.xml | grep -q "metadata/artist/disambiguation"
		then
			art_comment="$(xml sel -N my=$xmlns -t -m //my:metadata/my:artist/my:disambiguation -v . $temp_dir/artist.xml)"
			[[ $? -ne 0 ]] && echo "xml: parsing error." && return 1
		fi
		escape_chars art_comment "$art_comment"
		art_comment="${art_comment##+([-[[:space:]])}"
		art_comment=\'$art_comment\'

		rm -r $temp_dir
		[[ $? -ne 0 ]] && echo "rm: could not remove temporal directory." && return 1
		cd $old_pwd
		[[ $? -ne 0 ]] && echo "cd: could not change working directory." && return 1

		# Update the database.
		$mysql_path --skip-reconnect -u$user -p$pass -D$db \
			--skip-column-names -e "

			START TRANSACTION;
			CALL insert_artist (
				$art_mbid,
				$art_type,
				$art_name,
				$art_sort,
				$art_comment
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
	local rec_mbid
	local recmbid
	local -a rec_arts
	local rec_art
	local -a rec_art_ids
	local rec_art_id
	local rec_id
	local rec_name
	local rec_length
	local rec_comment
	local -a rec_xtypes
	local -a rec_xarts
	local rec_xart
	local rec_xart_id
	local wget_error
	
	if echo $1 | grep -q '^[-0123456789abcdef]\{36\}$'
	then
		rec_mbid=\'$1\'
	else
		echo "Error: $1 is not a valid mbid."
		return 1
	fi

	# Is this recording already in the database?
	recmbid=$($mysql_path --skip-reconnect -u$user -p$pass \
		-D$db --skip-column-names -e "

		SELECT mbid FROM recording WHERE mbid = $rec_mbid;

	")
	[[ $? -ne 0 ]] && echo "Error after querying the database." && return 1

	# If it is not, update it.
	if [ -z $recmbid ]
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

		limit_mbcon
		wget --wait=5 -q -O - "http://musicbrainz.org/ws/2/recording/$1?inc=artist-rels" > $temp_dir/rec2.xml
		wget_error=$?
		[[ $wget_error -ne 0 ]] && echo "wget: exit status is $wget_error" && return 1
		MUSICBRAINZ_LTIME=$(date +%s)

		xml ed $temp_dir/rec2.xml | sed -e 's/ xmlns.*=".*"//g' | sed -e 's/ext://g' > $temp_dir/recording2.xml

		# Parse data.
		if xml el $temp_dir/recording.xml | grep -q "metadata/recording-list/recording/title"
		then
			rec_name="$(xml sel -t -m //metadata/recording-list/recording/title -v . $temp_dir/recording.xml)"
			[[ $? -ne 0 ]] && echo "xml: parsing error." && return 1
		fi
		escape_chars rec_name "$rec_name"
		rec_name="${rec_name##+([-[[:space:]])}"
		rec_name=\'$rec_name\'

		if xml el $temp_dir/recording.xml | grep -q "metadata/recording-list/recording/length"
		then
			rec_length="$(xml sel -t -m //metadata/recording-list/recording/length -v . $temp_dir/recording.xml)"
			[[ $? -ne 0 ]] && echo "xml: parsing error." && return 1
		fi
		escape_chars rec_length "$rec_length"
		rec_length="${rec_length##+([-[[:space:]])}"
		rec_length=\'$rec_length\'

		if xml el $temp_dir/recording.xml | grep -q "metadata/recording-list/recording/disambiguation"
		then
			rec_comment="$(xml sel -t -m //metadata/recording-list/recording/disambiguation -v . $temp_dir/recording.xml)"
			[[ $? -ne 0 ]] && echo "xml: parsing error." && return 1
		fi
		escape_chars rec_comment "$rec_comment"
		rec_comment="${rec_comment##+([-[[:space:]])}"
		rec_comment=\'$rec_comment\'

		# Insert recording.
		$mysql_path --skip-reconnect -u$user -p$pass -D$db \
			--skip-column-names -e "

			START TRANSACTION;
			CALL insert_recording (
				$rec_mbid,
				$rec_name,
				$rec_length,
				$rec_comment
			);
			COMMIT;
		"
		if [ $? -ne 0 ]
		then
			error_exit "$LINENO: Error after calling mysql."
		fi
		rec_id=$($mysql_path --skip-reconnect -u$user -p$pass \
			-D$db --skip-column-names -e "

			SELECT id FROM recording WHERE mbid = $rec_mbid;

		")
		[[ $? -ne 0 ]] && echo "Error after querying the database." && return 1
		rec_id=\'$rec_id\'

		# Insert artist (credited for) recording relationship.
		if xml el -a $temp_dir/recording.xml | grep -q "metadata/recording-list/recording/artist-credit/name-credit/artist/@id"
		then
			rec_arts=( $(xml sel -t -m //metadata/recording-list/recording/artist-credit/name-credit/artist/@id -n -v . $temp_dir/recording.xml) )
			[[ $? -ne 0 ]] && echo "xml: parsing error." && return 1
			for rec_art in ${rec_arts[@]}
			do
				process_artist_mbid $rec_art
				[[ $? -ne 0 ]] && echo "Error after calling to process_artist_mbid()." && return 1
				rec_art=\'$rec_art\'
				rec_art_ids+=( $($mysql_path --skip-reconnect -u$user -p$pass \
					-D$db --skip-column-names -e "

					SELECT id FROM artist WHERE mbid = $rec_art;

				") )
				[[ $? -ne 0 ]] && echo "Error after querying the database." && return 1
			done
			for rec_art_id in ${rec_art_ids[@]}
			do
				rec_art_id=\'$rec_art_id\'
				$mysql_path --skip-reconnect -u$user -p$pass -D$db \
					--skip-column-names -e "

					START TRANSACTION;
					CALL link_artist_to_recording (
						$rec_art_id,
						'is credited for',
						$rec_id
					);
					COMMIT;
				"
				if [ $? -ne 0 ]
				then
					error_exit "$LINENO: Error after calling mysql."
				fi
			done
		fi

		# Insert extended artist-recording relationships.

		if xml el -a $temp_dir/recording2.xml | grep -q "metadata/recording/relation-list/relation/@type"
		then
			while read line
			do
				! [[ -z $line ]] && rec_xtypes+=( "$line" )
			done < <(xml sel -t -m //metadata/recording/relation-list/relation -n -v ./@type $temp_dir/recording2.xml)
			[[ $? -ne 0 ]] && echo "xml: parsing error." && return 1
		fi
		if xml el -a $temp_dir/recording2.xml | grep -q "metadata/recording/relation-list/relation/artist/@id"
		then
			while read line
			do
				! [[ -z $line ]] && rec_xarts+=( "$line" )
			done < <(xml sel -t -m //metadata/recording/relation-list/relation -n -v ./artist/@id $temp_dir/recording2.xml)
			[[ $? -ne 0 ]] && echo "xml: parsing error." && return 1
		fi
		if [[ ${#rec_xtypes[@]} -eq ${#rec_xarts[@]} ]]
		then
			for (( j=0; j < ${#rec_xarts[@]}; j++ ))
			do
				rec_xart=${rec_xarts[j]}
				process_artist_mbid $rec_xart
				[[ $? -ne 0 ]] && echo "Error after calling to process_artist_mbid()." && return 1

				rec_xart=\'$rec_xart\'
				rec_xart_id=$($mysql_path --skip-reconnect -u$user -p$pass \
					-D$db --skip-column-names -e "

					SELECT id FROM artist WHERE mbid = $rec_xart;")

				[[ $? -ne 0 ]] && echo "Error after querying the database." && return 1

				rel_type=${rec_xtypes[j]}; escape_chars rel_type "$rel_type"
				rel_type=\'$rel_type\'
				rec_xart_id=\'$rec_xart_id\'
				$mysql_path --skip-reconnect -u$user -p$pass -D$db \
					--skip-column-names -e "

					START TRANSACTION;
					CALL link_artist_to_recording (
						$rec_xart_id,
						$rel_type,
						$rec_id
					);
					COMMIT;
				"
				if [ $? -ne 0 ]
				then
					error_exit "$LINENO: Error after calling mysql."
				fi
			done
			unset -v j
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
	local rel_mbid=\'$1\'
	local relmbid
	local -a rel_arts
	local rel_art
	local -a rel_art_ids
	local rel_art_id
	local -a rel_recs
	local rel_rec
	local rel_id
	local rel_name
	local rel_status
	local rel_rgroup
	local rel_rgroup_id
	local rel_comment
	local -i rel_med_count
	local rel_med_format
	local rel_med_pos
	local wget_error
	
	if echo $1 | grep -q '^[-0123456789abcdef]\{36\}$'
	then
		rel_mbid=\'$1\'
	else
		echo "Error: $1 is not a valid mbid."
		return 1
	fi

	# Is this release already in the database?
	relmbid=$($mysql_path --skip-reconnect -u$user -p$pass \
		-D$db --skip-column-names -e "

		SELECT mbid FROM \`release\` WHERE mbid = $rel_mbid;

	")
	[[ $? -ne 0 ]] && echo "Error after querying the database." && return 1

	# If it is not, insert it.
	if [ -z $relmbid ]
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

		limit_mbcon
		wget --wait=5 -q -O - "http://musicbrainz.org/ws/2/release/$1?inc=recordings+media" > $temp_dir/rel2.xml
		wget_error=$?
		[[ $wget_error -ne 0 ]] && echo "wget: exit status is $wget_error" && return 1
		MUSICBRAINZ_LTIME=$(date +%s)

		xml ed $temp_dir/rel2.xml | sed -e 's/ xmlns.*=".*"//g' | sed -e 's/ext://g' > $temp_dir/release2.xml

		# Parse data.
		if xml el $temp_dir/release.xml | grep -q "metadata/release-list/release/status"
		then
			rel_status="$(xml sel -t -m //metadata/release-list/release/status -v . $temp_dir/release.xml)"
			[[ $? -ne 0 ]] && echo "xml: parsing error." && return 1
		fi
		escape_chars rel_status "$rel_status"
		rel_status="${rel_status##+([-[[:space:]])}"
		rel_status=\'$rel_status\'

		if xml el $temp_dir/release.xml | grep -q "metadata/release-list/release/title"
		then
			rel_name="$(xml sel -t -m //metadata/release-list/release/title -v . $temp_dir/release.xml)"
			[[ $? -ne 0 ]] && echo "xml: parsing error." && return 1
		fi
		escape_chars rel_name "$rel_name"; rel_name=\'$rel_name\'

		if xml el -a $temp_dir/release.xml | grep -q "metadata/release-list/release/release-group/@id"
		then
			rel_rgroup="$(xml sel -t -m //metadata/release-list/release/release-group/@id -v . $temp_dir/release.xml)"
			[[ $? -ne 0 ]] && echo "xml: parsing error." && return 1
		fi
		process_release_group_mbid $rel_rgroup
		[[ $? -ne 0 ]] && echo "Error after calling to process_release_group_mbid()." && return 1
		rel_rgroup=\'$rel_rgroup\'
		rel_rgroup_id=$($mysql_path --skip-reconnect -u$user -p$pass \
			-D$db --skip-column-names -e "

			SELECT id FROM release_group WHERE mbid = $rel_rgroup;

		")
		[[ $? -ne 0 ]] && echo "Error after querying the database." && return 1
		rel_rgroup_id=\'$rel_rgroup_id\'

		if xml el $temp_dir/release.xml | grep -q "metadata/release-list/release/disambiguation"
		then
			rel_comment="$(xml sel -t -m //metadata/release-list/release/disambiguation -v . $temp_dir/release.xml)"
			[[ $? -ne 0 ]] && echo "xml: parsing error." && return 1
		fi
		escape_chars rel_comment "$rel_comment"
		rel_comment="${rel_comment##+([-[[:space:]])}"
		rel_comment=\'$rel_comment\'

		# Insert release.
		$mysql_path --skip-reconnect -u$user -p$pass -D$db \
			--skip-column-names -e "

			START TRANSACTION;
			CALL insert_release (
				$rel_mbid,
				$rel_status,
				$rel_name,
				$rel_rgroup_id,
				$rel_comment
			);
			COMMIT;
		"
		if [ $? -ne 0 ]
		then
			error_exit "$LINENO: Error after calling mysql."
		fi
		rel_id=$($mysql_path --skip-reconnect -u$user -p$pass \
			-D$db --skip-column-names -e "

			SELECT id FROM \`release\` WHERE mbid = $rel_mbid;

		")
		[[ $? -ne 0 ]] && echo "Error after querying the database." && return 1
		rel_id=\'$rel_id\'

		# Insert artist-release relationships.
		if xml el -a $temp_dir/release.xml | grep -q "metadata/release-list/release/artist-credit/name-credit/artist/@id"
		then
			rel_arts=( $(xml sel -t -m //metadata/release-list/release/artist-credit/name-credit/artist/@id -n -v . $temp_dir/release.xml) )
			[[ $? -ne 0 ]] && echo "xml: parsing error." && return 1
			for rel_art in ${rel_arts[@]}
			do
				process_artist_mbid $rel_art
				[[ $? -ne 0 ]] && echo "Error after calling to process_artist_mbid()." && return 1
				rel_art=\'$rel_art\'
				rel_art_ids+=( $($mysql_path --skip-reconnect -u$user -p$pass \
					-D$db --skip-column-names -e "

					SELECT id FROM artist WHERE mbid = $rel_art;

				") )
				[[ $? -ne 0 ]] && echo "Error after querying the database." && return 1
			done
			for rel_art_id in ${rel_art_ids[@]}
			do
				rel_art_id=\'$rel_art_id\'
				$mysql_path --skip-reconnect -u$user -p$pass -D$db \
					--skip-column-names -e "

					START TRANSACTION;
					CALL link_artist_to_release (
						$rel_art_id,
						'is credited for',
						$rel_id
					);
					COMMIT;
				"
				if [ $? -ne 0 ]
				then
					error_exit "$LINENO: Error after calling mysql."
				fi
			done
		fi

		### Insert release's tracks into the database.
		rel_med_count="$(xml sel -t -m //metadata/release/medium-list/@count -n -v . $temp_dir/release2.xml)"
		for (( i=1; i <= $rel_med_count; i++ ))
		do
			rel_med_format="$(xml sel -t -m //metadata/release/medium-list/medium -i "./position=$i" -n -v ./format $temp_dir/release2.xml)"
			escape_chars rel_med_format "$rel_med_format";
			rel_med_format="${rel_med_format##+([-[[:space:]])}"
			rel_med_format=\'$rel_med_format\'
			rel_med_pos=\'$i\'

			rel_med_id=$($mysql_path --skip-reconnect -u$user -p$pass -D$db \
				--skip-column-names -e "

				START TRANSACTION;
				CALL insert_and_get_medium (
					$rel_id,
					$rel_med_format,
					$rel_med_pos,
					@rel_med_id
				);
				SELECT @rel_med_id;
				COMMIT;
			")
			if [ $? -ne 0 ]
			then
				error_exit "$LINENO: Error after calling mysql."
			fi

			rel_med_id=\'$rel_med_id\'

			rel_med_format=
			rel_med_pos=

			if xml el -a $temp_dir/release2.xml | grep -q "metadata/release/medium-list/medium/track-list/track/recording/@id"
			then
				rel_recs=( $(xml sel -t -m //metadata/release/medium-list/medium -i "./position=$i" -n -v ./track-list/track/recording/@id $temp_dir/release2.xml) )
				[[ $? -ne 0 ]] && echo "xml: parsing error." && return 1
				for rel_rec in ${rel_recs[@]}
				do
					process_recording_mbid $rel_rec
					[[ $? -ne 0 ]] && echo "Error after calling to process_recording_mbid()." && return 1

					rel_rec=\'$rel_rec\'
					$mysql_path --skip-reconnect -u$user -p$pass \
						-D$db --skip-column-names -e "

						START TRANSACTION;
						SELECT id into @recording_id FROM recording WHERE mbid = $rel_rec;
						INSERT INTO
						l_recording_to_medium (recording_id, medium_id) VALUES (
							@recording_id,
							$rel_med_id
						);
						COMMIT;

					"
					[[ $? -ne 0 ]] && echo "Error after querying the database." && return 1
				done
			fi
		done
		unset -v i

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
	local rgr_mbid=\'$1\'
	local rgrmbid
	local -a rgr_arts
	local rgr_art
	local -a rgr_art_ids
	local rgr_art_id
	local rgr_id
	local rgr_name
	local rgr_type
	local rgr_comment
	local wget_error
	
	if echo $1 | grep -q '^[-0123456789abcdef]\{36\}$'
	then
		rgr_mbid=\'$1\'
	else
		echo "Error: $1 is not a valid mbid."
		return 1
	fi

	# Is this release_group already in the database?
	rgrmbid=$($mysql_path --skip-reconnect -u$user -p$pass \
		-D$db --skip-column-names -e "

		SELECT mbid FROM release_group WHERE mbid = $rgr_mbid;

	")
	[[ $? -ne 0 ]] && echo "Error after querying the database." && return 1

	# If it is not, update it.
	if [ -z $rgrmbid ]
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
			rgr_type="$(xml sel -t -m //metadata/release-group-list/release-group/primary-type -v . $temp_dir/release_group.xml)"
			[[ $? -ne 0 ]] && echo "xml: parsing error." && return 1
		fi
		escape_chars rgr_type "$rgr_type"
		rgr_type="${rgr_type##+([-[[:space:]])}"
		rgr_type=\'$rgr_type\'

		if xml el $temp_dir/release_group.xml | grep -q "metadata/release-group-list/release-group/title"
		then
			rgr_name="$(xml sel -t -m //metadata/release-group-list/release-group/title -v . $temp_dir/release_group.xml)"
			[[ $? -ne 0 ]] && echo "xml: parsing error." && return 1
		fi
		escape_chars rgr_name "$rgr_name"; rgr_name=\'$rgr_name\'

		if xml el $temp_dir/release_group.xml | grep -q "metadata/release-group-list/release-group/disambiguation"
		then
			rgr_comment="$(xml sel -t -m //metadata/release-group-list/release-group/disambiguation -v . $temp_dir/release_group.xml)"
			[[ $? -ne 0 ]] && echo "xml: parsing error." && return 1
		fi
		escape_chars rgr_comment "$rgr_comment"
		rgr_comment="${rgr_comment##+([-[[:space:]])}"
		rgr_comment=\'$rgr_comment\'

		# Update the database.
		$mysql_path --skip-reconnect -u$user -p$pass -D$db \
			--skip-column-names -e "

			START TRANSACTION;
			CALL insert_release_group (
				$rgr_mbid,
				$rgr_type,
				$rgr_name,
				$rgr_comment
			);
			COMMIT;
		"
		if [ $? -ne 0 ]
		then
			error_exit "$LINENO: Error after calling mysql."
		fi
		rgr_id=$($mysql_path --skip-reconnect -u$user -p$pass \
			-D$db --skip-column-names -e "

			SELECT id FROM release_group WHERE mbid = $rgr_mbid;

		")
		[[ $? -ne 0 ]] && echo "Error after querying the database." && return 1
		rgr_id=\'$rgr_id\'

		# Insert artist-release_group relationships.
		if xml el -a $temp_dir/release_group.xml | grep -q "metadata/release-group-list/release-group/artist-credit/name-credit/artist/@id"
		then
			rgr_arts=( $(xml sel -t -m //metadata/release-group-list/release-group/artist-credit/name-credit/artist/@id -n -v . $temp_dir/release_group.xml) )
			[[ $? -ne 0 ]] && echo "xml: parsing error." && return 1
			for rgr_art in ${rgr_arts[@]}
			do
				process_artist_mbid $rgr_art
				[[ $? -ne 0 ]] && echo "Error after calling to process_artist_mbid()." && return 1
				rgr_art=\'$rgr_art\'
				rgr_art_ids+=( $($mysql_path --skip-reconnect -u$user -p$pass \
					-D$db --skip-column-names -e "

					SELECT id FROM artist WHERE mbid = $rgr_art;

				") )
				[[ $? -ne 0 ]] && echo "Error after querying the database." && return 1
			done
			for rgr_art_id in ${rgr_art_ids[@]}
			do
				rgr_art_id=\'$rgr_art_id\'
				$mysql_path --skip-reconnect -u$user -p$pass -D$db \
					--skip-column-names -e "

					START TRANSACTION;
					CALL link_artist_to_release_group (
						$rgr_art_id,
						'is credited for',
						$rgr_id
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
