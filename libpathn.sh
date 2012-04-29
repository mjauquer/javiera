#!/bin/bash

source ~/code/bash/lib-pathn/upvars.sh

#===  FUNCTION =========================================================
#
#        NAME: is_ancestor
#
#       USAGE: is_ancestor PATHNAME1 PATHNAME2
#
# DESCRIPTION: Consider PATHNAME1 and PATHNAME2 as the root directories
#              of two unix filesystem hierararchy trees, T1 and T2.
#              Return 0 if T2 is a subtree of T1.
#
#  PARAMETERS: PATHNAME1 (A string representing a unix pathname).
#              PATHNAME2 (A string representing a unix pathname).
#
#=======================================================================
is_ancestor () {
	OLD_IFS=$IFS
	IFS="$(printf '\n\t')"
	{
		[[ "$#" -ne 2 ]] && cat <<- EOF
		Error: function is_ancestor requires two arguments.
		EOF
	} && exit 1
	local pathname1="$(readlink -f "$1")"
	local pathname2="$(readlink -f "$2")"
	([[ "$pathname2" =~ ${pathname1}/.* ]] && return 0) || return 1
	IFS=$OLD_IFS
}

#===  FUNCTION =========================================================
#
#        NAME: get_outputdir
#
#       USAGE: get_outputdir VARNAME STRING PATHNAME PATH...
#
# DESCRIPTION: If STRING has the format of a unix filesystem absolute
#              pathname, assign this string to the caller's variable
#              VARNAME. Otherwise, consider PATHNAME and PATH... as
#              being unix filesystem formated pathnames. Find out which
#              of the pathnames listed in PATH... is an ancestor of
#              PATHNAME. Build a pathname string whose prefix is the
#              founded pathname ancestor and whose suffix is STRING.
#              Assign the resulting string to the caller's variable
#              VARNAME. 
#
#  PARAMETERS: VARNAME  (A string representing a variable name inside the
#                        caller's scope).
#              STRING   (A string).
#              PATHNAME (A string representing a unix pathname).
#              PATH...  (A listing of unix filesystem formated
#                        pathnames).
#
#=======================================================================
get_outputdir () {
	{
		[[ "$#" -lt 4 ]] && cat <<- EOF
		Error: function get_outputdir requires at least four arguments.
		EOF
	} && exit 1
	local output_dir="$1"
	local output_opt="$2"
	local pathname="$3"
	shift 3
	[[ "$output_opt" =~ /.* ]] && local output=$output_opt
	[[ ! "$output_opt" =~ /.* ]] && 
		for path in "$@"; do
			if is_ancestor "$path" "$pathname"; then
				output="$path"/"$output_opt"
				break
			fi
		done
	local $output_dir && upvar $output_dir "$output"
}

#===  FUNCTION =========================================================
#
#        NAME: get_parentmatcher
#
#       USAGE: get_parentmatcher VARNAME PATHNAME
#
# DESCRIPTION: Consider PATHNAME as a string representing a unix
#              filesystem pathname. Build a matching pattern just as in
#              pathname expansion which matches the pathname of
#              PATHNAME's parent directory. Assign the resulting pattern
#              to the caller's variable VARNAME.
#
#  PARAMETERS: VARNAME  (A string representing a variable name inside the
#                        caller's scope).
#              PATHNAME (A string representing a unix pathname).
#
#=======================================================================
get_parentmatcher () {
	{
		[[ "$#" -ne 2 ]] && cat <<- EOF
		Error: function get_parentmatcher requires one argument.
		EOF
	} && exit 1
	local parent_matcher=
	local file="$2"
	slashes="${file//[^\/]}"
	depth=${#slashes}	
	
	#--------------------------------------------------------------
	# Check for error in pathname (all slashes?)
	#--------------------------------------------------------------

	if [ ${#file} -eq ${#slashes} ]; then
		echo "Error: file $file skipped." 2>&1
		parent_matcher=
		continue
	fi
	
	#--------------------------------------------------------------
	# Build the pattern matcher.
	#--------------------------------------------------------------

	# Is an absolute path?
	if [[ $file =~ ^/.* ]]
	then
		parent_matcher="/"
		depth=$(($depth-1))
		subdir_matcher="[^/]*/"
		while [ $depth -ne 0 ]; do
			parent_matcher="$parent_matcher$subdir_matcher"
			depth=$(($depth-1))
		done
		local $1 && upvar $1 $parent_matcher
	else
		subdir_matcher="[^/]*/"
		while [ $depth -ne 0 ]; do
			parent_matcher="$parent_matcher$subdir_matcher"
			depth=$(($depth-1))
		done
		local $1 && upvar $1 $parent_matcher
	fi
}

#===  FUNCTION =========================================================
#
#        NAME: rm_subtrees
#
#       USAGE: rm_subtrees VARNAME PATH...
#
# DESCRIPTION: Consider PATH... as a list of unix filesystem pathnames.
#              Delete from PATH... every pathname which has an ancestor
#              pathname in that list. Store the resulting list in an
#              array pointed by the caller's VARNAME variable.
#
#  PARAMETERS: VARNAME (A string representing a variable name inside the
#                       caller's scope).
#              PATH... (A list of strings representing unix filesystem
#                       pathnames).
#
#=======================================================================
rm_subtrees () {
	OLD_IFS=$IFS
	IFS="$(printf '\n\t')"
	{
		[[ "$#" -lt 3 ]] && cat <<- EOF
		Error: function rm_substrees requires three or more \
arguments.
		EOF
	} && exit 1
	local varname=$1 && shift 1
	paths=($@)
	for (( f=0 ; f < ${#paths[*]}; f++ )); do
		[ ! paths[f] ] && continue
		for (( g=f+1 ; g < ${#paths[*]}; g++ )); do
			[ ! paths[g] ] && continue
			if [ ${#paths[f]} -le ${#paths[g]} ]; then
				if is_ancestor ${paths[f]} ${paths[g]}
				then
					unset paths[$g]
				fi
			else
				if is_ancestor ${paths[g]} ${paths[f]}
				then
					unset paths[$f]
				fi
			fi
		done
	done
	upvar $varname "${paths[@]}"
	IFS=$OLD_IFS
}
