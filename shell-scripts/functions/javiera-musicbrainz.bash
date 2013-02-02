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
# REQUIREMENTS: wget, xmlstarlet
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

#       USAGE: process_artist_mbid ARTIST_MBID QUERY_FILE
#
# DESCRIPTION: Search the `artist` table for the ARTIST_MBID value. If
#              no record is found, get pertinent data to this value from
#              musicbrainz.org and build a query in order to update the
#              database whith this data. Append the query to the file
#              pointed by QUERY_FILE.
#
#   PARAMETER: ARTIST_MBID:  A 36 character string used by
#                            musicbrainz.org as an unique identifier.
#              QUERY_FILE:   The pathname of the file in which append
#                            the sql query.

	local art_oldpwd=$(pwd)
	local art_tmpdir
	local art_mbid
	local art_id
	local art_type
	local art_name
	local art_sort
	local art_comment
	local art_wgeterr
	local art_xmlns="http://musicbrainz.org/ns/mmd-2.0#"
	
	# Check for well-formatted arguments.
	if echo $1 | grep -q '^[-0123456789abcdef]\{36\}$'
	then
		art_mbid=\'$1\'
	else
		echo "Error: $1 is not a valid mbid."
		return 1
	fi

	# Change directory to the temporal root directory of the script.
	cd $tmp_root
	[[ $? -ne 0 ]] && echo "cd: could not change working directory." && return 1

	# Create a temporal directory for use of this function.
	art_tmpdir="$(mktemp -d art.XXX)"
	[[ $? -ne 0 ]] && echo "mktemp: could not create a temporal directory." && return 1
	art_tmpdir="$(readlink -f $art_tmpdir)"
	[[ $? -ne 0 ]] && echo "readlink: could not read the temporal directory pathname." && return 1

	# Is this artist already in the database?
	art_id=$($mysql_path --skip-reconnect -u$user -p$pass \
		-D$db --skip-column-names -e "

		SELECT id FROM artist WHERE mbid = $art_mbid;

	")
	[[ $? -ne 0 ]] && echo "Error after querying the database." && return 1

	printf "SET @art_id = %b;\n" \'$art_id\' >> $2

	# If it is not, update it.
	if [ -z $art_id ]
	then
		# Query musicbrainz.
		limit_mbcon
		wget --wait=5 -q -O - "http://musicbrainz.org/ws/2/artist/$1" > $art_tmpdir/artist.xml
		art_wgeterr=$?
		[[ $art_wgeterr -ne 0 ]] && echo "wget: exit status is $art_wgeterr" && return 1

		MUSICBRAINZ_LTIME=$(date +%s)

		# Parse data.
		if xml el -a $art_tmpdir/artist.xml | grep -q "metadata/artist/@type"
		then
			art_type="$(xml sel -N my=$art_xmlns -t -m //my:metadata/my:artist/@type -v . $art_tmpdir/artist.xml)"
			[[ $? -ne 0 ]] && echo "xml: parsing error." && return 1
		fi
		escape_chars art_type "$art_type"
		art_type="${art_type##+([-[[:space:]])}"
		art_type=\'$art_type\'

		if xml el $art_tmpdir/artist.xml | grep -q "metadata/artist/name"
		then
			art_name="$(xml sel -N my=$art_xmlns -t -m //my:metadata/my:artist/my:name -v . $art_tmpdir/artist.xml)"
			[[ $? -ne 0 ]] && echo "xml: parsing error." && return 1
		fi
		escape_chars art_name "$art_name"
		art_name="${art_name##+([-[[:space:]])}"
		art_name=\'$art_name\'

		if xml el $art_tmpdir/artist.xml | grep -q "metadata/artist/sort-name"
		then
			art_sort="$(xml sel -N my=$art_xmlns -t -m //my:metadata/my:artist/my:sort-name -v . $art_tmpdir/artist.xml)"
			[[ $? -ne 0 ]] && echo "xml: parsing error." && return 1
		fi
		escape_chars art_sort "$art_sort"
		art_sort="${art_sort##+([-[[:space:]])}"
		art_sort=\'$art_sort\'

		if xml el $art_tmpdir/artist.xml | grep -q "metadata/artist/disambiguation"
		then
			art_comment="$(xml sel -N my=$art_xmlns -t -m //my:metadata/my:artist/my:disambiguation -v . $art_tmpdir/artist.xml)"
			[[ $? -ne 0 ]] && echo "xml: parsing error." && return 1
		fi
		escape_chars art_comment "$art_comment"
		art_comment="${art_comment##+([-[[:space:]])}"
		art_comment=\'$art_comment\'

		# Update the database.
		printf "CALL insert_and_get_artist (
				%b,
				%b,
				%b,
				%b,
				%b,
				@art_id
			);\n" $art_mbid "$art_type" "$art_name" "$art_sort" "$art_comment" >> $2
	fi

	# Delete the temporal directory.
	rm -r $art_tmpdir
	[[ $? -ne 0 ]] && echo "rm: could not remove temporal directory." && return 1
	cd $art_oldpwd
	[[ $? -ne 0 ]] && echo "cd: could not change working directory." && return 1

	return 0
}

