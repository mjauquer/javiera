#! /bin/bash

# javiera.flacflib <Flac files functions of the javiera.bash script.>
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
# REQUIREMENTS: upvars.bash
#         BUGS: --
#        NOTES: Any suggestion is welcomed at auq..r@gmail.com (fill in
#               the dots).

source ~/projects/javiera/upvars/upvars.bash

get_flac_metadata() {

#       USAGE: get_flac_metadata ARRAY1 ARRAY2 BLOCKNUM PATHNAME
#
# DESCRIPTION: Get the vorbis comments stored in the flac file pointed
#              by PATHNAME. Store the left member of each comment in
#              ARRAY1 and the right ones in ARRAY2.
#
#  PARAMETERS: ARRAY1   The name of an array variable in the caller's
#                       scope.
#              ARRAY2   The name of an array variable in the caller's
#                       scope.
#              BLOCKNUM The number of the metadata block from which data
#                       will be retrieved.
#              PATHNAME A unix filesystem formatted string. 

	local -a left
	local -a right
	local skip=true
	local char
	local line
	local tempdir=$(readlink -f $(mktemp -d tmp.XXX))
	if [ ! -d $tempdir ]
	then
		echo "Coudn't create a temporal directory."
		return 1
	fi
	if [ $3 == 0 ]
	then
		char=":"
	elif [ $3 == 2 ]
	then
		char="="
	else
		return 1
	fi
	metaflac --list --block-number=$3 $4 > $tempdir/tempfile.txt
	while read line
	do
		if [[ "$line" =~ length:.* ]]
		then
			skip=false
			continue
		fi
		if [ $skip == false ]
		then
			line="${line##*comment\[*\]: }"
			[[ "$line" =~ comments:.* ]] && continue
			if [[ "$line" =~ "vendor string:"* ]]
			then
				left+=( "vendor string" )
				right+=( "${line##*string: }" )
				continue
			fi
			left+=( "${line%%${char}*}" )
			right+=( "${line##*${char}}" )
		fi
	done < $tempdir/tempfile.txt
	rm -r $tempdir
	[[ $? -ne 0 ]] && return 1
	local $1 && upvars -a${#left[@]} $1 "${left[@]}"
	local $2 && upvars -a${#right[@]} $2 "${right[@]}"
}

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
			--skip-column-names -e "

			USE javiera;
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
		--skip-column-names -e "

		USE javiera;
		CALL insert_flac_file ($audio_file_id);
		SELECT MAX(id) FROM flac_file;

	")
	[[ $? -ne 0 ]] && return 1

	# Insert metadata entries related to the streaminfo metadata
	# block table.
	! insert_flac_streaminfo $1 $flac_file_id && return 1

	# Insert metadata entries related to the vorbis_comment metadata
	# block table.
	! insert_flac_vorbiscomment $1 $flac_file_id && return 1

	return 0
}

insert_flac_streaminfo () {

#       USAGE: insert_flac_streaminfo PATHNAME FLAC_FILE_ID
#
# DESCRIPTION: Collect the streaminfo metadata related to the flac file
#              pointed by PATHNAME and insert it in all the related
#              tables in the database.
#
#  PARAMETERS: PATHNAME     A unix filesystem formatted string. 
#              FLAC_FILE_ID The value of the 'id' column in the
#                           'audio_file' table of the database.

	! get_flac_metadata col1 col2 0 $1 && return 1

	# For each tag, insert an entry in the database.
	local flac_file_id=$2; flac_file_id=\"$flac_file_id\"
	for (( ind=0; ind<${#col1[@]}; ind++)) 
	do
		local field1="${col1[ind]}"; field1=\"$field1\"
		local field2="${col2[ind]}"; field2=\"$field2\"
		mysql --skip-reconnect -u$user -p$pass \
			--skip-column-names -e "

			USE javiera;
			CALL insert_flac_streaminfo_metadata_entry (
				$flac_file_id,
				$field1,
				$field2
			);

		"
		[[ $? -ne 0 ]] && return 1
	done

	return 0
}

insert_flac_vorbiscomment () {

#       USAGE: insert_flac_vorbiscomment PATHNAME FLAC_FILE_ID
#
# DESCRIPTION: Collect the vorbiscomment metadata related to the flac file
#              pointed by PATHNAME and insert it in all the related
#              tables in the database.
#
#  PARAMETERS: PATHNAME     A unix filesystem formatted string. 
#              FLAC_FILE_ID The value of the 'id' column in the
#                           'audio_file' table of the database.

	! get_flac_metadata col1 col2 2 $1 && return 1

	# For each tag, insert an entry in the database.
	local flac_file_id=$2; flac_file_id=\"$flac_file_id\"
	for (( ind=0; ind<${#col1[@]}; ind++)) 
	do
		local field1="${col1[ind]}"; field1=\"$field1\"
		local field2="${col2[ind]}"; field2=\"$field2\"
		mysql --skip-reconnect -u$user -p$pass \
			--skip-column-names -e "

			USE javiera;
			CALL insert_flac_vorbiscomment_metadata_entry (
				$flac_file_id,
				$field1,
				$field2
			);

		"
		[[ $? -ne 0 ]] && return 1
	done

	return 0
}
