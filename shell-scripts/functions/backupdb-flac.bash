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
#               upvars.bash, filetype.flib
#         BUGS: --
#        NOTES: Any suggestion is welcomed at auq..r@gmail.com (fill in
#               the dots).

#===  FUNCTION =========================================================
#
#       USAGE: delete_flacdata HANDLE ID
#
# DESCRIPTION: Delete from the database all the records corresponding
#              with ID.
#
#  PARAMETERS: HANDLE  A connection to a database.
#              ID      A number value related to the id column of the
#                      database's file table.
#
delete_flacdata () {
	shsql $1 $(printf 'DELETE FROM flac_streaminfo WHERE
		file_id="%b";' $2)
	[[ $? -ne 0 ]] && return 1
	shsql $1 $(printf 'DELETE FROM flac_comments WHERE 
		file_id="%b";' $2)
	[[ $? -ne 0 ]] && return 1
	shsql $1 $(printf 'DELETE FROM musicbrainz_ids WHERE 
		file_id="%b";' $2)
	[[ $? -ne 0 ]] && return 1
	return 0
}

#===  FUNCTION =========================================================
#
#       USAGE: insert_flacdata HANDLE PATHNAME ID
#
# DESCRIPTION: Collect metadata related to the flac file pointed by
#              PATHNAME and insert it in all the related tables in the
#              database.
#
#  PARAMETERS: HANDLE    A connection to a database.
#              PATHNAME  A unix filesystem formatted string. 
#              ID        A number value related to the id column of the
#                        database's file table.
insert_flacdata () {
	local tsamples=\"$(metaflac --show-total-samples $2)\"
	local sample_rate=\"$(metaflac --show-sample-rate $2)\"
	local channels=\"$(metaflac --show-channels $2)\"
	local bps=\"$(metaflac --show-bps $2)\"
	local md5=\"$(metaflac --show-md5sum $2)\"
	shsql $1 $(printf 'INSERT INTO flac_streaminfo (file_id, 
		total_samples, sample_rate, channels, bits_per_sample, 
		MD5_signature) VALUES (%b, %b, %b, %b, %b, %b);' $3 \
		"$tsamples" "$sample_rate" "$channels" "$bps" "$md5")
	[[ $? -ne 0 ]] && return 1
	local title="$(metaflac --show-tag=title $2)"
	title="${title##[Tt][Ii][Tt][Ll][Ee]=}"
	escape_chars title "$title"
	title=${title:-NULL} && [[ $title != NULL ]] && \
		title="\"$title\""
	local artist="$(metaflac --show-tag=artist $2)"
	artist="${artist##[Aa][Rr][Tt][Ii][Ss][Tt]=}"
	escape_chars artist "$artist"
	artist=${artist:-NULL} && [[ $artist != NULL ]] && \
		artist="\"$artist\""
	local artistsort="$(metaflac --show-tag=artistsort $2)"
	artistsort="${artistsort##[Aa][Rr][Tt[Ii][Ss][Tt][Ss][Oo][Rr][Tt]=}"
	escape_chars artistsort "$artistsort"
	artistsort=${artistsort:-NULL} && [[ $artistsort != NULL ]] && \
		artistsort="\"$artistsort\""
	local album="$(metaflac --show-tag=album $2)"
	album="${album##[Aa][Ll][Bb][Uu][Mm]=}"
	escape_chars album "$album"
	album=${album:-NULL} && [[ $album != NULL ]] && \
		album="\"$album\""
	local tracknumber="$(metaflac --show-tag=tracknumber $2)"
	tracknumber="${tracknumber##[Tt][Rr][Aa][Cc][Kk][Nn][Uu][Mm][Bb][Ee][Rr]=}"
	tracknumber=${tracknumber:-NULL} && [[ $tracknumber != NULL ]] && \
		tracknumber="\"$tracknumber\""
	local totaltracks="$(metaflac --show-tag=totaltracks $2)"
	totaltracks="${totaltracks##[Tt][Oo][Tt][Aa][Ll][Tt][Rr][Aa][Cc][Kk][Ss]=}"
	totaltracks=${totaltracks:-NULL} && [[ $totaltracks != NULL ]] && \
		totaltracks="\"$totaltracks\""
	shsql $1 $(printf 'INSERT INTO flac_comments (file_id, title, 
		artist, artistsort, album, tracknumber, totaltracks) 
		VALUES (%b, %b, %b, %b, %b, %b, %b);' $3 "$title" \
		"$artist" "$artistsort" "$album" "$tracknumber" \
		"$totaltracks")
	[[ $? -ne 0 ]] && return 1
	local mbrz_albumid="$(metaflac --show-tag=musicbrainz_albumid $2)"
	mbrz_albumid="${mbrz_albumid##musicbrainz_albumid=}"
	mbrz_albumid=${mbrz_albumid:-NULL} && [[ $mbrz_albumid != NULL ]] \
	       	&& mbrz_albumid="\"$mbrz_albumid\""
	local mbrz_artistid="$(metaflac --show-tag=musicbrainz_artistid $2)"
	mbrz_artistid="${mbrz_artistid##musicbrainz_artistid=}"
	mbrz_artistid=${mbrz_artistid:-NULL} && [[ $mbrz_artistid != NULL ]] \
	       	&& mbrz_artistid="\"$mbrz_artistid\""
	local mbrz_albartid="$(metaflac --show-tag=musicbrainz_albumartistid $2)"
	mbrz_albartid="${mbrz_albartid##musicbrainz_albumartistid=}"
	mbrz_albartid=${mbrz_albartid:-NULL} && [[ $mbrz_albartid != NULL ]] \
	       	&& mbrz_albartid="\"$mbrz_albartid\""
	local mbrz_trackid="$(metaflac --show-tag=musicbrainz_trackid $2)"
	mbrz_trackid="${mbrz_trackid##musicbrainz_trackid=}"
	mbrz_trackid=${mbrz_trackid:-NULL} && [[ $mbrz_trackid != NULL ]] \
	       	&& mbrz_trackid="\"$mbrz_trackid\""
	shsql $1 $(printf 'INSERT INTO musicbrainz_ids (file_id, 
		albumid, artistid, albumartistid, trackid) VALUES (%b, 
		%b, %b, %b, %b);' $3 "$mbrz_albumid" "$mbrz_artistid" \
		"$mbrz_albartid" "$mbrz_trackid")
	[[ $? -ne 0 ]] && return 1
	return 0
}

#===  FUNCTION =========================================================
#
#       USAGE: update_flacdata HANDLE PATHNAME ID
#
# DESCRIPTION: Collect metadata related to the flac file pointed by
#              PATHNAME and update it in all the related tables in the
#              database.
#
#  PARAMETERS: HANDLE    A connection to a database.
#              PATHNAME  A unix filesystem formatted string. 
#              ID        A number value related to the id column of the
#                        database's file table.
update_flacdata () {
	local tsamples="\"$(metaflac --show-total-samples $2)\""
	local sample_rate="\"$(metaflac --show-sample-rate $2)\""
	local channels="\"$(metaflac --show-channels $2)\""
	local bps="\"$(metaflac --show-bps $2)\""
	local md5="\"$(metaflac --show-md5sum $2)\""
	shsql $1 $(printf 'UPDATE flac_streaminfo SET
		total_samples=%b, sample_rate=%b, channels=%b,
		bits_per_sample=%b, MD5_signature=%b WHERE file_id=%b;'\
		"$tsamples" "$sample_rate" "$channels" "$bps" "$md5" $3)
	[[ $? -ne 0 ]] && return 1
	local title="$(metaflac --show-tag=title $2)"
	title="${title##[Tt][Ii][Tt][Ll][Ee]=}"
	escape_chars title "$title"
	title=${title:-NULL} && [[ $title != NULL ]] && \
		title="\"$title\""
	local artist="$(metaflac --show-tag=artist $2)"
	artist="${artist##[Aa][Rr][Tt][Ii][Ss][Tt]=}"
	escape_chars artist "$artist"
	artist=${artist:-NULL} && [[ $artist != NULL ]] && \
		artist="\"$artist\""
	local artistsort="$(metaflac --show-tag=artistsort $2)"
	artistsort="${artistsort##[Aa][Rr][Tt[Ii][Ss][Tt][Ss][Oo][Rr][Tt]=}"
	escape_chars artistsort "$artistsort"
	artistsort=${artistsort:-NULL} && [[ $artistsort != NULL ]] && \
		artistsort="\"$artistsort\""
	local album="$(metaflac --show-tag=album $2)"
	album="${album##[Aa][Ll][Bb][Uu][Mm]=}"
	escape_chars album "$album"
	album=${album:-NULL} && [[ $album != NULL ]] && \
		album="\"$album\""
	local tracknumber="$(metaflac --show-tag=tracknumber $2)"
	tracknumber="${tracknumber##[Tt][Rr][Aa][Cc][Kk][Nn][Uu][Mm][Bb][Ee][Rr]=}"
	tracknumber=${tracknumber:-NULL} && [[ $tracknumber != NULL ]] && \
		tracknumber="\"$tracknumber\""
	local totaltracks="$(metaflac --show-tag=totaltracks $2)"
	totaltracks="${totaltracks##[Tt][Oo][Tt][Aa][Ll][Tt][Rr][Aa][Cc][Kk][Ss]=}"
	totaltracks=${totaltracks:-NULL} && [[ $totaltracks != NULL ]] && \
		totaltracks="\"$totaltracks\""
	shsql $1 $(printf 'UPDATE flac_comments SET title=%b, 
		artist=%b, artistsort=%b, album=%b, tracknumber=%b, 
		totaltracks=%b WHERE file_id=%b ;' "$title" "$artist" \
		"$artistsort" "$album" "$tracknumber" "$totaltracks" $3)
	[[ $? -ne 0 ]] && return 1
	local mbrz_albumid="$(metaflac --show-tag=musicbrainz_albumid $2)"
	mbrz_albumid="${mbrz_albumid##musicbrainz_albumid=}"
	mbrz_albumid=${mbrz_albumid:-NULL} && [[ $mbrz_albumid != NULL ]] \
	       	&& mbrz_albumid="\"$mbrz_albumid\""
	local mbrz_artistid="$(metaflac --show-tag=musicbrainz_artistid $2)"
	mbrz_artistid="${mbrz_artistid##musicbrainz_artistid=}"
	mbrz_artistid=${mbrz_artistid:-NULL} && [[ $mbrz_artistid != NULL ]] \
	       	&& mbrz_artistid="\"$mbrz_artistid\""
	local mbrz_albartid="$(metaflac --show-tag=musicbrainz_albumartistid $2)"
	mbrz_albartid="${mbrz_albartid##musicbrainz_albumartistid=}"
	mbrz_albartid=${mbrz_albartid:-NULL} && [[ $mbrz_albartid != NULL ]] \
	       	&& mbrz_albartid="\"$mbrz_albartid\""
	local mbrz_trackid="$(metaflac --show-tag=musicbrainz_trackid $2)"
	mbrz_trackid="${mbrz_trackid##musicbrainz_trackid=}"
	mbrz_trackid=${mbrz_trackid:-NULL} && [[ $mbrz_trackid != NULL ]] \
	       	&& mbrz_trackid="\"$mbrz_trackid\""
	shsql $1 $(printf 'UPDATE musicbrainz_ids SET albumid=%b, 
		artistid=%b, albumartistid=%b, trackid=%b WHERE 
		file_id=%b ;' "$mbrz_albumid" "$mbrz_artistid" \
		"$mbrz_albartid" "$mbrz_trackid" $3)
	[[ $? -ne 0 ]] && return 1
	return 0
}
