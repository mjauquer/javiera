#! /bin/bash

# javiera-audio.bash <Audio files functions of the javiera.bash script.>
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

source ~/projects/javiera/shell-scripts/functions/javiera-musicbrainz.bash ||
	exit 1

insert_audio_file () {

#       USAGE: insert_audio_file PATHNAME FILE_ID
#
# DESCRIPTION: Collect metadata related to the audio file pointed by
#              PATHNAME and insert it in all the related tables in the
#              database.
#
#  PARAMETERS: PATHNAME  A unix filesystem formatted string. 
#              FILE_ID   The value of the 'id' column in the 'file'
#                        table of the database.

	local file_id=$2 
	local aud_rel_mbid
	local aud_med_count
	local aud_med_pos
	local aud_rec_mbid
	local aud_oldpwd=$(pwd)
	local aud_tmpdir
	local -i aud_i
	local -i aud_j

	# Change directory to the temporal root directory of the script.
	cd $tmp_root
	[[ $? -ne 0 ]] && echo "cd: could not change working directory." && return 1

	# Create a temporal directory for use of this function.
	aud_tmpdir="$(mktemp -d aud.XXX)"
	[[ $? -ne 0 ]] && echo "mktemp: could not create a temporal directory." && return 1
	aud_tmpdir="$(readlink -f $aud_tmpdir)"
	[[ $? -ne 0 ]] && echo "readlink: could not read the temporal directory pathname." && return 1

	# Insert an entry in the 'audio_file' table and get the
	# audio_file_id.

	file_id=\"$file_id\"
	local aud_file_id=$($mysql_path --skip-reconnect -u$user -p$pass \
		-D$db --skip-column-names -e "

		START TRANSACTION;
		CALL insert_audio_file (
			$file_id
		);
		SELECT MAX(id) FROM audio_file;
		COMMIT;

	")
	[[ $? -ne 0 ]] && return 1

	# Process the audio file according to its mime-type.
	if [ $(file -b --mime-type "$1") == audio/x-flac ]
	then
		insert_flac_file $1 $aud_file_id
		if [[ $? -ne 0 ]]
		then
			echo "Error after call to insert_flac_file()."
			return 1
		fi

		aud_rel_mbid=$(metaflac --show-tag=musicbrainz_albumid $1)
		aud_rel_mbid=${aud_rel_mbid##*=}
		aud_med_count=$(metaflac --show-tag=totaldiscs $1)
		aud_med_count=${aud_med_count##*=}
		if [ -z $aud_med_count ]
		then
			aud_med_count=$(metaflac --show-tag=disctotal $1)
			aud_med_count=${aud_med_count##*=}
		fi
		aud_med_pos=$(metaflac --show-tag=discnumber $1)
		aud_med_pos=${aud_med_pos##*=}
		aud_rec_mbid=$(metaflac --show-tag=musicbrainz_trackid $1)
		aud_rec_mbid=${aud_rec_mbid##*=}

		if ! [[ -z $aud_rel_mbid ]]
		then
			while true
			do
				aud_i=$(expr $aud_i + 1)
				> $aud_tmpdir/aud_relquery.mysql
				process_release_mbid $aud_rel_mbid $aud_tmpdir/aud_relquery.mysql
				if [ $? -ne 0 ]
				then
					printf "\nError after a call to process_release_mbid().
						(audio file id: %b)
						(release mbid: %b)
						(attempt nº: %b)\n" $aud_file_id $aud_rel_mbid $aud_i 
					continue
				fi
				break
			done
			$mysql_path --skip-reconnect -u$user -p$pass -D$db \
				--skip-column-names -e "

				START TRANSACTION;
				source $aud_tmpdir/aud_relquery.mysql
				COMMIT;
			"
			if [ $? -ne 0 ]
			then
				echo "insert_audio_file(): Error after querying the database."
				return 1
			fi
		elif ! [[ -z $aud_rec_mbid ]] 
		then
			while true
			do
				aud_j=$(expr $aud_j + 1)
				> $aud_tmpdir/aud_recquery.mysql
				process_recording_mbid $aud_rec_mbid $aud_tmpdir/aud_recquery.mysql
				if [ $? -ne 0 ]
				then
					printf "\nError after a call to process_recording_mbid().
						(audio file id: %b)
						(recording mbid: %b)
						(attempt nº: %b)\n" $aud_file_id $aud_rec_mbid $aud_j 
					continue
				fi
				break
			done
			$mysql_path --skip-reconnect -u$user -p$pass -D$db \
				--skip-column-names -e "

				START TRANSACTION;
				source $aud_tmpdir/aud_recquery.mysql
				COMMIT;
			"
			if [ $? -ne 0 ]
			then
				echo "insert_audio_file(): Error after querying the database."
				return 1
			fi
		fi

		aud_file_id=\'$aud_file_id\'
		aud_rel_mbid=\'$aud_rel_mbid\'
		aud_med_count=\'$aud_med_count\'
		aud_med_pos=\'$aud_med_pos\'
		aud_rec_mbid=\'$aud_rec_mbid\'

		$mysql_path --skip-reconnect -u$user -p$pass \
			-D$db --skip-column-names -e "

			START TRANSACTION;
			CALL link_audio_file_to_recording (
				$aud_file_id,
				$aud_rel_mbid,
				$aud_med_count,
				$aud_med_pos,
				$aud_rec_mbid
			);
			COMMIT;"

		if [ $? -ne 0 ]
		then
			echo "insert_audio_file(): Error after querying the database."
			return 1
		fi
	fi

	# Delete the temporal directory.
	rm -r $aud_tmpdir
	[[ $? -ne 0 ]] && echo "rm: could not remove temporal directory." && return 1
	cd $aud_oldpwd
	[[ $? -ne 0 ]] && echo "cd: could not change working directory." && return 1

	return 0
}

insert_flac_file () {
	
#       USAGE: insert_flac_file PATHNAME AUDIO_FILE_ID
#
# DESCRIPTION: Collect metadata related to the flac file pointed by
#              PATHNAME and insert it in all the related tables in the
#              database.
#
#  PARAMETERS: PATHNAME      A unix filesystem formatted string. 
#              AUDIO_FILE_ID The value of the 'id' column in the
#                            'audio_file' table of the database.

	# Insert an entry in the 'flac_file' table and get the
	# flac_file_id.
	local audio_file_id=$2; audio_file_id=\"$audio_file_id\"
	local min_blocksize=\"$(metaflac --show-min-blocksize $1)\"
	local max_blocksize=\"$(metaflac --show-max-blocksize $1)\"
	local min_framesize=\"$(metaflac --show-min-framesize $1)\"
	local max_framesize=\"$(metaflac --show-max-framesize $1)\"
	local sample_rate=\"$(metaflac --show-sample-rate $1)\"
	local channels=\"$(metaflac --show-channels $1)\"
	local bits_per_sample=\"$(metaflac --show-bps $1)\"
	local total_samples=\"$(metaflac --show-total-samples $1)\"
	local md5sum=\"$(metaflac --show-md5sum $1)\"

	local flac_file_id=$($mysql_path --skip-reconnect -u$user -p$pass \
		-D$db --skip-column-names -e "

		START TRANSACTION;
		CALL insert_flac_file (
			$audio_file_id,
			$min_blocksize,
			$max_blocksize,
			$min_framesize,
			$max_framesize,
			$sample_rate,
			$channels,
			$bits_per_sample,
			$total_samples,
			$md5sum
		);
		SELECT MAX(id) FROM flac_file;
		COMMIT;

	")
	[[ $? -ne 0 ]] && return 1

	# Insert metadata entries related to the picture metadata
	# block.
	! insert_flac_metadata PICTURE $1 $flac_file_id && return 1

	# Insert metadata entries related to the vorbis_comment metadata
	# block.
	! insert_flac_metadata VORBIS_COMMENT $1 $flac_file_id && return 1

	return 0
}

insert_flac_metadata() {

#       USAGE: insert_flac_metadata BLKTYPE PATHNAME FLAC_ID
#
# DESCRIPTION: Get metadata from the flac file pointed by PATHNAME. 
#              Insert it in all the related tables in the database.
#
#  PARAMETERS: BLKTYPE  The type of the metadata block from which data
#                       will be retrieved (see man metaflac).
#              PATHNAME A unix filesystem formatted string. 
#              FLAC_ID  The value of the 'id' column in the 'audio_file'
#                       table of the database.

	local -a col1
	local -a col2
	local skip=true
	local char
	local line
	local procedure
	local flac_tmpdir=$(readlink -f $(mktemp -d flac_tmpdir.XXX))
	if [ ! -d $flac_tmpdir ]
	then
		echo "Coudn't create a temporal directory."
		return 1
	fi
	if [ $1 == STREAMINFO ]
	then
		char=":"
	elif [ $1 == VORBIS_COMMENT ]
	then
		char="="
	elif [ $1 == PICTURE ]
	then
		char=":"
	else
		return 1
	fi
	metaflac --list --block-type=$1 $2 | sed ':begin;N;s/\n\([^ ][^ ][^ ][^ ][^c][^o][^m][^m][^e][^n]\)/ \1/;tbegin;P;D' > $flac_tmpdir/tempfile.txt
	while read line
	do
		if [[ "$line" =~ length:.* ]]
		then
			skip=false
			continue
		elif [[ "$line" =~ data:.* ]]
		then
			break
		fi
		if [ $skip == false ]
		then
			line="${line##*comment\[*\]: }"
			[[ "$line" =~ comments:.* ]] && continue
			if [[ "$line" =~ "vendor string:".* ]]
			then
				col1+=( "vendor string" )
				col2+=( "${line##*string: }" )
				continue
			fi
			col1+=( "${line%%${char}*}" )
			col2+=( "${line##*${char}}" )
		fi
	done < $flac_tmpdir/tempfile.txt
	rm -r $flac_tmpdir
	[[ $? -ne 0 ]] && return 1

	# For each tag, insert an entry in the database.
	local flac_file_id=$3; flac_file_id=\"$flac_file_id\"
	for (( ind=0; ind<${#col1[@]}; ind++)) 
	do
		local field1="${col1[ind]}"
		local field2="${col2[ind]}"
		escape_chars field1 "$field1"
		escape_chars field2 "$field2"

		case "$field1" in
			[Cc][Oo][Mm][Mm][Ee][Nn][Tt]) ;&
			[Ee][Nn][Cc][Oo][Dd][Ee][Rr]) ;&
			"vendor string")              field1="\"$field1\""
			                              field2="\"$field2\""
			                              local mtype="\"$1\""
			                              $mysql_path --skip-reconnect -u$user -p$pass \
			                              	-D$db --skip-column-names -e "

			                              	START TRANSACTION;
			                              	CALL insert_flac_metadata_entry (
			                                	$flac_file_id,
			                                 	$mtype,
				                                	$field1,
				                              	$field2
		                              	        );
				                        COMMIT;

				                      "
				                      [[ $? -ne 0 ]] && return 1
				                      ;;
		esac
	done

	return 0
}

legacy_release_mbid () {

	local lgy_oldpwd=$(pwd)
	local -a mbids
	local lgy_tmpdir

	# Change directory to the temporal root directory of the script.
	cd $tmp_root
	[[ $? -ne 0 ]] && echo "cd: could not change working directory." && return 1

	# Create a temporal directory for use of this function.
	lgy_tmpdir="$(mktemp -d lgy.XXX)"
	[[ $? -ne 0 ]] && echo "mktemp: could not create a temporal directory." && return 1
	lgy_tmpdir="$(readlink -f $lgy_tmpdir)"
	[[ $? -ne 0 ]] && echo "readlink: could not read the temporal directory pathname." && return 1

	mbids=( $( $mysql_path --skip-reconnect -u$user -p$pass \
		-D$db --skip-column-names -e "

		START TRANSACTION;
		SELECT DISTINCT column2
			FROM flac_metadata_entry
			WHERE column1 LIKE 'musicbrainz_albumid';
		COMMIT;") )


	# Process mbids.
	for (( pos=0; pos < ${#mbids[@]}; pos++ ))
	do
		echo "${pos}) ${mbids[pos]}"

		> $lgy_tmpdir/legacy_relquery.mysql
		process_release_mbid ${mbids[pos]} $lgy_tmpdir/legacy_relquery.mysql
		if [ $? -ne 0 ]
		then
			echo "Error after a call to process_release_mbid() (mbid: ${mbids[pos]})"
			continue
		fi
		$mysql_path --skip-reconnect -u$user -p$pass -D$db \
			--skip-column-names -e "

			START TRANSACTION;
			source $lgy_tmpdir/legacy_relquery.mysql
			COMMIT;
		"
		if [ $? -ne 0 ]
		then
			error_exit "$LINENO: Error after a call to mysql in order to insert a release (mbid: ${mbids[pos]})."
			continue
		fi
	done

	# Delete the temporal directory.
	rm -r $lgy_tmpdir
	[[ $? -ne 0 ]] && echo "rm: could not remove temporal directory." && return 1
	cd $lgy_oldpwd
	[[ $? -ne 0 ]] && echo "cd: could not change working directory." && return 1
}

legacy_link () {

	local -a flac_ids=( $( $mysql_path --skip-reconnect -u$user -p$pass \
			-D$db --skip-column-names -e "

			SELECT DISTINCT flac_file_id
				FROM l_flac_file_to_metadata_entry; ") )

	[[ $? -ne 0 ]] && echo "Error" && return 1

	for (( pos=0; pos < ${#flac_ids[@]}; pos++ ))
	do
		flac_id=\'${flac_ids[pos]}\'; echo "flac_id: $flac_id"
		audio_file_id=$($mysql_path --skip-reconnect -u$user -p$pass \
				-D$db --skip-column-names -e "

			SELECT audio_file_id
				FROM flac_file
				WHERE id = $flac_id;")

		[[ $? -ne 0 ]] && echo "Error" && return 1

		audio_file_id=\'$audio_file_id\'
		echo "audio_file_id: $audio_file_id"

		release_mbid=$($mysql_path --skip-reconnect -u$user -p$pass \
				-D$db --skip-column-names -e "
			SELECT column2
				FROM flac_metadata_entry
				INNER JOIN l_flac_file_to_metadata_entry AS link
					ON flac_metadata_entry.id = link.flac_metadata_entry_id
				WHERE link.flac_file_id = $flac_id
				AND column1 LIKE 'musicbrainz_albumid';")
		
		[[ $? -ne 0 ]] && echo "Error" && return 1

		release_mbid=\'$release_mbid\'
		echo "release_mbid: $release_mbid"

		medium_count=$($mysql_path --skip-reconnect -u$user -p$pass \
				-D$db --skip-column-names -e "

			SELECT column2
				FROM flac_metadata_entry
				INNER JOIN l_flac_file_to_metadata_entry AS link
					ON flac_metadata_entry.id = link.flac_metadata_entry_id
				WHERE link.flac_file_id = $flac_id
				AND column1 LIKE 'totaldiscs';")

		[[ $? -ne 0 ]] && echo "Error" && return 1

		medium_count=\'$medium_count\'
		echo "medium_count: $medium_count"

		if [ -z $medium_count ]
		then
			medium_count=$($mysql_path --skip-reconnect -u$user -p$pass \
					-D$db --skip-column-names -e "

				SELECT column2
					FROM flac_metadata_entry
					INNER JOIN l_flac_file_to_metadata_entry AS link
						ON flac_metadata_entry.id = link.flac_metadata_entry_id
					WHERE link.flac_file_id = $flac_id
					AND column1 LIKE 'disctotal';")

			[[ $? -ne 0 ]] && echo "Error" && return 1

			medium_count=\'$medium_count\'
			echo "medium_count: $medium_count"
		fi

		medium_position=$($mysql_path --skip-reconnect -u$user -p$pass \
				-D$db --skip-column-names -e "

			SELECT column2
				FROM flac_metadata_entry
				INNER JOIN l_flac_file_to_metadata_entry AS link
					ON flac_metadata_entry.id = link.flac_metadata_entry_id
				WHERE link.flac_file_id = $flac_id
				AND column1 LIKE 'discnumber';")

		[[ $? -ne 0 ]] && echo "Error" && return 1

		medium_position=\'$medium_position\'
		echo "medium_position: $medium_position"

		recording_mbid=$($mysql_path --skip-reconnect -u$user -p$pass \
				-D$db --skip-column-names -e "

			SELECT column2
				FROM flac_metadata_entry
				INNER JOIN l_flac_file_to_metadata_entry AS link
					ON flac_metadata_entry.id = link.flac_metadata_entry_id
				WHERE link.flac_file_id = $flac_id
				AND column1 LIKE 'musicbrainz_trackid';")

		[[ $? -ne 0 ]] && echo "Error" && return 1

		recording_mbid=\'$recording_mbid\'
		echo "recording_mbid: $recording_mbid"

		$mysql_path --skip-reconnect -u$user -p$pass \
				-D$db --skip-column-names -e "

				CALL link_audio_file_to_recording (
					$audio_file_id,
					$release_mbid,
					$medium_count,
					$medium_position,
					$recording_mbid)"
					
		[[ $? -ne 0 ]] && echo "Error" && return 1

	done
}
