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

	if [ $(file -b --mime-type "$1") == audio/x-flac ]
	then
		# Get data from the file.
		local record_id="$(metaflac --show-tag=musicbrainz_record_id $1)"
		record_id=${record_id##musicbrainz_record_id=}
		record_id=${record_id:-NULL}
		[[ $record_id != NULL ]] && record_id=\"$record_id\"
		local file_id=$2; file_id=\"$file_id\"

		# Insert an entry in the 'audio_file' table and get the
		# audio_file_id.
		local audio_file_id=$(mysql --skip-reconnect -u$user -p$pass \
			-D$db --skip-column-names -e "

			CALL insert_audio_file (
				$file_id,
				$record_id
			);
			SELECT MAX(id) FROM audio_file;

		")
		[[ $? -ne 0 ]] && return 1
		! insert_flac_file $1 $audio_file_id && return 1
	fi
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
	local flac_file_id=$(mysql --skip-reconnect -u$user -p$pass \
		-D$db --skip-column-names -e "

		CALL insert_flac_file ($audio_file_id);
		SELECT MAX(id) FROM flac_file;

	")
	[[ $? -ne 0 ]] && return 1

	# Insert metadata entries related to the picture metadata
	# block.
	! insert_flac_metadata PICTURE $1 $flac_file_id && return 1

	# Insert metadata entries related to the streaminfo metadata
	# block.
	! insert_flac_metadata STREAMINFO $1 $flac_file_id && return 1

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
	local tempdir=$(readlink -f $(mktemp -d tmp.XXX))
	if [ ! -d $tempdir ]
	then
		echo "Coudn't create a temporal directory."
		return 1
	fi
	if [ $1 == STREAMINFO ]
	then
		char=":"
		procedure="insert_flac_streaminfo_metadata_entry"
	elif [ $1 == VORBIS_COMMENT ]
	then
		char="="
		procedure="insert_flac_vorbiscomment_metadata_entry"
	elif [ $1 == PICTURE ]
	then
		char=":"
		procedure="insert_flac_picture_metadata_entry"
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
		escape_chars field1 "$field1"; field1="\"$field1\""
		local field2="${col2[ind]}"
		escape_chars field2 "$field2"; field2="\"$field2\""
		mysql --skip-reconnect -u$user -p$pass \
			-D$db --skip-column-names -e "

			CALL $procedure (
				$flac_file_id,
				$field1,
				$field2
			);

		"
		[[ $? -ne 0 ]] && return 1
	done
	return 0
}
