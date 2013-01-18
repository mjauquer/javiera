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

echo "entra: insert_audio_file()"

	local file_id=$2 
	local release_mbid
	local recording_mbid

	# Insert an entry in the 'audio_file' table and get the
	# audio_file_id.

	file_id=\"$file_id\"
	local audio_file_id=$($mysql_path --skip-reconnect -u$user -p$pass \
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
		insert_flac_file $1 $audio_file_id
		if [[ $? -ne 0 ]]
		then
			echo "Error after call to insert_flac_file()."
			return 1
		fi

		release_mbid=$(metaflac --show-tag=musicbrainz_albumid $1)
		release_mbid=${release_mbid##*=}
		recording_mbid=$(metaflac --show-tag=musicbrainz_trackid $1)
		recording_mbid=${recording_mbid##*=}
	fi
echo "sale: insert_audio_file()"
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

echo "entra: insert_flac_file()"

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

echo "sale: insert_flac_file()"

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

echo "entra: insert_flac_metadata()"

	local -a col1
	local -a col2
	local skip=true
	local char
	local line
	local procedure
	local tempdir=$(readlink -f $(mktemp -d tmp.XXX))
	if [ ! -d $tempdir ]
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
	metaflac --list --block-type=$1 $2 > $tempdir/tempfile.txt
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
	done < $tempdir/tempfile.txt
	rm -r $tempdir
	[[ $? -ne 0 ]] && return 1

	# For each tag, insert an entry in the database.
	local flac_file_id=$3; flac_file_id=\"$flac_file_id\"
	for (( ind=0; ind<${#col1[@]}; ind++)) 
	do
		local field1="${col1[ind]}"
		local field2="${col2[ind]}"
		escape_chars field1 "$field1"; field1="\"$field1\""
		escape_chars field2 "$field2"; field2="\"$field2\""
		case ${col1[ind]} in
			[mM][uU][sS][iI][cC][bB][rR][aA[iI][nN][zZ]_[aA][rR][tT][iI][sS][tT][iI][dD])                          process_artist_mbid ${col2[ind]}
			                                                                                                       ;;
			[mM][uU][sS][iI][cC][bB][rR][aA][iI][nN][zZ]_[aA][lL][bB][uU][mM][aA][rR][tT][iI][sS][tT][iI][dD])     process_artist_mbid ${col2[ind]}
			                                                                                                       ;;
			[mM][uU][sS][iI][cC][bB][rR][aA][iI][nN][zZ]_[tT][rR][aA][cC][kK][iI][dD])                             process_recording_mbid ${col2[ind]}
			                                                                                                       ;;
			[mM][uU][sS][iI][cC][bB][rR][aA][iI][nN][zZ]_[rR][eE][lL][eE][aA][sS][eE][gG][rR][oO][uU][pP][iI][dD]) process_release_group_mbid ${col2[ind]}
			                                                                                                       ;;
			[mM][uU][sS][iI][cC][bB][rR][aA][iI][nN][zZ]_[aA][lL][bB][uU][mM][iI][dD])                             process_release_mbid ${col2[ind]}
			                                                                                                       ;;
		esac
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
	done
echo "sale: insert_flac_metadata()"
	return 0
}
