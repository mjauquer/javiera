#! /bin/bash

# javiera-core.bash <Core functions of the javiera.bash script.>
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
# REQUIREMENTS: upvars.bash, filetype.flib
#         BUGS: --
#        NOTES: Any suggestion is welcomed at auq..r@gmail.com (fill in
#               the dots).

source ~/projects/javiera/submodules/upvars/upvars.bash || exit 1
source ~/projects/javiera/shell-scripts/functions/javiera-archive.bash || exit 1
source ~/projects/javiera/shell-scripts/functions/javiera-audio.bash || exit 1
source ~/projects/javiera/shell-scripts/functions/javiera-binary.bash || exit 1

declare -a file_systems # An array with the uuid fingerprints that
                        # correspond to file systems that have been 
			# found during the shell script session.
declare -a mount_points # An array with the mount points that correspond
                        # to file systems that have been found during
			# the shell script session.

escape_chars () {

#       USAGE: escape_chars VARNAME STRING
#
# DESCRIPTION: Edit STRING inserting backslashes in order to escape SQL
#              special characters. Store the resulting string in
#              caller's VARNAME variable.
#
#  PARAMETERS: VARNAME The name of a caller's variable.
#              STRING  The string to be edited.

	local string="$2"
	string=${string//\"/\\\"}
	string=${string//\'/\\\'}
	local $1 && upvar $1 "$string"
}

get_file_system_location () {

#       USAGE: get_file_system_location FS PATH PATHNAME
#
# DESCRIPTION: Use the 'file_systems' and 'mount_points' arrays in order
#              to get the file system and relative pathname of the file
#              pointed by PATHNAME. Store the resulting file system
#              fingerprint in FS and the relative pathname in PATH.
#
#  PARAMETERS: FS       The name of a variable declared in the caller's
#                       scope.
#              PATH     The name of a variable declared in the caller's
#                       scope.
#              PATHNAME The pathname of the file it is being query
#                       about.

	local fs_uuid
	local pname
	local mpoint
	local -i max_length

	for (( i=0; i<${#mount_points[@]}; i++ ))
	do
		if [[ $3 =~ ${mount_points[i]}.* ]] && 
			[[ ${#mount_points[i]} -gt $max_length ]]
		then
			mpoint=${mount_points[i]}
			max_length=${#mount_points[i]}
			fs_uuid=${file_systems[i]}
		fi
	done
	if [[ $mpoint == / ]]
	then
		pname=$3
	else
		pname=${3#${mpoint}}
	fi
	local $1 $2 && upvars -v $1 "$fs_uuid" -v $2 "$pname"
}

process_file () {

#       USAGE: process_file HOSTNAME PATHNAME QUERY_FILE
#
# DESCRIPTION: Collect metadata related to the file located in HOSTNAME
#              pointed by PATHNAME and call the pertinent procedures in
#              the database.
#
#  PARAMETERS: HOSTNAME    The name of the host machine where the file
#                          it is being query about is stored. 
#              PATHNAME    The pathname of the file it is being query
#                          about.
#              QUERY_FILE  The pathname of the file into which append
#                          the sql query.

	# Test if file's metadata is already in the database.

	local sha1; sha1=$(sha1sum $2)
	[[ $? -ne 0 ]] && return 1
	sha1=$(echo $sha1 | cut -c1-40); sha1=\'$sha1\'

	local file_id=$($mysql_path --skip-reconnect -u$user -p$pass \
		-D$db --skip-column-names -e "

		SELECT id FROM file WHERE sha1 = $sha1;

	")
	[[ $? -ne 0 ]] && return 1

	[ $file_id ] && return 0

	# Get the uuid of the file system where the file beeing
	# processed is located, and the pathname of the file relative to
	# that file system.

	local file_sys # The uuid fingerprint of the file system where
	               # the file pointed by PATHNAME is located.             
	local pathname # The pathname of the file pointed by PATHNAME
	               # relative to the mount point of the file system
		       # where it is located.

	get_file_system_location file_sys pathname $2
	[[ $? -ne 0 ]] && return 1

	file_sys=\'$file_sys\'
	pathname=\'$pathname\'

	# Get the other needed data about the file.

	local mime_type; mime_type=$(file -b --mime-type $2)
	[[ $? -ne 0 ]] && return 1
	mime_type=\'$mime_type\'

	local fsize; fsize=$(stat --format='%s' $2)
	[[ $? -ne 0 ]] && return 1
	fsize=\'$fsize\'

	local mtime; mtime=$(stat --format='%Y' $2)
	[[ $? -ne 0 ]] && return 1
	mtime=\'$mtime\'

	# Insert file's metadata in the database.

	printf "CALL insert_and_get_file (%b, %b, %b, %b, %b, %b, @file_id);\n" $file_sys $pathname $mime_type $sha1 $fsize $mtime >> $3

	# Look at the mime-type of the file whose metadata is going to
	# be inserted in order to determine which function has to be
	# called.

	local -a file_type

	file_type=( $($mysql_path --skip-reconnect -u$user -p$pass -D$db \
		--skip-column-names -e "

		START TRANSACTION;
		CALL select_ancestor (
			'file type hierarchy',
			'regular',
			$mime_type
		);
		COMMIT;

	") )
	[[ $? -ne 0 ]] && return 1

	case ${file_type[-1]} in
		audio)   ! insert_audio_file $2 $3 && return 1
			 ;;
		archive) ! insert_archive_file $3 && return 1
			 ;;
		binary)  ! insert_binary_file $2 $3 && return 1
 
	esac

	return 0
}

process_fstab () {

#       USAGE: process_fstab
#
# DESCRIPTION: Parse file systems' data and insert it in the database.

	# Get uuids related to hard disk partitions from /etc/fstab.

	while read line
	do
		local fields=( $line )
		if [[ ${fields[0]} =~ UUID=.* ]]
		then
			local field0=${fields[0]}
			local fs_uuid=${field0#UUID=}
			file_systems+=( $fs_uuid )

			local device_name; device_name=$(blkid -U $fs_uuid)
			[[ $? -ne 0 ]] && return 1

			mount_points+=( ${fields[1]} )
		fi
	done < /etc/fstab

	# Mount any digital media and get uuid data from there.

	local -a media # The mount points where digital media devices
	               # are expected to be mounted.
	local mounted  # "true" is the dvd device is mounted.

	media=( "/mnt/dvd/0" "/mnt/dvd/1" )
	for dev in ${media[@]}
	do

		# XXX Skip mounting /mnt/dvd if there is no dvd in the
		# drive.

		if [[ $dev == /mnt/dvd/0 ]]
		then
			if [[ -b /dev/sr0 ]]
			then
				if cdrecord -V -inq dev=/dev/sr0 2>&1 | grep -q "medium not present"
				then
					continue
				fi
			else
				continue
			fi
		fi

		if [[ $dev == /mnt/dvd/1 ]]
		then
			if [[ -b /dev/sr1 ]]
			then
				if cdrecord -V -inq dev=/dev/sr1 2>&1 | grep -q "medium not present"
				then
					continue
				fi
			else
				continue
			fi
		fi

		# Mount media if it is not already mounted.

		( mount | grep "on $dev type" > /dev/null ) && mounted=true
		if [[ $mounted != true ]] && ! sudo mount $dev 2> /dev/null
		then
			echo ""
			echo "Could not mount $dev." 
			echo "Should I:"
			echo " 	c) continue?"
			echo " 	e) exit?"
			echo "  r) retry?"
			echo -n "> "
			while [[ $mounted != true ]] && read answer
			do
				echo ""
				case $answer in
					n) exit
					   ;;
					r) sudo mount $dev 2> /dev/null
					   if ( mount | grep "on $dev type" > /dev/null )
					   then
					   	mounted=true
					   else
						echo ""
					   	echo "Could not mount $dev."
						echo "Should I:"
						echo " 	c) continue?"
						echo "  e) exit?"
						echo "  r) retry?"
						echo -n "> "
					   fi
					   ;;
					c) break
					   ;;
					*) echo -n "> "
					   continue
					   ;;
				esac
			done
		fi

		# Get data.

		if [[ -f $dev/.javiera/info.txt ]]
		then
			while read line
			do
				if [[ $line =~ UUID=.* ]]
				then
					file_systems+=( ${line#UUID=} )
					mount_points+=( $dev )
				fi
			done < $dev/.javiera/info.txt
		fi
		mounted=false
	done

	# Insert any new file system or mount point in the db.

	local hostname=$(hostname); hostname=\'$hostname\'

	for (( i=0; i<${#file_systems[@]}; i++ ))
	do
		local file_system=${file_systems[i]}
		file_system=\'$file_system\'
		local mount_point=${mount_points[i]}
		mount_point=\'$mount_point\'
		$mysql_path --skip-reconnect -u$user -p$pass -D$db \
			--skip-column-names -e "

			START TRANSACTION;
			CALL insert_file_system (
				$file_system
			);
			CALL insert_mount_point (
				$hostname,
				$mount_point,
				$file_system
			);
			COMMIT;

		"
		[[ $? -ne 0 ]] && return 1
	done

	return 0
}