process_recording_mbid () {

#       USAGE: process_recording_mbid RECORDING_MBID QUERY_FILE
#
# DESCRIPTION: Search the `recording` table for the RECORDING_MBID
#              value. If no record is found, get pertinent data to this
#              value from musicbrainz.org and build a query in order to
#              update the database whith this data. Append the query to
#              the file pointed by QUERY_FILE.
#
#   PARAMETER: RECORDING_MBID: A 36 character string used by
#                              musicbrainz.org as an unique identifier.
#              QUERY_FILE:     The pathname of the file in which append
#                              the sql query.

	local rec_oldpwd=$(pwd)
	local rec_tmpdir
	local rec_mbid
	local rec_id
	local -a rec_arts
	local rec_art
	local rec_name
	local rec_length
	local rec_comment
	local -a rec_xtypes
	local -a rec_xarts
	local rec_xart
	local rec_wgeterr
	
	# Check for well-formatted arguments.
	if echo $1 | grep -q '^[-0123456789abcdef]\{36\}$'
	then
		rec_mbid=\'$1\'
	else
		echo "Error: $1 is not a valid mbid."
		return 1
	fi

	# Change directory to the temporal root directory of the script.
	cd $tmp_root
	[[ $? -ne 0 ]] && echo "cd: could not change working directory." && return 1

	# Create a temporal directory for use of this function.
	rec_tmpdir="$(mktemp -d rec.XXX)"
	[[ $? -ne 0 ]] && echo "mktemp: could not create a temporal directory." && return 1
	rec_tmpdir="$(readlink -f $rec_tmpdir)"
	[[ $? -ne 0 ]] && echo "readlink: could not read the temporal directory pathname." && return 1

	# Is this recording already in the database?
	rec_id=$($mysql_path --skip-reconnect -u$user -p$pass \
		-D$db --skip-column-names -e "

		SELECT id FROM recording WHERE mbid = $rec_mbid;

	")
	[[ $? -ne 0 ]] && echo "Error after querying the database." && return 1

	printf "SET @art_id = %b;\n" \'$rec_id\' >> $2

	# If it is not, update it.
	if [ -z $rec_id ]
	then
		# Query musicbrainz.
		limit_mbcon
		wget --wait=5 -q -O - "http://musicbrainz.org/ws/2/recording?query=rid:$1" > $rec_tmpdir/rec.xml
		rec_wgeterr=$?
		[[ $rec_wgeterr -ne 0 ]] && echo "wget: exit status is $rec_wgeterr" && return 1
		MUSICBRAINZ_LTIME=$(date +%s)

		xml ed $rec_tmpdir/rec.xml | sed -e 's/ xmlns.*=".*"//g' | sed -e 's/ext://g' > $rec_tmpdir/recording.xml

		limit_mbcon
		wget --wait=5 -q -O - "http://musicbrainz.org/ws/2/recording/$1?inc=artist-rels" > $rec_tmpdir/rec2.xml
		rec_wgeterr=$?
		[[ $rec_wgeterr -ne 0 ]] && echo "wget: exit status is $rec_wgeterr" && return 1
		MUSICBRAINZ_LTIME=$(date +%s)

		xml ed $rec_tmpdir/rec2.xml | sed -e 's/ xmlns.*=".*"//g' | sed -e 's/ext://g' > $rec_tmpdir/recording2.xml

		# Parse data.
		if xml el $rec_tmpdir/recording.xml | grep -q "metadata/recording-list/recording/title"
		then
			rec_name="$(xml sel -t -m //metadata/recording-list/recording/title -v . $rec_tmpdir/recording.xml)"
			[[ $? -ne 0 ]] && echo "xml: parsing error." && return 1
		fi
		escape_chars rec_name "$rec_name"
		rec_name="${rec_name##+([-[[:space:]])}"
		rec_name=\'$rec_name\'

		if xml el $rec_tmpdir/recording.xml | grep -q "metadata/recording-list/recording/length"
		then
			rec_length="$(xml sel -t -m //metadata/recording-list/recording/length -v . $rec_tmpdir/recording.xml)"
			[[ $? -ne 0 ]] && echo "xml: parsing error." && return 1
		fi
		escape_chars rec_length "$rec_length"
		rec_length="${rec_length##+([-[[:space:]])}"
		rec_length=\'$rec_length\'

		if xml el $rec_tmpdir/recording.xml | grep -q "metadata/recording-list/recording/disambiguation"
		then
			rec_comment="$(xml sel -t -m //metadata/recording-list/recording/disambiguation -v . $rec_tmpdir/recording.xml)"
			[[ $? -ne 0 ]] && echo "xml: parsing error." && return 1
		fi
		escape_chars rec_comment "$rec_comment"
		rec_comment="${rec_comment##+([-[[:space:]])}"
		rec_comment=\'$rec_comment\'

		# Insert recording.
		printf "CALL insert_and_get_recording (
				%b,
				%b,
				%b,
				%b,
				@rec_id
			);\n" $rec_mbid "$rec_name" "$rec_length" "$rec_comment" >> $2

		# Insert artist (credited for) recording relationship.
		if xml el -a $rec_tmpdir/recording.xml | grep -q "metadata/recording-list/recording/artist-credit/name-credit/artist/@id"
		then
			rec_arts=( $(xml sel -t -m //metadata/recording-list/recording/artist-credit/name-credit/artist/@id -n -v . $rec_tmpdir/recording.xml) )
			[[ $? -ne 0 ]] && echo "xml: parsing error." && return 1
			for rec_art in ${rec_arts[@]}
			do
				process_artist_mbid $rec_art $2
				[[ $? -ne 0 ]] && echo "Error after calling to process_artist_mbid()." && return 1

				printf "CALL link_artist_to_recording (
						@art_id,
						'is credited for',
						@rec_id 
					);
					SET @art_id = NULL;\n" >> $2
			done
		fi

		# Insert extended artist-recording relationships.

		if xml el -a $rec_tmpdir/recording2.xml | grep -q "metadata/recording/relation-list/relation/@type"
		then
			while read line
			do
				! [[ -z $line ]] && rec_xtypes+=( "$line" )
			done < <(xml sel -t -m //metadata/recording/relation-list/relation -n -v ./@type $rec_tmpdir/recording2.xml)
			[[ $? -ne 0 ]] && echo "xml: parsing error." && return 1
		fi
		if xml el -a $rec_tmpdir/recording2.xml | grep -q "metadata/recording/relation-list/relation/artist/@id"
		then
			while read line
			do
				! [[ -z $line ]] && rec_xarts+=( "$line" )
			done < <(xml sel -t -m //metadata/recording/relation-list/relation -n -v ./artist/@id $rec_tmpdir/recording2.xml)
			[[ $? -ne 0 ]] && echo "xml: parsing error." && return 1
		fi
		if [[ ${#rec_xtypes[@]} -eq ${#rec_xarts[@]} ]]
		then
			for (( j=0; j < ${#rec_xarts[@]}; j++ ))
			do
				rec_xart=${rec_xarts[j]}
				process_artist_mbid $rec_xart $2
				[[ $? -ne 0 ]] && echo "Error after calling to process_artist_mbid()." && return 1
				
				rel_type=${rec_xtypes[j]}; escape_chars rel_type "$rel_type"
				rel_type=\'$rel_type\'

				printf "CALL link_artist_to_recording (
						@art_id,
						%b,
						@rec_id 
					);
					SET @art_id = NULL;\n" "$rel_type" >> $2
			done
			unset -v j
		fi
	fi

	# Delete the temporal directory.
	rm -r $rec_tmpdir
	[[ $? -ne 0 ]] && echo "rm: could not remove temporal directory." && return 1
	cd $rec_oldpwd
	[[ $? -ne 0 ]] && echo "cd: could not change working directory." && return 1

	return 0
}

process_release_mbid () {

#       USAGE: process_release_mbid RELEASE_MBID QUERY_FILE
#
# DESCRIPTION: Search the `release` table for the RELEASE_MBID value. If
#              no record is found, get pertinent data to this value from
#              musicbrainz.org and build a query in order to update the
#              database whith this data. Append the query to the file
#              pointed by QUERY_FILE.
#
#   PARAMETER: RELEASE_MBID: A 36 character string used by
#                            musicbrainz.org as an unique identifier.
#              QUERY_FILE:   The pathname of the file in which append
#                            the sql query.

	local rel_oldpwd=$(pwd)
	local rel_tmpdir
	local rel_mbid
	local rel_id
	local -a rel_arts
	local rel_art
	local -a rel_recs
	local rel_rec
	local rel_name
	local rel_status
	local rel_rgroup
	local rel_comment
	local -i rel_med_count
	local rel_med_format
	local rel_med_pos
	local rel_wgeterr
	
	# Check for well-formatted arguments.
	if echo $1 | grep -q '^[-0123456789abcdef]\{36\}$'
	then
		rel_mbid=\'$1\'
	else
		echo "Error: $1 is not a valid mbid."
		return 1
	fi

	# Change directory to the temporal root directory of the script.
	cd $tmp_root
	[[ $? -ne 0 ]] && echo "cd: could not change working directory." && return 1

	# Create a temporal directory for use of this function.
	rel_tmpdir="$(mktemp -d rel.XXX)"
	[[ $? -ne 0 ]] && echo "mktemp: could not create a temporal directory." && return 1
	rel_tmpdir="$(readlink -f $rel_tmpdir)"
	[[ $? -ne 0 ]] && echo "readlink: could not read the temporal directory pathname." && return 1

	# Is this release already in the database?
	rel_id=$($mysql_path --skip-reconnect -u$user -p$pass \
		-D$db --skip-column-names -e "

		SELECT id FROM \`release\` WHERE mbid = $rel_mbid;

	")
	[[ $? -ne 0 ]] && echo "Error after querying the database." && return 1

	printf "SET @rel_id = %b;\n" \'$rel_id\' >> $2

	# If it is not, insert it.
	if [ -z $rel_id ]
	then
		# Query musicbrainz.
		limit_mbcon
		wget --wait=5 -q -O - "http://musicbrainz.org/ws/2/release?query=reid:$1" > $rel_tmpdir/rel.xml
		rel_wgeterr=$?
		[[ $rel_wgeterr -ne 0 ]] && echo "wget: exit status is $rel_wgeterr" && return 1
		MUSICBRAINZ_LTIME=$(date +%s)

		xml ed $rel_tmpdir/rel.xml | sed -e 's/ xmlns.*=".*"//g' | sed -e 's/ext://g' > $rel_tmpdir/release.xml

		limit_mbcon
		wget --wait=5 -q -O - "http://musicbrainz.org/ws/2/release/$1?inc=recordings+media" > $rel_tmpdir/rel2.xml
		rel_wgeterr=$?
		[[ $rel_wgeterr -ne 0 ]] && echo "wget: exit status is $rel_wgeterr" && return 1
		MUSICBRAINZ_LTIME=$(date +%s)

		xml ed $rel_tmpdir/rel2.xml | sed -e 's/ xmlns.*=".*"//g' | sed -e 's/ext://g' > $rel_tmpdir/release2.xml

		# Parse data.
		if xml el $rel_tmpdir/release.xml | grep -q "metadata/release-list/release/status"
		then
			rel_status="$(xml sel -t -m //metadata/release-list/release/status -v . $rel_tmpdir/release.xml)"
			[[ $? -ne 0 ]] && echo "xml: parsing error." && return 1
		fi
		escape_chars rel_status "$rel_status"
		rel_status="${rel_status##+([-[[:space:]])}"
		rel_status=\'$rel_status\'

		if xml el $rel_tmpdir/release.xml | grep -q "metadata/release-list/release/title"
		then
			rel_name="$(xml sel -t -m //metadata/release-list/release/title -v . $rel_tmpdir/release.xml)"
			[[ $? -ne 0 ]] && echo "xml: parsing error." && return 1
		fi
		escape_chars rel_name "$rel_name"; rel_name=\'$rel_name\'

		if xml el -a $rel_tmpdir/release.xml | grep -q "metadata/release-list/release/release-group/@id"
		then
			rel_rgroup="$(xml sel -t -m //metadata/release-list/release/release-group/@id -v . $rel_tmpdir/release.xml)"
			[[ $? -ne 0 ]] && echo "xml: parsing error." && return 1
		fi
		process_release_group_mbid $rel_rgroup $2
		[[ $? -ne 0 ]] && echo "Error after calling to process_release_group_mbid()." && return 1

		if xml el $rel_tmpdir/release.xml | grep -q "metadata/release-list/release/disambiguation"
		then
			rel_comment="$(xml sel -t -m //metadata/release-list/release/disambiguation -v . $rel_tmpdir/release.xml)"
			[[ $? -ne 0 ]] && echo "xml: parsing error." && return 1
		fi
		escape_chars rel_comment "$rel_comment"
		rel_comment="${rel_comment##+([-[[:space:]])}"
		rel_comment=\'$rel_comment\'

		# Insert release.
		printf "CALL insert_and_get_release (
				%b,
				%b,
				%b,
				@rgroup_id,
				%b,
				@rel_id
			);\n" $rel_mbid "$rel_status" "$rel_name" "$rel_comment" >> $2

		# Insert artist-release relationships.
		if xml el -a $rel_tmpdir/release.xml | grep -q "metadata/release-list/release/artist-credit/name-credit/artist/@id"
		then
			rel_arts=( $(xml sel -t -m //metadata/release-list/release/artist-credit/name-credit/artist/@id -n -v . $rel_tmpdir/release.xml) )
			[[ $? -ne 0 ]] && echo "xml: parsing error." && return 1
			for rel_art in ${rel_arts[@]}
			do
				process_artist_mbid $rel_art $2
				[[ $? -ne 0 ]] && echo "Error after calling to process_artist_mbid()." && return 1

				printf "CALL link_artist_to_release (
						@art_id,
						'is credited for',
						@rel_id 
					);
					SET @art_id = NULL;\n" >> $2
			done
		fi

		### Insert release's tracks into the database.
		rel_med_count="$(xml sel -t -m //metadata/release/medium-list/@count -n -v . $rel_tmpdir/release2.xml)"
		for (( i=1; i <= $rel_med_count; i++ ))
		do
			rel_med_format="$(xml sel -t -m //metadata/release/medium-list/medium -i "./position=$i" -n -v ./format $rel_tmpdir/release2.xml)"
			escape_chars rel_med_format "$rel_med_format";
			rel_med_format="${rel_med_format##+([-[[:space:]])}"
			rel_med_format=\'$rel_med_format\'
			rel_med_pos=\'$i\'

			printf "CALL insert_and_get_medium (
					@rel_id,
					%b,
					%b,
					@med_id
				);\n" "$rel_med_format" "$rel_med_pos" >> $2

			rel_med_format=
			rel_med_pos=

			if xml el -a $rel_tmpdir/release2.xml | grep -q "metadata/release/medium-list/medium/track-list/track/recording/@id"
			then
				rel_recs=( $(xml sel -t -m //metadata/release/medium-list/medium -i "./position=$i" -n -v ./track-list/track/recording/@id $rel_tmpdir/release2.xml) )
				[[ $? -ne 0 ]] && echo "xml: parsing error." && return 1
				for rel_rec in ${rel_recs[@]}
				do
					process_recording_mbid $rel_rec $2
					[[ $? -ne 0 ]] && echo "Error after calling to process_recording_mbid()." && return 1

					rel_rec=\'$rel_rec\'

					printf "INSERT INTO l_recording_to_medium (recording_id, medium_id) VALUES (
							@rec_id,
							@med_id
						);\n" >> $2
				done
			fi
		done
		unset -v i
	fi

	# Delete the temporal directory.
	rm -r $rel_tmpdir
	[[ $? -ne 0 ]] && echo "rm: could not remove temporal directory." && return 1
	cd $rel_oldpwd
	[[ $? -ne 0 ]] && echo "cd: could not change working directory." && return 1

	return 0
}

process_release_group_mbid () {

#       USAGE: process_release_group_mbid RELEASEGROUP_MBID QUERY_FILE
#
# DESCRIPTION: Search the `release_group` table for the
#              RELEASEGROUP_MBID value. If no record is found, get 
#              pertinent data to this value from musicbrainz.org and
#              build a query in order to update the database whith this
#              data. Append the query to the file pointed by QUERY_FILE.
#
#   PARAMETER: RELEASEGROUP_MBID: A 36 character string used by
#                                 musicbrainz.org as an unique
#                                 identifier.
#              QUERY_FILE:        The pathname of the file in which
#                                 append the sql query.

	local rgr_oldpwd=$(pwd)
	local rgr_tmpdir
	local rgr_mbid
	local rgr_id
	local -a rgr_arts
	local rgr_art
	local rgr_name
	local rgr_type
	local rgr_comment
	local rgr_wgeterr
	
	# Check for well-formatted arguments.
	if echo $1 | grep -q '^[-0123456789abcdef]\{36\}$'
	then
		rgr_mbid=\'$1\'
	else
		echo "Error: $1 is not a valid mbid."
		return 1
	fi

	# Change directory to the temporal root directory of the script.
	cd $tmp_root
	[[ $? -ne 0 ]] && echo "cd: could not change working directory." && return 1

	# Create a temporal directory for use of this function.
	rgr_tmpdir="$(mktemp -d rgr.XXX)"
	[[ $? -ne 0 ]] && echo "mktemp: could not create a temporal directory." && return 1
	rgr_tmpdir="$(readlink -f $rgr_tmpdir)"
	[[ $? -ne 0 ]] && echo "readlink: could not read the temporal directory pathname." && return 1

	# Is this release_group already in the database?
	rgr_id=$($mysql_path --skip-reconnect -u$user -p$pass \
		-D$db --skip-column-names -e "

		SELECT id FROM release_group WHERE mbid = $rgr_mbid;

	")
	[[ $? -ne 0 ]] && echo "Error after querying the database." && return 1

	printf "SET @rgr_id = %b;\n" \'$rgr_id\' >> $2

	# If it is not, update it.
	if [ -z $rgr_id ]
	then
		# Query musicbrainz.
		limit_mbcon
		wget --wait=5 -q -O - "http://musicbrainz.org/ws/2/release-group?query=rgid:$1" > $rgr_tmpdir/rg.xml
		rgr_wgeterr=$?
		[[ $rgr_wgeterr -ne 0 ]] && echo "wget: exit status is $rgr_wgeterr" && return 1
		MUSICBRAINZ_LTIME=$(date +%s)

		xml ed $rgr_tmpdir/rg.xml | sed -e 's/ xmlns.*=".*"//g' | sed -e 's/ext://g' > $rgr_tmpdir/release_group.xml

		# Parse data.
		if xml el $rgr_tmpdir/release_group.xml | grep -q "metadata/release-group-list/release-group/primary-type"
		then
			rgr_type="$(xml sel -t -m //metadata/release-group-list/release-group/primary-type -v . $rgr_tmpdir/release_group.xml)"
			[[ $? -ne 0 ]] && echo "xml: parsing error." && return 1
		fi
		escape_chars rgr_type "$rgr_type"
		rgr_type="${rgr_type##+([-[[:space:]])}"
		rgr_type=\'$rgr_type\'

		if xml el $rgr_tmpdir/release_group.xml | grep -q "metadata/release-group-list/release-group/title"
		then
			rgr_name="$(xml sel -t -m //metadata/release-group-list/release-group/title -v . $rgr_tmpdir/release_group.xml)"
			[[ $? -ne 0 ]] && echo "xml: parsing error." && return 1
		fi
		escape_chars rgr_name "$rgr_name"; rgr_name=\'$rgr_name\'

		if xml el $rgr_tmpdir/release_group.xml | grep -q "metadata/release-group-list/release-group/disambiguation"
		then
			rgr_comment="$(xml sel -t -m //metadata/release-group-list/release-group/disambiguation -v . $rgr_tmpdir/release_group.xml)"
			[[ $? -ne 0 ]] && echo "xml: parsing error." && return 1
		fi
		escape_chars rgr_comment "$rgr_comment"
		rgr_comment="${rgr_comment##+([-[[:space:]])}"
		rgr_comment=\'$rgr_comment\'

		# Update the database.
		printf "CALL insert_and_get_release_group (
				%b,
				%b,
				%b,
				%b,
				@rgroup_id
			);\n" $rgr_mbid "$rgr_type" "$rgr_name" "$rgr_comment" >> $2

		# Insert artist-release_group relationships.
		if xml el -a $rgr_tmpdir/release_group.xml | grep -q "metadata/release-group-list/release-group/artist-credit/name-credit/artist/@id"
		then
			rgr_arts=( $(xml sel -t -m //metadata/release-group-list/release-group/artist-credit/name-credit/artist/@id -n -v . $rgr_tmpdir/release_group.xml) )
			[[ $? -ne 0 ]] && echo "xml: parsing error." && return 1
			for rgr_art in ${rgr_arts[@]}
			do
				process_artist_mbid $rgr_art $2
				[[ $? -ne 0 ]] && echo "Error after calling to process_artist_mbid()." && return 1

				printf "CALL link_artist_to_release_group (
						@art_id,
						'is credited for',
						@rgroup_id 
					);
					SET @art_id = NULL;\n" >> $2
			done
		fi
	fi

	# Delete temporal directory.
	rm -r $rgr_tmpdir
	[[ $? -ne 0 ]] && echo "rm: could not remove temporal directory." && return 1
	cd $rgr_oldpwd
	[[ $? -ne 0 ]] && echo "cd: could not change working directory." && return 1

	return 0
}
