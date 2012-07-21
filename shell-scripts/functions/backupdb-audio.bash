#! /bin/bash

# backupdb.flacflib <Flac files functions of the backupdb.bash script.>
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
# REQUIREMENTS: shellsql <http://sourceforge.net/projects/shellsql/>
#               upvars.bash
#         BUGS: --
#        NOTES: Any suggestion is welcomed at auq..r@gmail.com (fill in
#               the dots).

source ~/code/bash/backupdb/upvars/upvars.bash

#===  FUNCTION =========================================================
#
#       USAGE: insert_audiofile HANDLE PATHNAME ID
#
# DESCRIPTION: Collect metadata related to the audio file pointed by
#              PATHNAME and insert it in all the related tables in the
#              database.
#
#  PARAMETERS: HANDLE    A connection to a database.
#              PATHNAME  A unix filesystem formatted string. 
#              ID        The value of the 'id' column in the 'file'
#                        table of the database.
insert_audiofile () {
	if [ $(file -b --mime-type "$2") == audio/x-flac ]
	then
		! insert_flacfile $1 $2 $3 && return 1
	fi
	return 0
}

#===  FUNCTION =========================================================
#
#       USAGE: update_audiofile HANDLE PATHNAME ID
#
# DESCRIPTION: Update metadata related to the audio file pointed by
#              PATHNAME and insert it in all the related tables in the
#              database.
#
#  PARAMETERS: HANDLE    A connection to a database.
#              PATHNAME  A unix filesystem formatted string. 
#              ID        The value of the 'id' column in the 'file'
#                        table of the database.
update_audiofile () {
	if [ $(file -b --mime-type "$2") == audio/x-flac ]
	then
		! update_flacfile $1 $2 $3 && return 1
	fi
	return 0
}

