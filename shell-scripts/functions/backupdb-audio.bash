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
	local audiofile_id=$(shsql $1 $(printf 'SELECT id FROM
		audio_file WHERE file_id="%b";' $2))
	[[ $? -ne 0 ]] && return 1
	shsql $1 $(printf 'DELETE FROM audio_file WHERE 
		file_id="%b";' $2)
	[[ $? -ne 0 ]] && return 1

	# Continue the delete process.
	local mimetype=$(shsql $1 $(printf 'SELECT mimetype FROM file 
		WHERE id="%b";' $2))
	[[ $? -ne 0 ]] && return 1
	if [ $mimetype == \"audio/x-flac\" ]
	then
		! delete_flacfile $1 $audiofile_id && return 1
	fi
	return 0
}

#===  FUNCTION =========================================================
#
#       USAGE: get_flacfilemetadata PATHNAME ALBUMID ARTISTID ALBARTID 
#                      TRACKID
#
# DESCRIPTION: Get metadata related to the flac file pointed by PATHNAME
#              and store it in the variables ALBUMID, ARTISTID,
#              ALBARTID and TRACKID declared in the caller's scope.
#
#  PARAMETERS: PATHNAME  A unix filesystem formatted string. 
#              ALBUMID   The name of the variable declared in the
#                        caller's scope where to store the musicbrainz's
#                        album PUID.
#              ARTISTID  The name of the variable declared in the
#                        caller's scope where to store the musicbrainz's
#                        artist PUID.
#              ALBARTID  The name of the variable declared in the
#                        caller's scope where to store the musicbrainz's
#                        albumartist PUID.
#              TRACKID   The name of the variable declared in the
#                        caller's scope where to store the musicbrainz's
#                        track PUID.
#
get_flacfilemetadata () {
	local albumid="$(metaflac --show-tag=musicbrainz_albumid $1)"
	albumid="${albumid##musicbrainz_albumid=}"
	albumid="\"$albumid\""
	local artistid="$(metaflac --show-tag=musicbrainz_artistid $1)"
	artistid="${artistid##musicbrainz_artistid=}"
	artistid="\"$artistid\""
	local albartid="$(metaflac --show-tag=musicbrainz_albumartistid $1)"
	albartid="${albartid##musicbrainz_albumartistid=}"
	albartid="\"$albartid\""
	local trackid="$(metaflac --show-tag=musicbrainz_trackid $1)"
	trackid="${trackid##musicbrainz_trackid=}"
	trackid="\"$trackid\""
	local $2 && upvar $2 $albumid
	local $3 && upvar $3 $artistid
	local $4 && upvar $4 $albartid
	local $5 && upvar $5 $trackid
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
	get_flacfilemetadata $2 mbrz_albumid mbrz_artistid \
		mbrz_albartid mbrz_trackid
	[[ $? -ne 0 ]] && return 1
	shsql $1 $(printf 'INSERT INTO audio_file (file_id, 
		albumid, artistid, albumartistid, trackid) VALUES (%b, 
		%b, %b, %b, %b);' $3 "$mbrz_albumid" "$mbrz_artistid" \
		"$mbrz_albartid" "$mbrz_trackid")
	[[ $? -ne 0 ]] && return 1
	local audiofile_id=$(shsql $1 "SELECT LAST_INSERT_ID();")
	[[ $? -ne 0 ]] && return 1

	# Insert an entry in the 'flac_stream' table.
	! insert_flacstream $1 $2 && return 1
	local flacstream_id=$(shsql $1 "SELECT LAST_INSERT_ID();")
	[[ $? -ne 0 ]] && return 1

	# Insert an entry in the 'flac_comments' table.
	! insert_flaccomments $1 $2 && return 1
	local flaccomments_id=$(shsql $1 "SELECT LAST_INSERT_ID();")
	[[ $? -ne 0 ]] && return 1

	# Insert an entry in the 'flac_file' table.
	shsql $1 $(printf 'INSERT INTO flac_file (audiofile_id,
		flaccomments_id, flacstream_id) VALUES (%b, %b, %b);' \
		$audiofile_id $flaccomments_id $flacstream_id)
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
	get_flacfilemetadata $2 mbrz_albumid mbrz_artistid \
		mbrz_albartid mbrz_trackid
	[[ $? -ne 0 ]] && return 1
	shsql $1 $(printf 'UPDATE audio_file SET albumid=%b, 
		artistid=%b, albumartistid=%b, trackid=%b WHERE 
		file_id=%b ;' "$mbrz_albumid" "$mbrz_artistid" \
		"$mbrz_albartid" "$mbrz_trackid" $3)
	[[ $? -ne 0 ]] && return 1

	# Get involved ids.
	local audiofile_id=$(shsql $1 $(printf 'SELECT id FROM audio_file 
		WHERE file_id=%b;' $3))
	[[ $? -ne 0 ]] && return 1
	local flacfile_id=$(shsql $1 $(printf 'SELECT id FROM flac_file
		WHERE audiofile_id=%b;' $audiofile_id))
	[[ $? -ne 0 ]] && return 1
	local flacstream_id=$(shsql $1 $(printf 'SELECT flacstream_id
		FROM flac_file WHERE audiofile_id=%b;' $audiofile_id))
	[[ $? -ne 0 ]] && return 1
	local flaccomments_id=$(shsql $1 $(printf 'SELECT flaccomments_id
		FROM flac_file WHERE audiofile_id=%b;' $audiofile_id))
	[[ $? -ne 0 ]] && return 1

	# Update the entry in the 'flac_stream' table.
	! update_flacstream $1 $2 $flacstream_id && return 1

	# Update the entry in the 'flac_comments' table.
	! update_flaccomments $1 $2 $flaccomments_id && return 1
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
		flac_file WHERE audiofile_id=%b;' $2))
	[[ $? -ne 0 ]] && return 1
	local flaccomments_id=$(shsql $1 $(printf 'SELECT 
		flaccomments_id FROM flac_file WHERE id=%b;' \
		$flacfile_id))
	[[ $? -ne 0 ]] && return 1
	local flacstream_id=$(shsql $1 $(printf 'SELECT flacstream_id
		FROM flac_file WHERE id=%b;' $flacfile_id))
	[[ $? -ne 0 ]] && return 1

	# Delete the entry in the 'flac_comments' table.
	! delete_flaccomments $1 $flaccomments_id && return 1

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
#       USAGE: get_flacstreammetadata PATHNAME MINBCKSIZE MAXBCKSIZE
#                      MINFRMSIZE TOTSAMPLES SAMPLERATE CHANNELS BPS MD5
#
# DESCRIPTION: Get metadata related to the flac stream of the flac file
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
get_flacstreammetadata () {
	local minbsze=\"$(metaflac --show-min-blocksize $1)\"
	local maxbsze=\"$(metaflac --show-max-blocksize $1)\"
	local minfsze=\"$(metaflac --show-min-framesize $1)\"
	local maxfsze=\"$(metaflac --show-max-framesize $1)\"
	local totsamp=\"$(metaflac --show-total-samples $1)\"
	local samplerate=\"$(metaflac --show-sample-rate $1)\"
	local chann=\"$(metaflac --show-channels $1)\"
	local bpers=\"$(metaflac --show-bps $1)\"
	local md5sum=\"$(metaflac --show-md5sum $1)\"
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
	get_flacstreammetadata $2 minbsize maxbsize minfsize maxfsize \
		tsamples sample_rate channels bps md5
	[[ $? -ne 0 ]] && return 1
	shsql $1 $(printf 'INSERT INTO flac_stream (min_blocksize,
		max_blocksize, min_framesize, max_framesize, 
		total_samples, sample_rate, channels, bits_per_sample,
		MD5_signature) VALUES (%b,%b,%b,%b,%b,%b,%b,%b,%b);' \
		$minbsize $maxbsize $minfsize $maxfsize $tsamples \
		$sample_rate $channels $bps $md5)
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
	get_flacstreammetadata $2 minbsize maxbsize minfsize maxfsize \
		tsamples sample_rate channels bps md5
	[[ $? -ne 0 ]] && return 1
	shsql $1 $(printf 'UPDATE flac_stream SET min_blocksize=%b,
		max_blocksize=%b, min_framesize=%b, max_framesize=%b,
		total_samples=%b, sample_rate=%b, channels=%b, 
		bits_per_sample=%b, MD5_signature=%b WHERE id=%b;'\
		$minbsize $maxbsize $minfsize $maxfsize $tsamples \
		$sample_rate $channels $bps $md5 $3)
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
#       USAGE: get_flaccommentsmetadata PATHNAME ALBUM ARTIST ARTISTSORT
#                      DISCTOTAL TITLE TOTALTRACKS TRACKNUMBER
#
# DESCRIPTION: Get the comments of the flac file pointed by PATHNAME and
#              store them in the variables ALBUM, ARTIST, ARTISTSORT,
#              DISCNUMBER, DISCTOTAL, TITLE, TOTALTRACKS and TRACKNUMBER
#              declared in the caller's scope.
#
#  PARAMETERS: PATHNAME    A unix filesystem formatted string. 
#              ALBUM       The name of the variable declared in the
#                          caller's scope where to store the name of the
#                          album.
#              ARTIST      The name of the variable declared in the
#                          caller's scope where to store the name of the
#                          artist.
#              ARTISTSORT  The name of the variable declared in the
#                          caller's scope where to store the sorted name
#                          of the album.
#              DISCNUMBER  The name of the variable declared in the
#                          caller's scope where to store the number of
#                          disc.
#              DISCTOTAL   The name of the variable declared in the
#                          caller's scope where to store the total
#                          number of discs.
#              TITLE       The name of the variable declared in the
#                          caller's scope where to store the title.
#              TOTALTRACKS The name of the variable declared in the
#                          caller's scope where to store the total
#                          number of tracks.
#              TRACKNUMBER The name of the variable declared in the
#                          caller's scope where to store the number of
#                          track.
#
get_flaccommentsmetadata () {
	local albu="$(metaflac --show-tag=album $1)"
	albu="${albu##[Aa][Ll][Bb][Uu][Mm]=}"
	escape_chars albu "$albu"
	albu="\"$albu\""
	local artis="$(metaflac --show-tag=artist $1)"
	artis="${artis##[Aa][Rr][Tt][Ii][Ss][Tt]=}"
	escape_chars artis "$artis"
	artis="\"$artis\""
	local artisor="$(metaflac --show-tag=artistsort $1)"
	artisor="${artisor##[Aa][Rr][Tt][Ii][Ss][Tt][Ss][Oo][Rr][Tt]=}"
	escape_chars artisor "$artisor"
	artisor="\"$artisor\""
	local discnum="$(metaflac --show-tag=discnumber $1)"
	discnum="${discnum##[Dd][Ii][Ss][Cc][Nn][Uu][Mm][Bb][Ee][Rr]=}"
	escape_chars discnum "$discnum"
	discnum="\"$discnum\""
	local disctot="$(metaflac --show-tag=disctotal $1)"
	disctot="${disctot##[Dd][Ii][Ss][Cc][Tt][Oo][Tt][Aa][Ll]=}"
	escape_chars disctot "$disctot"
	disctot="\"$disctot\""
	local titl="$(metaflac --show-tag=title $1)"
	titl="${titl##[Tt][Ii][Tt][Ll][Ee]=}"
	escape_chars titl "$titl"
	titl="\"$titl\""
	local tottracks="$(metaflac --show-tag=totaltracks $1)"
	tottracks="${tottracks##[Tt][Oo][Tt][Aa][Ll][Tt][Rr][Aa][Cc][Kk][Ss]=}"
	tottracks="\"$tottracks\""
	local tracknum="$(metaflac --show-tag=tracknumber $1)"
	tracknum="${tracknum##[Tt][Rr][Aa][Cc][Kk][Nn][Uu][Mm][Bb][Ee][Rr]=}"
	tracknum="\"$tracknum\""
	local $2 && upvar $2 "$albu"
	local $3 && upvar $3 "$artis"
	local $4 && upvar $4 "$artisor"
	local $5 && upvar $5 "$discnum"
	local $6 && upvar $6 "$disctot"
	local $7 && upvar $7 "$titl"
	local $8 && upvar $8 "$tottracks"
	local $9 && upvar $9 "$tracknum"
}

#===  FUNCTION =========================================================
#
#       USAGE: insert_flaccomments HANDLE PATHNAME
#
# DESCRIPTION: Collect metadata related to the flac file pointed by
#              PATHNAME and insert it in the 'flac_comments' table.
#
#  PARAMETERS: HANDLE    A connection to a database.
#              PATHNAME  A unix filesystem formatted string. 
#
insert_flaccomments () {
	get_flaccommentsmetadata $2 album artist artistsort discnumber \
		disctotal title totaltracks tracknumber
	[[ $? -ne 0 ]] && return 1
	shsql $1 $(printf 'INSERT INTO flac_comments (album, artist,
		artistsort, discnumber, disctotal, title, totaltracks,
		tracknumber) VALUES (%b,%b,%b,%b,%b,%b,%b,%b);' \
		"$album" "$artist" "$artistsort" "$discnumber" \
		"$disctotal" "$title" "$totaltracks" "$tracknumber")
	[[ $? -ne 0 ]] && return 1
	return 0
}

#===  FUNCTION =========================================================
#
#       USAGE: update_flaccomments HANDLE PATHNAME ID
#
# DESCRIPTION: Collect metadata related to the flac file pointed by
#              PATHNAME and update it in all the related tables in the
#              database.
#
#  PARAMETERS: HANDLE    A connection to a database.
#              PATHNAME  A unix filesystem formatted string. 
#              ID        The value of the 'id' column in the 
#                        'flac_comments' of the database.
update_flaccomments () {
	get_flaccommentsmetadata $2 album artist artistsort discnumber \
		disctotal title totaltracks tracknumber
	[[ $? -ne 0 ]] && return 1
	shsql $1 $(printf 'UPDATE flac_comments SET album=%b, artist=%b,
		artistsort=%b, discnumber=%b, disctotal=%b, title=%b,
		totaltracks=%b, tracknumber=%b WHERE id=%b ;' "$album" \
		"$artist" "$artistsort" "$discnumber" "$disctotal" \
		"$title" "$totaltracks" "$tracknumber" $3)
	[[ $? -ne 0 ]] && return 1
	return 0
}

#===  FUNCTION =========================================================
#
#       USAGE: delete_flaccomments HANDLE ID
#
# DESCRIPTION: Delete an entry in the 'flac_comments' table.
#
#  PARAMETERS: HANDLE  A connection to a database.
#              ID      The value of the 'id' column in the
#                      'flac_comments' table.
#
delete_flaccomments () {
	shsql $1 $(printf 'DELETE FROM flac_comments WHERE id=%b;' $2)
	[[ $? -ne 0 ]] && return 1
	return 0
}