#===  FUNCTION =========================================================
#
#       USAGE: delete_audiofile HANDLE ID
#
# DESCRIPTION: Delete related metadata of the audio file whose id value
#              in the 'file' table is ID.
#
#  PARAMETERS: HANDLE  A connection to a database.
#              ID      The value of the 'id' column in the 'file'
#                      table of the database.
delete_audiofile () {
	# Delete the entry in the 'audio_file' table.
	local audio_file=$(shsql $1 $(printf '
		SELECT id FROM audio_file WHERE file="%b";' $2))
	[[ $? -ne 0 ]] && return 1
	shsql $1 $(printf '
		DELETE FROM audio_file WHERE file="%b";' $2)
	[[ $? -ne 0 ]] && return 1

	# Delete entries in the 'audio_file_tags' table.
	shsql $1 $(printf '
		DELETE FROM audio_file_tags WHERE audio_file=%b;
		' $audio_file)
	[[ $? -ne 0 ]] && return 1

	# Continue the delete process.
	local mimetype=$(shsql $1 $(printf '
		SELECT type
		FROM file INNER JOIN mime_type ON file.mime_type_id =
		mime_type.id
		WHERE file.id="%b";
		' $2))
	[[ $? -ne 0 ]] && return 1
	if [ $mimetype == \"audio/x-flac\" ]
	then
		! delete_flacfile $1 $audio_file && return 1
	fi
	return 0
}

#===  FUNCTION =========================================================
#
#       USAGE: get_flacmetadata ARRAYNAME1 ARRAYNAME2 BLOCKNUM PATHNAME
#
# DESCRIPTION: Get the vorbis comments stored in the flac file pointed
#              by PATHNAME. Store the left member of each comment in
#              ARRAYNAME1 and the right ones in ARRAYNAME2, both
#              situated in the caller's scope.
#
#  PARAMETERS: PATHNAME A unix filesystem formatted string. 
#
get_flacmetadata() {
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

#===  FUNCTION =========================================================
#
#       USAGE: get_flacfile PATHNAME TRACKID
#
# DESCRIPTION: Get metadata related to the flac file pointed by PATHNAME
#              and store it in the variables ALBUMID, ARTISTID,
#              ALBARTID and TRACKID declared in the caller's scope.
#
#  PARAMETERS: PATHNAME  A unix filesystem formatted string. 
#              TRACKID   The name of the variable declared in the
#                        caller's scope where to store the musicbrainz's
#                        track PUID.
#
get_flacfile () {
	local trackid="$(metaflac --show-tag=musicbrainz_trackid $1)"
	trackid="${trackid##musicbrainz_trackid=}"
	trackid="\"$trackid\""
	local $2 && upvar $2 $trackid
}

#===  FUNCTION =========================================================
#
#       USAGE: insert_flacfile HANDLE PATHNAME ID
#
# DESCRIPTION: Collect metadata related to the flac file pointed by
#              PATHNAME and insert it in all the related tables in the
#              database.
#
#  PARAMETERS: HANDLE    A connection to a database.
#              PATHNAME  A unix filesystem formatted string. 
#              ID        The value of the 'id' column in the 'file'
#                        table of the database.
insert_flacfile () {

	# Insert an entry in the 'audio_file' table.
	get_flacfile $2 mbrz_trackid
	[[ $? -ne 0 ]] && return 1
	shsql $1 $(printf 'INSERT INTO audio_file (file, type, trackid) 
		VALUES (%b, "%b", %b);' $3 flac "$mbrz_trackid")
	[[ $? -ne 0 ]] && return 1
	local audio_file=$(shsql $1 "SELECT LAST_INSERT_ID();")
	[[ $? -ne 0 ]] && return 1

	# Insert entries in the 'tag' table.
	local tags
	insert_audiofiletags $1 tags $2 $audio_file
	[[ $? -ne 0 ]] && return 1

	# Insert entries in the 'audio_file_tags' table.
	for tag in ${tags[@]}
	do
		shsql $1 $(printf 'INSERT INTO audio_file_tags 
			(audio_file, tag, tag_deleted) 
			VALUES (%b, %b, "false");' $audio_file $tag)
		[[ $? -ne 0 ]] && return 1
	done

	# Insert an entry in the 'flac_stream' table.
	! insert_flacstream $1 $2 && return 1
	local flacstream_id=$(shsql $1 "SELECT LAST_INSERT_ID();")
	[[ $? -ne 0 ]] && return 1

	# Insert an entry in the 'flac_file' table.
	shsql $1 $(printf 'INSERT INTO flac_file (audio_file,
		flacstream_id) VALUES (%b, %b);' \
		$audio_file $flacstream_id)
	[[ $? -ne 0 ]] && return 1
	return 0
}

#===  FUNCTION =========================================================
#
#       USAGE: update_flacfile HANDLE PATHNAME ID
#
# DESCRIPTION: Collect metadata related to the audio file pointed by
#              PATHNAME and insert it in all the related tables in the
#              database.
#
#  PARAMETERS: HANDLE    A connection to a database.
#              PATHNAME  A unix filesystem formatted string. 
#              ID        The value of the 'id' column in the 'file'
#                        table of the database.
update_flacfile () {

	# Update the entry in the 'audio_file' table.
	get_flacfile $2 mbrz_trackid
	[[ $? -ne 0 ]] && return 1
	shsql $1 $(printf 'UPDATE audio_file SET type="flac", trackid=%b 
		WHERE file=%b ;' "$mbrz_trackid" $3)
	[[ $? -ne 0 ]] && return 1

	# Get involved ids.
	local audio_file=$(shsql $1 $(printf 'SELECT id FROM audio_file 
		WHERE file=%b;' $3))
	[[ $? -ne 0 ]] && return 1
	local flacfile_id=$(shsql $1 $(printf 'SELECT id FROM flac_file
		WHERE audio_file=%b;' $audio_file))
	[[ $? -ne 0 ]] && return 1
	local flacstream_id=$(shsql $1 $(printf 'SELECT flacstream_id
		FROM flac_file WHERE audio_file=%b;' $audio_file))
	[[ $? -ne 0 ]] && return 1

	# Search the 'audio_file_tags' table for tags deleted from the
	# audio file and update that table.
	get_flacmetadata tagnames text 2 $2
	shsql $handle "SELECT name, text, tag_deleted, tag
       		FROM tag LEFT JOIN 
		audio_file_tags ON audio_file_tags.tag=tag.id 
		WHERE audio_file_tags.audio_file=$audio_file;" | (
		local found=false
		while row=$(shsqlline)
		do
			eval set $row
			for (( ind=0; ind<${#tagnames[@]}; ind++ ))
			do
				if [ "$1" == "${tagnames[ind]}" ]
				then
					if [ "$2" == "${text[ind]}" ]
					then
						found=true
						break
					fi
				fi
			done
			if [ \( $found == true \) -a \( $3 == "true" \) ]
			then
				shsql $handle $(printf 'UPDATE 
					audio_file_tags 
					SET tag_deleted="false" WHERE
					audio_file=%b AND tag=%b;' \
					$audio_file $4)
			fi
			if [ \( $found == false \) -a \( $3 == false \) ]
			then
				shsql $handle $(printf 'UPDATE 
					audio_file_tags 
					SET tag_deleted="true" WHERE
					audio_file=%b AND tag=%b;' \
					$audio_file $4)
			fi
			found=false
		done
	)

	# Insert entries in the 'tag' table.
	local tags
	insert_audiofiletags $1 tags $2 $audio_file
	[[ $? -ne 0 ]] && return 1

	# Insert entries in the 'audio_file_tags' table.
	for tag in ${tags[@]}
	do
		local match=$(shsql $1 $(printf 'SELECT COUNT(*) FROM 
			audio_file_tags WHERE tag=%b;' $tag))
		[[ $? -ne 0 ]] && return 1
		if [ $match == '"0"' ]
		then
			shsql $1 $(printf 'INSERT INTO audio_file_tags 
				(audio_file, tag, tag_deleted) VALUES 
				(%b, %b, "false");' $audio_file $tag)
			[[ $? -ne 0 ]] && return 1
		fi
	done

	# Update the entry in the 'flac_stream' table.
	! update_flacstream $1 $2 $flacstream_id && return 1
	return 0
}

#===  FUNCTION =========================================================
#
#       USAGE: delete_flacfile HANDLE ID
#
# DESCRIPTION: Delete related metadata of the flac file whose id value
#              in the 'audio_file' table is ID.
#
#  PARAMETERS: HANDLE  A connection to a database.
#              ID      The value of the 'id' column in the 'audio_file'
#                      table of the database.
delete_flacfile () {
	local flacfile_id=$(shsql $1 $(printf 'SELECT id FROM
		flac_file WHERE audio_file=%b;' $2))
	[[ $? -ne 0 ]] && return 1
	local flacstream_id=$(shsql $1 $(printf 'SELECT flacstream_id
		FROM flac_file WHERE id=%b;' $flacfile_id))
	[[ $? -ne 0 ]] && return 1

	# Delete the entry in the 'flac_stream' table.
	! delete_flacstream $1 $flacstream_id && return 1

	# Delete the entry in the 'flac_file' table.
	shsql $1 $(printf 'DELETE FROM flac_file WHERE id=%b;' \
		$flacfile_id)
	[[ $? -ne 0 ]] && return 1
	return 0
}

#===  FUNCTION =========================================================
#
#       USAGE: get_flacstream PATHNAME MINBCKSIZE MAXBCKSIZE
#                      MINFRMSIZE TOTSAMPLES SAMPLERATE CHANNELS BPS MD5
#
# DESCRIPTION: Get metadata related to the stream of the flac file
#              pointed by PATHNAME and store it in the variables
#              MINBCKSIZE, MAXBCKSIZE, MINFRMSIZE, MAXFRMSIZE,
#              TOTSAMPLES, SAMPLERATE, CHANNELS, BPS and MD5, declared
#              in the caller's scope.
#
#  PARAMETERS: PATHNAME    A unix filesystem formatted string. 
#              MINBCKSIZE  The name of the variable declared in the
#                          caller's scope where to store the minimum
#                          block size.
#              MAXBCKSIZE  The name of the variable declared in the
#                          caller's scope where to store the maximum
#                          block size.
#              MINFRMSIZE  The name of the variable declared in the
#                          caller's scope where to store the minimum
#                          frame size.
#              MAXFRMSIZE  The name of the variable declared in the
#                          caller's scope where to store the maximum
#                          frame size.
#              TOTSAMPLES  The name of the variable declared in the
#                          caller's scope where to store the total
#                          number of samples.
#              SAMPLERATE  The name of the variable declared in the
#                          caller's scope where to store the sample
#                          rate.
#              CHANNELS    The name of the variable declared in the
#                          caller's scope where to store the number of
#                          channels.
#              BPS         The name of the variable declared in the
#                          caller's scope where to store the number of
#                          bits per sample.
#              MD5         The name of the variable declared in the
#                          caller's scope where to store the md5sum of
#                          the original audio stream.
#
get_flacstream () {
	get_flacmetadata tagnames text 0 $1
	[[ $? -ne 0 ]] && return 1
	for (( ind=0; ind<${#tagnames[@]}; ind++ ))
	do
		case "${tagnames[ind]}" in
			'minimum blocksize') minbsze="${text[ind]}"
			                     ;;
			'maximum blocksize') maxbsze="${text[ind]}"
			                     ;;
			'minimum framesize') minfsze="${text[ind]}"
			                     ;;
			'maximum framesize') maxfsze="${text[ind]}"
			                     ;;
			'sample_rate')       samplerate="${text[ind]}"
			                     ;;
			'channels')          chann="${text[ind]}"
			                     ;;
			'bits_per_sample')   bpers="${text[ind]}"
			                     ;;
			'total samples')     totsamp="${text[ind]}"
			                     ;;
			'MD5 signature')     md5sum="${text[ind]}"
			                     ;;
		esac
	done
	local $2 && upvar $2 $minbsze
	local $3 && upvar $3 $maxbsze
	local $4 && upvar $4 $minfsze
	local $5 && upvar $5 $maxfsze
	local $6 && upvar $6 $totsamp
	local $7 && upvar $7 $samplerate
	local $8 && upvar $8 $chann
	local $9 && upvar $9 $bpers
	local ${10} && upvar ${10} $md5sum
	
}

#===  FUNCTION =========================================================
#
#       USAGE: insert_flacstream HANDLE PATHNAME
#
# DESCRIPTION: Collect metadata related to the audio file pointed by
#              PATHNAME and insert it in all the related tables in the
#              database.
#
#  PARAMETERS: HANDLE    A connection to a database.
#              PATHNAME  A unix filesystem formatted string. 
#
insert_flacstream () {
	get_flacstream $2 minbsize maxbsize minfsize maxfsize tsamples \
		sample_rate channels bps md5
	[[ $? -ne 0 ]] && return 1
	shsql $1 $(printf 'INSERT INTO flac_stream (min_blocksize,
		max_blocksize, min_framesize, max_framesize, 
		total_samples, sample_rate, channels, bits_per_sample,
		MD5_signature) VALUES
		("%b","%b","%b","%b","%b","%b","%b","%b","%b");' \
		"$minbsize" "$maxbsize" "$minfsize" "$maxfsize" \
		"$tsamples" \
		"$sample_rate" "$channels" "$bps" "$md5")
	[[ $? -ne 0 ]] && return 1
	return 0
}

#===  FUNCTION =========================================================
#
#       USAGE: update_flacstream HANDLE ID
#
# DESCRIPTION: Collect metadata related to the audio file pointed by
#              PATHNAME and insert it in all the related tables in the
#              database.
#
#  PARAMETERS: HANDLE    A connection to a database.
#              PATHNAME  A unix filesystem formatted string. 
#              ID        The value of the 'id' column in the
#                        'flac_stream' table.
#
update_flacstream () {
	get_flacstream $2 minbsize maxbsize minfsize maxfsize tsamples \
	       	sample_rate channels bps md5
	[[ $? -ne 0 ]] && return 1
	shsql $1 $(printf 'UPDATE flac_stream SET min_blocksize="%b",
		max_blocksize="%b", min_framesize="%b", 
		max_framesize="%b", total_samples="%b", 
		sample_rate="%b", channels="%b", bits_per_sample="%b", 
		MD5_signature="%b" WHERE id=%b;'\
		"$minbsize" "$maxbsize" "$minfsize" "$maxfsize" \
		"$tsamples" "$sample_rate" "$channels" "$bps" "$md5" \
		$3)
	[[ $? -ne 0 ]] && return 1
	return 0
}

#===  FUNCTION =========================================================
#
#       USAGE: delete_flacstream HANDLE ID
#
# DESCRIPTION: Delete an entry in the 'flac_stream' table.
#
#  PARAMETERS: HANDLE  A connection to a database.
#              ID      The value of the 'id' column in the 'flac_stream'
#                      table.
#
delete_flacstream () {
	shsql $1 $(printf 'DELETE FROM flac_stream WHERE id=%b;' $2)
	[[ $? -ne 0 ]] && return 1
	return 0
}

#===  FUNCTION =========================================================
#
#       USAGE: insert_tag HANDLE VARNAME TAGNAME TEXT
#
# DESCRIPTION: Search the 'tag' table for an entry with the specified
#              TAGNAME and TEXT. If no entry is found, insert a new one.
#              In either case, store the corresponding id number in the
#              variable VARNAME.
#
#  PARAMETERS: HANDLE   A connection to a database.
#              VARNAME  A variable in the caller's scope.
#              TAGNAME  The left member of a tag.
#              TEXT     The right member of a tag.
#
insert_tag () {
	local match
	local id
	match=$(shsql $1 $(printf 'SELECT COUNT(*) FROM tag WHERE
		name="%b" AND text="%b";' "$3" "$4"))
	[[ $? -ne 0 ]] && return 1
	if [ $match == '"0"' ]
	then
		shsql $1 $(printf 'INSERT INTO tag (name, text) 
			VALUES ("%b", "%b");' "$3" "$4")
		[[ $? -ne 0 ]] && return 1
	fi
	id=$(shsql $1 $(printf 'SELECT id FROM tag WHERE
		name="%b" AND text="%b";' "$3" "$4"))
	[[ $? -ne 0 ]] && return 1
	local $2 && upvar $2 $id
}

#===  FUNCTION =========================================================
#
#       USAGE: insert_audiofiletags HANDLE VARNAME PATHNAME AUDIOFILE_ID
#
# DESCRIPTION: Get the comments of the audio file whose id is
#              AUDIOFILE_ID and insert them in the corresponding tables.
#
#  PARAMETERS: HANDLE    A connection to a database.
#              VARNAME   A variable in the caller's scope.
#              PATHNAME  A unix filesystem formatted string. 
#              ID        The id number of the audio file in the table
#                        'audio_file'.
#
insert_audiofiletags () {
	local -a tagsarr
	if [ $(file -b --mime-type "$3") == audio/x-flac ]
	then
		get_flacmetadata tagnames text 2 $3
	fi
	for (( ind=0; ind<${#tagnames[@]}; ind++ ))
	do
		insert_tag $1 tag "${tagnames[ind]}" "${text[ind]}"
		tagsarr+=( "$tag" )
	done
	local $2 && upvars -a${#tagsarr[@]} $2 "${tagsarr[@]}"
}
