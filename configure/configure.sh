#! /bin/bash

###
#
# tools-for-g16.bash -- 
#   A collection of tools for the help with Gaussian 16.
# Copyright (C) 2019 Martin C Schwarzer
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
# along with this program.  If not, see <https://www.gnu.org/licenses/>.
#
# Please see the license file distributed alongside this repository,
# which is available when you type 'g16.tools-info.sh -L',
# or at <https://github.com/polyluxus/tools-for-g16.bash>.
#
###

# This script is only meant to configure tools-for-g16.bash

#
# Generic functions to find the scripts 
# (Copy of ./resources/locations.sh)
#
# Let's know where the script is and how it is actually called
#

get_absolute_location ()
{
    # Resolves the absolute location of parameter and returns it
    # Taken from https://stackoverflow.com/a/246128/3180795
    local resolve_file="$1" description="$2" 
    local link_target directory_name filename resolve_dir_name 
    debug "Getting directory for '$resolve_file'."
    #  resolve $resolve_file until it is no longer a symlink
    while [[ -h "$resolve_file" ]]; do 
      link_target="$(readlink "$resolve_file")"
      if [[ $link_target == /* ]]; then
        debug "File '$resolve_file' is an absolute symlink to '$link_target'"
        resolve_file="$link_target"
      else
        directory_name="$(dirname "$resolve_file")" 
        debug "File '$resolve_file' is a relative symlink to '$link_target' (relative to '$directory_name')"
        #  If $resolve_file was a relative symlink, we need to resolve 
        #+ it relative to the path where the symlink file was located
        resolve_file="$directory_name/$link_target"
      fi
    done
    debug "File is '$resolve_file'" 
    filename="$(basename "$resolve_file")"
    debug "File name is '$filename'"
    resolve_dir_name="$(dirname "$resolve_file")"
    directory_name="$(cd -P "$(dirname "$resolve_file")" && pwd)"
    if [[ "$directory_name" != "$resolve_dir_name" ]]; then
      debug "$description '$directory_name' resolves to '$directory_name'."
    fi
    debug "$description is '$directory_name'"
    if [[ -z $directory_name ]] ; then
      directory_name="."
    fi
    echo "$directory_name/$filename"
}

get_absolute_filename ()
{
    # Returns only the filename
    local resolve_file="$1" description="$2" return_filename
    return_filename=$(get_absolute_location "$resolve_file" "$description")
    return_filename=${return_filename##*/}
    echo "$return_filename"
}

get_absolute_dirname ()
{
    # Returns only the directory
    local resolve_file="$1" description="$2" return_dirname
    return_dirname=$(get_absolute_location "$resolve_file" "$description")
    return_dirname=${return_dirname%/*}
    echo "$return_dirname"
}

get_scriptpath_and_source_files ()
{
    local error_count tmplog line 
    tmplog=$(mktemp tmp.XXXXXXXX) 
    # Who are we and where are we?
    scriptname="$(get_absolute_filename "${BASH_SOURCE[0]}" "installname")"
    debug "Script is called '$scriptname'"
    # remove scripting ending (if present)
    scriptbasename=${scriptname%.sh} 
    debug "Base name of the script is '$scriptbasename'"
    # We are in another subdirectory
    scriptpath="$(get_absolute_dirname  "${BASH_SOURCE[0]}" "current installdirectory")"
    # move one up
    debug "Script is located in '$scriptpath'"
    resourcespath="$scriptpath/../resources"
    
    if [[ -d "$resourcespath" ]] ; then
      debug "Found library in '$resourcespath'."
    else
      (( error_count++ ))
    fi
    
    # Import default variables
    #shellcheck source=../resources/default_variables.sh
    source "$resourcespath/default_variables.sh" &> "$tmplog" || (( error_count++ ))
    
    # Import other functions
    #shellcheck source=../resources/messaging.sh
    source "$resourcespath/messaging.sh" &> "$tmplog" || (( error_count++ ))
    #shellcheck source=../resources/rcfiles.sh
    source "$resourcespath/rcfiles.sh" &> "$tmplog" || (( error_count++ ))
    #shellcheck source=../resources/test_files.sh
    source "$resourcespath/test_files.sh" &> "$tmplog" || (( error_count++ ))
    #shellcheck source=../resources/process_gaussian.sh
    source "$resourcespath/process_gaussian.sh" &> "$tmplog" || (( error_count++ ))
    #shellcheck source=../resources/validate_numbers.sh
    source "$resourcespath/validate_numbers.sh" &> "$tmplog" || (( error_count++ ))

    if (( error_count > 0 )) ; then
      echo "ERROR: Unable to locate library functions. Check installation." >&2
      echo "ERROR: Expect functions in '$resourcespath'."
      debug "Errors caused by:"
      while read -r line || [[ -n "$line" ]] ; do
        debug "$line"
      done < "$tmplog"
      debug "$(rm -v -- "$tmplog")"
      exit 1
    else
      debug "$(rm -v -- "$tmplog")"
    fi
}

#
# Specific functions for this script only
#

expand_tilde ()
{
  local expand_string="$1" return_string
  # Tilde does not expand like a variable, this might lead to files not being found
  # The regex is trying to exclude special meanings of '~+' and '~-'
  if [[ $expand_string =~ ^~([^/+-]*)/(.*)$ ]] ; then
    debug "Expandinging tilde, match: ${BASH_REMATCH[0]}"
    if [[ -z ${BASH_REMATCH[1]} ]] ; then
      # If the tilde is followed by a slash it expands to the users home
      return_string="$HOME/${BASH_REMATCH[2]}"
    else
      # If the tilde is followed by a string, it expands to another user's home
      return_string="/home/${BASH_REMATCH[1]}/${BASH_REMATCH[2]}"
    fi
    debug "Expanded tilde for '$return_string'."
  else
    return_string="$expand_string"
  fi
  echo "$return_string"
}

expand_tilde_in_path ()
{
  local test_PATH="$1" test_element return_PATH
  local -a test_PATH_elements return_PATH_elements

  IFS=':' read -r -a test_PATH_elements <<< "$test_PATH"
  for test_element in "${test_PATH_elements[@]}" ; do
    test_element=$(expand_tilde "$test_element")
    return_PATH_elements+=( "$test_element" )
  done
  printf -v return_PATH '%s:' "${return_PATH_elements[@]}"
  echo "${return_PATH%:}"
}
  
check_exist_executable ()
{
  local resolve_file="$1"
  if [[ -e "$resolve_file" && -x "$resolve_file" ]] ; then
    debug "Found file and is executable."
  else
    warning "File '$resolve_file' does not exist or is not executable."
    return 1
  fi
}

check_exist_directory ()
{
  local resolve_dir="$1"
  if [[ -e "$resolve_dir" && -d "$resolve_dir" ]] ; then
    debug "Found directory."
  else
    warning "File '$resolve_dir' does not exist or is not a directory."
    return 1
  fi
}

#
# Input functions
#

# Additional function only necessary for configure
ask ()
{
    echo    "QUESTION: $*" >&3
}

read_human_input ()
{
  debug "Reading human input."
  message "Enter '0' to skip or exit this section."
  local readvar
  while [[ -z $readvar ]] ; do
    echo -n "ANSWER  : " >&3
    read -r readvar
    [[ "$readvar" == 0 ]] && unset readvar && break 
  done
  debug "readvar=$readvar"
  echo "$readvar"
}

read_email ()
{
  debug "Reading email address."
  local verified_email
  until is_email "$verified_email" ; do
    verified_email=$(read_human_input)
    [[ -z $verified_email ]] && unset verified_email && break
  done
  debug "verified_email=$verified_email"
  echo "$verified_email"
}

read_boolean ()
{
  debug "Reading boolean."
  local readvar pattern_true_false pattern_yes_no pattern
  pattern_true_false="[Tt]([Rr]([Uu][Ee]?)?)?|[Ff]([Aa]([Ll]([Ss][Ee]?)?)?)?"
  pattern_yes_no="[Yy]([Ee][Ss]?)?|[Nn][Oo]?"
  pattern="($pattern_true_false|$pattern_yes_no|0|1)"
  until [[ $readvar =~ ^[[:space:]]*${pattern}[[:space:]]*$ ]] ; do
    message "Please enter t(rue)/y(es)/1 or f(alse)/n(o)/0."
    echo -n "ANSWER  : " >&3
    read -r readvar
  done
  debug "Found match '${BASH_REMATCH[0]}'"
  case ${BASH_REMATCH[0]} in
    [Tt]* | [Yy]* | 1) return 0 ;;
    [Ff]* | [Nn]* | 0) return 1 ;;
  esac
}

read_true_false ()
{
  if read_boolean ; then
    echo "true"
  else
    echo "false"
    return 1
  fi
}

read_yes_no ()
{
  if read_boolean ; then
    echo "yes"
  else
    echo "no"
    return 1
  fi
}

read_integer ()
{
  debug "Reading integer."
  local readvar
  until [[ $readvar =~ ^[[:space:]]*([[:digit:]]+)[[:space:]]*$ ]] ; do
    message "Please enter an integer value."
    echo -n "ANSWER  : " >&3
    read -r readvar
  done
  debug "Whole match is |${BASH_REMATCH[0]}|; Numeric is |${BASH_REMATCH[1]}|"
  readvar="${BASH_REMATCH[1]}"
  debug "readvar=$readvar"
  echo "$readvar"
}

# 
# Single queries
#

ask_installation_path ()
{
  ask "Where is the Gaussian directory? Please specify the full path."
  use_g16_installpath=$(read_human_input)
  # Will be empty if skipped; can return without assigning/testing empty values
  [[ -z $use_g16_installpath ]] && return
  use_g16_installpath=$(expand_tilde "$use_g16_installpath")
  if check_exist_directory "$use_g16_installpath" ; then
    use_g16_installpath=$(get_absolute_dirname "$use_g16_installpath" "Gaussian 16")
  else
    warning "Problem locating Gaussian directory, unsetting variable."
    unset use_g16_installpath
  fi
  debug "use_g16_installpath=$use_g16_installpath"
}

ask_gaussian_scratch ()
{
  ask "Where shall temporary files be stored?"
  message "This may be any directory, such as locally '~/scratch', or globally '/scratch', etc.."
  message "The default of this script will write a 'mktemp' statement to the submitfile," 
  message "which creates a temporary directory at runtime (based on \$TEMPDIR."
  message "Valid values for this: T(E)MP(DIR) [case insensitive], default, 0, (empty)"
  message "If no pattern is matched, the value will be taken as a directory."
  message "No sanity check of the input will be performed."
  use_g16_scratch=$(read_human_input)
  # Will be empty if skipped; can return without assigning/testing empty values
  [[ -z $use_g16_scratch ]] && return
  debug "use_g16_scratch=$use_g16_scratch"
}

ask_gaussian_overhead ()
{
  ask "How much overhead (in MB) shall Gaussian use?"
  message "Some additional overhead will be provided by the scripts in any case."
  use_g16_overhead=$(read_integer)
  debug "use_g16_overhead=$use_g16_overhead"
}

ask_gaussian_checkpoint_save ()
{
  ask "Should Gaussian checkpoint files be saved by default?"
  use_g16_scheckpoint_save=$(read_yes_no)
  debug "use_g16_scheckpoint_save=$use_g16_scheckpoint_save"
}

ask_load_modules ()
{
  ask "If a modular software management is available, would you like to use it?"
  use_load_modules=$(read_true_false)
  debug "use_load_modules=$use_load_modules"
  if [[ "$use_load_modules" =~ ^[Tt]([Rr]([Uu]([Ee])?)?)?$ ]] ; then
    if ( command -v module &> /dev/null ) ; then
      debug "Command 'module' is available."
      (( ${#use_g16_modules[@]} > 0 )) && warning "Read modules have been reset, please enter all of them again."
      unset use_g16_modules
      local module_index=0
      while [[ -z ${use_g16_modules[$module_index]} ]] ; do
        debug "Reading use_g16_modules[$module_index]"
        ask "What modules do need to be loaded?"
        use_g16_modules[$module_index]=$(read_human_input)
        debug "use_g16_modules[$module_index]=${use_g16_modules[$module_index]}"
        if [[ ${use_g16_modules[$module_index]} =~ ^[[:space:]]*$ ]] ; then
          debug "Finished reading modules."
          unset 'use_g16_modules[module_index]'
          break
        fi
        (( module_index++ ))
      done
      debug "Number of elements: ${#use_g16_modules[@]}"
      if (( ${#use_g16_modules[@]} == 0 )) ; then
        warning "No modules specified."
        use_load_module="false"
        warning "Switching the use of modules off."
      fi
    else
      warning "Command 'module' not found'."
      use_load_module="false"
      warning "Switching the use of modules off."
    fi
  else
    debug "No modules used."
  fi
  debug "use_load_module=$use_load_module; use_g16_modules=( ${use_g16_modules[*]} )"
}

ask_g16_utilities ()
{
  ask "Which command shall be used as a wrapper to Gaussian commands?"
  message "This may be an executable script found in PATH, or an absolute location."
  message "If no wrapper should be used, please eneter 'none'."
  message "No sanity check of the input will be performed."
  local wrapper_found wrapper_test
  local -a wrapper_names
  wrapper_names=( "g16.wrapper.sh" "g16.wrapper" "rung16.sh" "rung16" "wrapper.g16.sh" "wrapper.g16" )
  for wrapper_test in "${wrapper_names[@]}" ; do
    debug "Checking for $wrapper_test."
    if wrapper_found=$( command -v "$wrapper_test" ) ; then
      message "Suggestion '$wrapper_found'"
      break
    else
      debug "'$wrapper_test' not found."
    fi
  done
  use_g16_wrapper_cmd=$(read_human_input)
  if [[ "$use_g16_wrapper_cmd" =~ ^[Nn]([Oo]([Nn]([Ee])?)?)?$ ]] ; then
    unset use_g16_wrapper_cmd
  fi
  debug "use_g16_wrapper_cmd=$use_g16_wrapper_cmd"

  local check_g16_formchk_cmd
  ask "Which command shall be used to execute Gaussians 'formchk' utility?"
  message "This may be the name used to call the program, be it via the previously specified wrapper,"
  message "loaded via PATH, or the absolute location of the program."
  if [[ -n $use_g16_wrapper_cmd ]] ; then
    debug "Wrapper is used."
    if check_g16_formchk_cmd="$( $use_g16_wrapper_cmd command -v formchk 2>&1 )" ; then
      message "Found command via wrapper as 'formchk'."
    else
      debug "$check_g16_formchk_cmd"
    fi
  else
    debug "Wrapper is _not_ used."
    if check_g16_formchk_cmd="$(command -v formchk)" ; then
      message "Found executable command 'formchk' as '$check_g16_formchk_cmd'."
    fi
  fi
  debug "check_g16_formchk_cmd=$check_g16_formchk_cmd"
  message "No sanity check of the input will be performed."
  message "Please do not include options, they will be specified next."
  use_g16_formchk_cmd=$(read_human_input)
  debug "use_g16_formchk_cmd=$use_g16_formchk_cmd"
  ask "What options should be used?"
  message "Leving this blank will revert to the default option '-3'."
  message "If you want to use no optinions, please enter 'none'."
  use_g16_formchk_opts=$(read_human_input)
  if [[ "$use_g16_formchk_opts" =~ ^[Nn]([Oo]([Nn]([Ee])?)?)?$ ]] ; then
    use_g16_formchk_opts=" "
  fi
  debug "use_g16_formchk_opts=$use_g16_formchk_opts"

  local check_g16_testrt_cmd
  ask "Which command shall be used to execute Gaussians 'testrt' utility?"
  message "This should be very similar to the above."
  if [[ -n $use_g16_wrapper_cmd ]] ; then
    debug "Wrapper is used."
    if check_g16_testrt_cmd="$( $use_g16_wrapper_cmd command -v testrt 2>&1 )" ; then
      message "Found command via wrapper as 'testrt'."
    fi
  else
    debug "Wrapper is _not_ used."
    if check_g16_testrt_cmd="$(command -v testrt)" ; then
      message "Found executable command 'testrt' as '$check_g16_testrt_cmd'."
    fi
  fi
  use_g16_testrt_cmd=$(read_human_input)
  debug "use_g16_testrt_cmd=$use_g16_testrt_cmd"
}

ask_other_utilities ()
{
  local check_obabel_cmd
  ask "Which command shall be used to execute Open Babel (obabel)?"
  message "This may be any string used to call the program, be it via a wrapper,"
  message "loaded via PATH, or the absolute location of the program."
  if check_obabel_cmd="$(command -v obabel)" ; then
    message "Found executable command 'obabel' as '$check_obabel_cmd'."
  fi
  use_obabel_cmd=$(read_human_input)
  debug "use_obabel_cmd=$use_obabel_cmd"
  # Maybe some more are necessary later
}

ask_g16_default_extensions ()
{
  ask "What is the default extension you use for Gaussian input files?"
  message "This should be one of the following options:"
  message "com, in, inp, gjf, COM, IN, INP, GJF"
  use_g16_input_suffix=$(read_human_input)
  ## Match it and reply
  if use_g16_output_suffix=$(match_output_suffix "$use_g16_input_suffix") ; then
    message "Matched '$use_g16_output_suffix' as output extension."
  else
    warning "Could not find matching output extension for '$use_g16_input_suffix'."
    message "Unsetting variable to fall back to default."
    unset use_g16_input_suffix use_g16_output_suffix
  fi
  debug "use_g16_input_suffix=$use_g16_input_suffix"
  debug "use_g16_output_suffix=$use_g16_output_suffix"
}

ask_g16_store_route_section ()
{
  if [[ -x "$scriptpath/routebuilder.sh" ]] ; then
    debug "Calling the route builder script."
    local tmpfile_routes_tomodify
    tmpfile_routes_tomodify="$( mktemp --tmpdir )"
    {
      local array_index=0
      for array_index in "${!use_g16_route_section_predefined[@]}" ; do
        printf '  g16_route_section_predefined[%d]="%s"\n' "$array_index" "${use_g16_route_section_predefined[$array_index]}"
        printf '  g16_route_section_predefined_comment[%d]="%s"\n' "$array_index" "${use_g16_route_section_predefined_comment[$array_index]}"
      done
    } > "$tmpfile_routes_tomodify"
    local tmpfile_routes_edited
    tmpfile_routes_edited="$( mktemp --tmpdir )"
    debug "Created temporary file: $tmpfile_routes_edited"
    local pass_on_a_message
    pass_on_a_message="Route builder was called from $scriptname, don't forget to save your edits."
    local -a routebuilder_opts
    [[ "$debugging" == "true" ]] && routebuilder_opts+=( "debug" )
    routebuilder_opts+=( '-r' "$tmpfile_routes_tomodify" '-o' "$tmpfile_routes_edited" '-m' "$pass_on_a_message" )
    debug "Calling: $scriptpath/routebuilder.sh ${routebuilder_opts[*]}"
    "$scriptpath/routebuilder.sh" "${routebuilder_opts[@]}"
    debug "Received: $( cat "$tmpfile_routes_edited" )"
    debug "Resetting routevariables."
    unset use_g16_route_section_predefined use_g16_route_section_predefined_comment
    unset     g16_route_section_predefined     g16_route_section_predefined_comment
    debug "Sourceing '$tmpfile_routes_edited'."
    #shellcheck disable=SC1090
    . "$tmpfile_routes_edited"
    debug "$( rm -v -- "$tmpfile_routes_edited" )"
    use_g16_route_section_predefined=( "${g16_route_section_predefined[@]}" )
    use_g16_route_section_predefined_comment=( "${g16_route_section_predefined_comment[@]}" )
    debug "$(declare -p use_g16_route_section_predefined)"
    debug "$(declare -p use_g16_route_section_predefined_comment)"
    local array_index=0
    for array_index in "${!use_g16_route_section_predefined[@]}" ; do
      (( array_index > 0 )) && printf '\n'
      printf '%3d       : ' "$array_index" 
      local printvar printline=0
      while read -r printvar || [[ -n "$printvar" ]] ; do
        if (( printline == 0 )) ; then
          printf '%-80s\n' "$printvar"
        else
          printf '            %-80s\n' "$printvar"
        fi
        (( printline++ ))
      done <<< "$( fold -w80 -s <<< "${use_g16_route_section_predefined[$array_index]}" )"
      unset printvar 
      while read -r printvar || [[ -n "$printvar" ]] ; do
        [[ -z "$printvar" ]] && printvar="no comment"
        printf '%3d(cmt.) : %-80s\n' "$array_index" "$printvar"
      done <<< "$( fold -w80 -s <<< "${use_g16_route_section_predefined_comment[$array_index]}" )"
    done
    (( ${#use_g16_route_section_predefined[@]} == 0 )) && return 0
    ask "Which entry would you like to set as the default?"
    local user_input
    user_input=$(read_integer)
    while (( user_input >= ${#use_g16_route_section_predefined[@]} )) ; do
      user_input=$(read_integer)
    done
    use_g16_route_section_default="${use_g16_route_section_predefined[$user_input]}"
    
    return 0
  fi
  
  debug "Calling old function."
  warning "You shouldn't actually see the following part of the script. Installation might have gone wrong."
  #  Unsetting related variables
  unset use_g16_route_section_default
  unset use_g16_route_section_predefined
  unset use_g16_route_section_predefined_comment
}

ask_stay_quiet ()
{
  ask "What level of chattyness of $softwarename would you like to set?"
  message "(0: all; 1: no info; 2: no warnings; >2: nothing)"
  message "Skipping this section will also choose '0'."
  use_stay_quiet=$(read_interger)
  [[ -z $use_stay_quiet ]] && use_stay_quiet=0
  debug "use_stay_quiet=$use_stay_quiet"
}

ask_output_verbosity ()
{
  ask "How much information should be printed by default when extracting information?"
  message "This determines the short/long output form of some scripts (currently only getfreq)."
  message "(0: least; 1: slightly more; 2: table; 3: (long) table; >3: much MORE)"
  message "Skipping this section will also choose '0'."
  use_output_verbosity=$(read_integer)
  [[ -z $use_output_verbosity ]] && use_output_verbosity=0
  debug "use_output_verbosity=$use_output_verbosity"
} 

ask_values_delimiter ()
{
  ask "For delimiter-separated values, which character  would you like to use?"
  message "Recognised arguments: space/comma/semicolon/colon/slash/pipe." 
  message "Skip this section to use the default (space)."
  use_values_delimiter=$(read_human_input)
  [[ -z $use_values_delimiter ]] &&  use_values_delimiter="space"
  debug "use_values_delimiter=$use_values_delimiter"
}

ask_qsys_details ()
{
  ask "For which queueing system are you configuring?"
  message "Currently supported: pbs-gen, slurm-gen, bsub-gen, slurm-rwth, bsub-rwth"
  local test_queue
  test_queue=$(read_human_input)
  debug "test_queue=$test_queue"
  case $test_queue in
    [Pp][Bb][Ss]* )
      use_request_qsys="pbs-gen"
      debug "use_request_qsys=$use_request_qsys"
      #skip the rest because it does not apply
      return 
      ;;
    [Bb][Ss][Uu][Bb]* )
      use_request_qsys="bsub-gen"
      ;;&
    [Bb][Ss][Uu][Bb]-[Rr][Ww][Tt][Hh] )
      use_request_qsys="bsub-rwth"
      ask "What machine type would you like to specify?"
      use_bsub_machinetype=$(read_human_input)
      [[ -z "$use_bsub_machinetype" ]] && use_bsub_machinetype="default"
      debug "use_bsub_machinetype=$use_bsub_machinetype"
      ;;
    [Ss][Ll][Uu][Rr][Mm]* )
      use_request_qsys="slurm-gen"
      ;;&
    [Ss][Ll][Uu][Rr][Mm]-[Rr][Ww][Tt][Hh] )
      use_request_qsys="slurm-rwth"
      ;;
    '' )
      : ;;
    * )
      [[ -z $use_request_qsys ]] && warning "Unrecognised queueing system ($test_queue)."
      ;;
  esac
  debug "use_request_qsys=$use_request_qsys"

  ask "What project would you like to specify?"
  use_qsys_project=$(read_human_input)
  [[ -z "$use_qsys_project" ]] && use_qsys_project="default"
  debug "use_qsys_project=$use_qsys_project"

  ask "What email address should recieve notifications?"
  use_user_email=$(read_email)
  [[ -z "$use_user_email" ]] && use_user_email="default"
  debug "use_user_email=$use_user_email"
}

ask_xmail_details ()
{
  ask "Would you like to use the extra mail interface (experimental)?"
  if use_xmail_interface=$(read_yes_no) ; then
   debug "Activating extra mail interface."
  else 
    unset use_xmail_cmd
    return 0
  fi
  debug "use_xmail_interface=$use_xmail_interface"
  debug "use_xmail_cmd=$use_xmail_cmd"
  ask "Please specify a command to use as an interface."
  local mymail_found mymail_test
  local -a mymail_names
  mymail_names=( "mymail_slurm.sh" "mymail_slurm" "mymail" "mymail.sh" )
  for mymail_test in "${mymail_names[@]}" ; do
    debug "Checking for $mymail_test."
    if mymail_found=$( command -v "$mymail_test" ) ; then
      message "Suggestion: $mymail_found"
      break
    else
      debug "'$mymail_test not found."
    fi
  done
  use_xmail_cmd=$(read_human_input)
  if [[ -z $use_xmail_cmd ]] ; then
    warning "No interface specified, turning option off."
    use_xmail_interface="disabled"
  fi
  debug "use_xmail_interface=$use_xmail_interface"
  debug "use_xmail_cmd=$use_xmail_cmd"
  ask "Would you like to also enable the standard queueing system email?"
  if use_qsys_email=$(read_yes_no) ; then
   debug "Activating standard email."
  else 
   debug "Deactivating standard email."
  fi
  debug "use_qsys_email=$use_qsys_email"
}

ask_walltime ()
{
  ask "How much walltime (in hours) do you want to use if submitted to a queueing system?"
  use_requested_walltime=$(read_integer)
  if (( use_requested_walltime == 0 )) ; then
    warning "It is no good idea to set the walltime to zero. Unsetting choice."
    unset use_requested_walltime
  else
    use_requested_walltime="$use_requested_walltime:00:00"
  fi
  debug "use_requested_walltime=$use_requested_walltime"
}

ask_memory ()
{
  ask "How much memory (in MB) do you want to use by default?"
  use_requested_memory=$(read_integer)
  if (( use_requested_memory == 0 )) ; then
    warning "It is impossible to use no memory. Unsetting choice."
    unset use_requested_memory
  fi
  debug "use_requested_memory=$use_requested_memory"
}

ask_threads ()
{
  ask "How many threads do you want to use by default?"
  use_requested_numCPU=$(read_integer)
  if (( use_requested_numCPU == 0 )) ; then
    warning "It is impossible to use no threads. Unsetting choice."
    unset use_requested_numCPU
  fi
  debug "use_requested_numCPU=$use_requested_numCPU"
}

ask_maxdisk ()
{
  ask "What value (in MB) would you like to set for the MaxDisk keyword?"
  use_requested_maxdisk=$(read_integer)
  if (( use_requested_maxdisk == 0 )) ; then
    warning "It is impossible to use no MaxDisk setting. Unsetting choice."
    unset use_requested_maxdisk
  fi
  debug "use_requested_maxdisk=$use_requested_maxdisk"
}

ask_submit_status ()
{
  ask "What should be the default operation submitting the calculations?"
  message "Accepted values: run, hold, keep"
  use_requested_submit_status=$(read_human_input)
  [[ -z $use_requested_submit_status ]] && return
  local pattern_run="[Rr][Uu][Nn]"
  local pattern_hold="[Hh][Oo][Ll][Dd]"
  local pattern_keep="[Kk][Ee][Ee][Pp]"
  if [[ $use_requested_submit_status =~ ($pattern_run|$pattern_hold|$pattern_keep) ]] ; then
    debug "Pattern matches: '$use_requested_submit_status'"
  else
    warning "Unrecognised submit status: 'use_requested_submit_status'"
    message "Unsetting choice to fall back to defaults."
    unset use_requested_submit_status
  fi
  debug "use_requested_submit_status=$use_requested_submit_status"
}


#
# Other option to read in file
#
get_configuration_from_file ()
{
  # Check for settings in four default locations (increasing priority):
  #   install path of the script, user's home directory, 'config' in user's home directory, current directory
  g16_tools_path=$(get_absolute_dirname "$scriptpath/../g16.tools.rc")
  local g16_tools_rc_searchlocations
  g16_tools_rc_searchlocations=( "$g16_tools_path" "$HOME" "$HOME/.config" "$PWD" )
  g16_tools_rc_loc="$( get_rc "${g16_tools_rc_searchlocations[@]}" )"
  debug "g16_tools_rc_loc=$g16_tools_rc_loc"
  
  # Load custom settings from the rc
  
  if [[ -n $g16_tools_rc_loc ]] ; then
    message "Configuration file '${g16_tools_rc_loc/*$HOME/<HOME>}' found."
  else
    debug "No custom settings found."
  fi
    
  if [[ "$route_mode" == "true" || "$translate_mode" == "true" ]] ; then
    debug "Route (${route_mode:-false}) / translate (${translate_mode:-false}) mode active, skipping alternative file."
  else
    ask "Would you like to specify a file to read settings from?"
    if read_boolean ; then
      ask "What file would you like to load?"
      local test_g16_tools_rc_loc
      test_g16_tools_rc_loc=$(read_human_input)
      if test_g16_tools_rc_loc=$(test_rc_file "$test_g16_tools_rc_loc") ; then
        g16_tools_rc_loc="$test_g16_tools_rc_loc"
      else
        warning "Loading configuration file '$test_g16_tools_rc_loc' failed."
        message "Continue with defaults."
      fi
    else
      debug "g16_tools_rc_loc=$g16_tools_rc_loc"
    fi
  fi

  [[ -z $g16_tools_rc_loc ]] && return 1
  #shellcheck source=../g16.tools.rc 
  . "$g16_tools_rc_loc"
  message "Configuration file '${g16_tools_rc_loc/*$HOME/<HOME>}' applied."
  # Put a warning for pre-0.3.0 versions
  if [[ "$configured_version" =~ ^0\.3\.[[:digit:]]+ ]] ; then
    debug "Configured version was $configured_version ($configured_versiondate)."
  else
    warning "Configured version was $configured_version ($configured_versiondate),"
    warning "some sttings might have changed, or newer ones have not been configured yet."
  fi
}

translate_conf_settings_to_internal ()
{
  use_g16_installpath="$g16_installpath"
  debug "use_g16_installpath=$use_g16_installpath"
  use_g16_scratch="$g16_scratch"
  debug "use_g16_scratch=$use_g16_scratch"
  use_g16_overhead="$g16_overhead"
  debug "use_g16_overhead=$use_g16_overhead"
  use_g16_checkpoint_save="$g16_checkpoint_save"
  debug "use_g16_checkpoint_save=$use_g16_checkpoint_save"
  use_load_modules="$load_modules"
  use_g16_modules=( "${g16_modules[@]}" )
  debug "use_load_modules=$use_load_modules"
  use_g16_wrapper_cmd="$g16_wrapper_cmd"
  use_g16_formchk_cmd="$g16_formchk_cmd"
  use_g16_formchk_opts="$g16_formchk_opts"
  use_g16_testrt_cmd="$g16_testrt_cmd"
  debug "use_g16_wrapper_cmd=$use_g16_wrapper_cmd"
  debug "use_g16_testrt_cmd=$use_g16_testrt_cmd"
  debug "use_g16_formchk_cmd=$use_g16_formchk_cmd"
  debug "use_g16_formchk_opts=$use_g16_formchk_opts"
  use_obabel_cmd="$obabel_cmd"
  debug "use_obabel_cmd=$use_obabel_cmd"
  use_g16_input_suffix="$g16_input_suffix"
  use_g16_output_suffix="$g16_output_suffix"
  debug "use_g16_input_suffix=$use_g16_input_suffix"
  debug "use_g16_output_suffix=$use_g16_output_suffix"
  use_g16_route_section_default="$g16_route_section_default"
  debug "g16_route_section_default=$use_g16_route_section_default"
  use_g16_route_section_predefined=( "${g16_route_section_predefined[@]}" )
  use_g16_route_section_predefined_comment=( "${g16_route_section_predefined_comment[@]}" )
  debug "$(declare -p use_g16_route_section_predefined)"
  debug "$(declare -p use_g16_route_section_predefined_comment)"
  use_stay_quiet="$stay_quiet"
  debug "use_stay_quiet=$use_stay_quiet"
  use_output_verbosity="$output_verbosity"
  debug "use_output_verbosity=$use_output_verbosity"
  # backwards compatibility
  use_values_separator="$values_separator"
  debug "use_values_separator=$use_values_separator"
  case $use_values_separator in 
    [[:space:]])
      use_values_delimiter="space"
      ;;
    ',')
      use_values_delimiter="comma"
      ;;
    ';')
      use_values_delimiter="semicolon"
      ;;
    '|')
      use_values_delimiter="pipe"
      ;;
    '/')
      use_values_delimiter="slash"
      ;;
    '')
      debug "Empty (new configuration or unset): $use_values_separator"
      ;;
    *)
      debug "Not regognised: $use_values_separator"
      ;;
  esac
  use_values_delimiter="${use_values_delimiter:-$values_delimiter}"
  debug "use_values_delimiter=$use_values_delimiter"
  use_request_qsys="$request_qsys"
  # backwards compatibility
  use_qsys_project="${qsys_project:-$bsub_project}"
  use_user_email="${user_email:-$bsub_email}"
  # Very specific constraint:
  use_bsub_machinetype="$bsub_machinetype"
  debug "use_request_qsys=$use_request_qsys"
  debug "use_qsys_project=$use_qsys_project"
  debug "use_user_email=$use_user_email"
  debug "use_bsub_machinetype=$use_bsub_machinetype"
  use_qsys_email="$use_qsys_email"
  use_xmail_interface="$xmail_interface"
  use_xmail_cmd="$xmail_cmd"
  debug "use_qsys_email=$use_qsys_email"
  debug "use_xmail_interface=$use_xmail_interface"
  debug "use_xmail_cmd=$use_xmail_cmd"
  use_requested_walltime="$requested_walltime"
  debug "use_requested_walltime=$use_requested_walltime"
  use_requested_memory="$requested_memory"
  debug "use_requested_memory=$use_requested_memory"
  use_requested_numCPU="$requested_numCPU"
  debug "use_requested_numCPU=$use_requested_numCPU"
  use_requested_maxdisk="$requested_maxdisk"
  debug "use_requested_maxdisk=$use_requested_maxdisk"
  use_requested_submit_status="$requested_submit_status"
  debug "use_requested_submit_status=$use_requested_submit_status"
}

#
# Get Information from user input
#
get_configuration_interactive ()
{
  use_g16_installpath="$g16_installpath"
  if [[ -z $use_g16_installpath ]] ; then
    ask_installation_path
  else
    message "Recovered setting: 'g16_installpath=$use_g16_installpath'"
    ask "Would you like to change this setting?"
    if read_boolean ; then ask_installation_path ; fi
  fi
  debug "use_g16_installpath=$use_g16_installpath"

  use_g16_scratch="$g16_scratch"
  if [[ -z $use_g16_scratch ]] ; then
    ask_gaussian_scratch 
  else
    message "Recovered setting: 'g16_scratch=$use_g16_scratch'"
    ask "Would you like to change this setting?"
    if read_boolean ; then ask_gaussian_scratch ; fi
  fi
  debug "use_g16_scratch=$use_g16_scratch"

  use_g16_overhead="$g16_overhead"
  if [[ -z $use_g16_overhead ]] ; then
    ask_gaussian_overhead
  else
    message "Recovered setting: 'g16_overhead=$use_g16_overhead'"
    ask "Would you like to change this setting?"
    if read_boolean ; then ask_gaussian_overhead ; fi
  fi
  debug "use_g16_overhead=$use_g16_overhead"

  use_g16_checkpoint_save="$g16_checkpoint_save"
  if [[ -z $use_g16_checkpoint_save ]] ; then
    ask_gaussian_checkpoint_save
  else
    message "Recovered setting: 'g16_checkpoint_save=$use_g16_checkpoint_save'"
    ask "Would you like to change this setting?"
    if read_boolean ; then ask_gaussian_checkpoint_save ; fi
  fi
  debug "use_g16_checkpoint_save=$use_g16_checkpoint_save"

  use_load_modules="$load_modules"
  use_g16_modules=( "${g16_modules[@]}" )
  if [[ -z $use_load_modules ]] ; then
    ask_load_modules
  else
    message "Recovered setting: 'load_modules=$use_load_modules'"
    if (( ${#use_g16_modules[@]} > 0 )) ; then
      message "Recovered setting: 'g16_modules=( ${use_g16_modules[*]} )"
    fi
    ask "Would you like to change any of these settings?"
    if read_boolean ; then ask_load_modules ; fi
  fi
  debug "use_load_modules=$use_load_modules"

  use_g16_wrapper_cmd="$use_g16_wrapper_cmd"
  use_g16_formchk_cmd="$g16_formchk_cmd"
  use_g16_formchk_opts="$g16_formchk_opts"
  use_g16_testrt_cmd="$g16_testrt_cmd"
  if [[ -z $use_g16_formchk_cmd || -z $use_g16_testrt_cmd ]] ; then
    ask_g16_utilities
  else
    message "Recovered setting: 'g16_wrapper_cmd=$use_g16_wrapper_cmd'"
    message "Recovered setting: 'g16_testrt_cmd=$use_g16_testrt_cmd'"
    message "Recovered setting: 'g16_formchk_cmd=$use_g16_formchk_cmd'"
    message "Recovered setting: 'g16_formchk_opts=$use_g16_formchk_opts'"
    ask "Would you like to change these settings?"
    if read_boolean ; then ask_g16_utilities ; fi
  fi
  debug "use_g16_wrapper_cmd=$use_g16_wrapper_cmd"
  debug "use_g16_testrt_cmd=$use_g16_testrt_cmd"
  debug "use_g16_formchk_cmd=$use_g16_formchk_cmd"
  debug "use_g16_formchk_opts=$use_g16_formchk_opts"

  use_obabel_cmd="$obabel_cmd"
  if [[ -z $use_obabel_cmd ]] ; then
    ask_other_utilities
  else
    message "Recovered setting: 'obabel_cmd=$use_obabel_cmd'"
    ask "Would you like to change this setting?"
    if read_boolean ; then ask_other_utilities ; fi
  fi
  debug "use_obabel_cmd=$use_obabel_cmd"

  use_g16_input_suffix="$g16_input_suffix"
  use_g16_output_suffix="$g16_output_suffix"
  if [[ -z $use_g16_input_suffix || -z $use_g16_output_suffix ]] ; then
    ask_g16_default_extensions
  else
    message "Recovered setting: 'g16_input_suffix=$use_g16_input_suffix'"
    message "Recovered setting: 'g16_output_suffix=$use_g16_output_suffix'"
    ask "Would you like to change these settings?"
    if read_boolean ; then ask_g16_default_extensions ; fi
  fi
  debug "use_g16_input_suffix=$use_g16_input_suffix"
  debug "use_g16_output_suffix=$use_g16_output_suffix"

  use_g16_route_section_default="$g16_route_section_default"
  debug "g16_route_section_default=$use_g16_route_section_default"
  use_g16_route_section_predefined=( "${g16_route_section_predefined[@]}" )
  use_g16_route_section_predefined_comment=( "${g16_route_section_predefined_comment[@]}" )
  debug "$(declare -p use_g16_route_section_predefined)"
  debug "$(declare -p use_g16_route_section_predefined_comment)"
  if [[ -n $use_g16_route_section_default ]] ; then
    message "Recovered setting: 'g16_route_section_default=$use_g16_route_section_default'"
  fi
  if (( ${#use_g16_route_section_predefined[@]} != 0 )) ; then
    message "Recovered predefined route sections."
  fi
  ask "Would you like to display/add/remove stored route sections?"
  if read_boolean ; then ask_g16_store_route_section ; fi

  use_stay_quiet="$stay_quiet"
  [[ -z $use_stay_quiet ]] && use_stay_quiet=0
  message "Recovered setting: 'stay_quiet=$use_stay_quiet'"
  ask "Would you like to change this setting?"
  if read_boolean ; then ask_stay_quiet ; fi
  debug "use_stay_quiet=$use_stay_quiet"

  use_output_verbosity="$output_verbosity"
  [[ -z $use_output_verbosity ]] && use_output_verbosity=0
  message "Recovered setting: 'output_verbosity=$use_output_verbosity'"
  ask "Would you like to change this setting?"
  if read_boolean ; then ask_output_verbosity ; fi
  debug "use_output_verbosity=$use_output_verbosity"

  # backwards compatibility
  use_values_separator="$values_separator"
  debug "use_values_separator=$use_values_separator"
  case $use_values_separator in 
    [[:space:]])
      use_values_delimiter="space"
      ;;
    ',')
      use_values_delimiter="comma"
      ;;
    ';')
      use_values_delimiter="semicolon"
      ;;
    '|')
      use_values_delimiter="pipe"
      ;;
    '/')
      use_values_delimiter="slash"
      ;;
    '')
      debug "Empty (new configuration or unset): $use_values_separator"
      ;;
    *)
      debug "Not regognised: $use_values_separator"
      ;;
  esac
  use_values_delimiter="${use_values_delimiter:-$values_delimiter}"
  use_values_delimiter="${use_values_delimiter:-space}"
  debug "use_values_delimiter=$use_values_delimiter"
  message "Recovered setting: 'values_delimiter=$use_values_delimiter'"
  ask "Would you like to change this setting?"
  if read_boolean ; then ask_values_delimiter ; fi
  debug "use_values_delimiter=$use_values_delimiter"

  use_request_qsys="$request_qsys"
  # backwards compatibility
  use_qsys_project="${qsys_project:-$bsub_project}"
  use_user_email="${user_email:-$bsub_email}"
  # Very specific constraint:
  use_bsub_machinetype="$bsub_machinetype"
  if [[ -z $use_request_qsys ]] ; then
    ask_qsys_details
  else
    message "Recovered setting: 'request_qsys=$use_request_qsys'"
    ask "Would you like to change this setting?"
    if read_boolean ; then ask_qsys_details ; fi
  fi
  if [[ "$use_request_qsys" =~ ([Bb][Ss][Uu][Bb]|[Ss][Ll][Uu][Rr][Mm]) && -z $use_qsys_project ]] ; then
    ask_qsys_details
  else
    message "Recovered setting: 'qsys_project=$use_qsys_project'"
    ask "Would you like to change this setting?"
    message "Choosing 'yes' will re-enter the configuration of the queueing system."
    if read_boolean ; then ask_qsys_details ; fi
  fi
  if [[ "$use_request_qsys" =~ ([Bb][Ss][Uu][Bb]|[Ss][Ll][Uu][Rr][Mm]) && -z $use_user_email ]] ; then
    ask_qsys_details
  else
    message "Recovered setting: 'user_email=$use_user_email'"
    ask "Would you like to change this setting?"
    message "Choosing 'yes' will re-enter the configuration of the queueing system."
    if read_boolean ; then ask_qsys_details ; fi
  fi
  if [[ "$use_request_qsys" =~ [Bb][Ss][Uu][Bb]-[Rr][Ww][Tt][Hh] && -z $use_bsub_machinetype ]] ; then
    ask_qsys_details
  elif [[ "$use_request_qsys" =~ [Bb][Ss][Uu][Bb] && -n "$use_bsub_machinetype" ]] ; then
    message "Recovered setting: 'bsub_machinetype=$use_bsub_machinetype'"
    ask "Would you like to change this setting?"
    message "Choosing 'yes' will re-enter the configuration of the queueing system."
    if read_boolean ; then ask_qsys_details ; fi
  else
    debug "Chosen queueing system is not 'bsub', machine type irrelevant."
  fi
  debug "use_request_qsys=$use_request_qsys"
  debug "use_qsys_project=$use_qsys_project"
  debug "use_user_email=$use_user_email"
  debug "use_bsub_machinetype=$use_bsub_machinetype"

  use_qsys_email="$qsys_email"
  use_xmail_interface="$xmail_interface"
  use_xmail_cmd="$xmail_cmd"
  if [[ -z $use_xmail_interface ]] ; then
    ask_xmail_details
  else
    message "Recovered setting: 'qsys_email=$use_qsys_email"
    message "Recovered setting: 'xmail_interface=$use_xmail_interface"
    message "Recovered setting: 'xmail_cmd=$use_xmail_cmd"
    ask "Would you like to change this setting?"
    if read_boolean ; then ask_xmail_details ; fi
  fi
  debug "use_xmail_interface=$use_xmail_interface"
  debug "use_xmail_cmd=$use_xmail_cmd"

  use_requested_walltime="$requested_walltime"
  if [[ -z $use_requested_walltime ]] ; then
    ask_walltime
  else
    message "Recovered setting: 'requested_walltime=$use_requested_walltime'"
    ask "Would you like to change this setting?"
    if read_boolean ; then ask_walltime ; fi
  fi
  debug "use_requested_walltime=$use_requested_walltime"

  use_requested_memory="$requested_memory"
  if [[ -z $use_requested_memory ]] ; then
    ask_memory
  else
    message "Recovered setting: 'requested_memory=$use_requested_memory'"
    ask "Would you like to change this setting?"
    if read_boolean ; then ask_memory ; fi
  fi
  debug "use_requested_memory=$use_requested_memory"

  use_requested_numCPU="$requested_numCPU"
  if [[ -z $use_requested_numCPU ]] ; then
    ask_threads
  else
    message "Recovered setting: 'requested_numCPU=$use_requested_numCPU'"
    ask "Would you like to change this setting?"
    if read_boolean ; then ask_threads ; fi
  fi
  debug "use_requested_numCPU=$use_requested_numCPU"

  use_requested_maxdisk="$requested_maxdisk"
  if [[ -z $use_requested_maxdisk ]] ; then
    ask_maxdisk
  else
    message "Recovered setting: 'requested_maxdisk=$use_requested_maxdisk'"
    ask "Would you like to change this setting?"
    if read_boolean ; then ask_maxdisk ; fi
  fi
  debug "use_requested_maxdisk=$use_requested_maxdisk"

  use_requested_submit_status="$requested_submit_status"
  if [[ -z $use_requested_submit_status ]] ; then
    ask_submit_status
  else
    message "Recovered setting: 'requested_submit_status=$use_requested_submit_status'"
    ask "Would you like to change this setting?"
    if read_boolean ; then ask_submit_status ; fi
  fi
  debug "use_requested_submit_status=$use_requested_submit_status"

}

print_configuration ()
{
  # Write the configuration file 
  echo "#!/bin/bash"
  echo "# This is an an automatically generated configuration file."
  echo ""

  echo "# General path to the g16 directory (this should work on every system)"
  echo "# [Default: /path/is/not/set]"
  echo "#"
  if [[ -z $use_g16_installpath ]] ; then
    echo "# g16_installpath=\"/path/is/not/set\""
  else
    echo "  g16_installpath=\"$use_g16_installpath\""
  fi
  echo ""

  echo "# Define where scratch files shall be written to. [Default: default]"
  echo "# The default will write a 'mktemp' statement to the submitfile, "
  echo "# creating a directory at runtime."
  echo "# Valid values for this: T(E)MP(DIR) [case insensitive], default, 0, (empty)"
  echo "# If the pattern is not matched, the value will be taken as a directory, but not checked."
  echo "#"
  if [[ -z $use_g16_scratch ]] ; then
    echo '# g16_scratch="default"'
  else
    echo "  g16_scratch=\"$use_g16_scratch\""
  fi
  echo ""

  echo "# Define the overhead you'd like to give Gaussian in MB "
  echo "# [Default: 2000]"
  echo "#"
  if [[ -z $use_g16_overhead ]] ; then
    echo "# g16_overhead=2000"
  else
    echo "  g16_overhead=$use_g16_overhead"
  fi
  echo ""

  echo "# Save checkpoint files by default."
  echo "#"
  if [[ -z $use_g16_checkpoint_save ]] ; then
    echo "# g16_checkpoint_save=true"
  else
    echo "  g16_checkpoint_save=\"$use_g16_checkpoint_save\""
  fi
  echo ""

  echo "# If a modular software management is available, use it?"
  echo "# [Default: true]"
  echo "#"
  if [[ -z $use_load_modules ]] ; then
    echo "# load_modules=true"
  else
    echo "  load_modules=\"$use_load_modules\""
  fi
  echo "#"
  echo "# Enter the names of the modules to be loaded here."
  echo "# They have to appear in the correct order (if they happen to depend on each other)."
  echo "# "
  if (( ${#use_g16_modules[@]} == 0 )) ; then
    echo "# g16_modules[0]=\"DependOn\""
    echo "# g16_modules[1]=\"gaussian/version\""
  else
    local print_g16_modules
    print_g16_modules=$(declare -p use_g16_modules)
    print_g16_modules="${print_g16_modules/use_/}"
    echo "$print_g16_modules"
  fi
  echo ""

  echo "# Set the commands or paths for utilities:"
  echo "#"
  echo "# - wrapper for all Gaussian commands"
  echo "#"
  echo "#   The wrapper will load the Gaussian environment before executing the below utilities"
  echo "#   This should be blank if the utilities are found in PATH, or the absolute paths are provided"
  if [[ -z $use_g16_wrapper_cmd ]] ; then
    echo "#   g16_wrapper_cmd=\"g16.wrapper.sh\""
  else
    echo "    g16_wrapper_cmd=\"$use_g16_wrapper_cmd\""
  fi
  echo "#"
  echo "# - formatted checkpoint files"
  echo "#   "
  echo "#   The command that executes formchk."
  echo "#   Local install with formchk found in PATH, or wrapped with above, or absolute path."
  echo "#"
  if [[ -z $use_g16_formchk_cmd ]] ; then
    echo "#   g16_formchk_cmd=\"formchk\""
    echo "#   bin_formchk_cmd=\"/path/to/g16/formchk\""
    echo "#"
    echo "#   No options should be included in the above, but can be set:"
    echo "#   g16_formchk_opts=\"-3\""
    echo "#   If no options should be given to fromchk, the leave set it to empty,"
    echo "#   g16_formchk_opts=\"\""
    echo "#   otherwise the scripts will use '-3' as option."
  else
    echo "    g16_formchk_cmd=\"$use_g16_formchk_cmd\""
    echo "#   No options should be included in the above, but can be set:"
    echo "    g16_formchk_opts=\"$use_g16_formchk_opts\""
  fi
  echo "#"

  echo "# - checking the route section (this is similar to above)"
  echo "#   "
  if [[ -z $use_g16_testrt_cmd ]] ; then
    echo "#   g16_testrt_cmd=\"testrt\""
  else
    echo "    g16_testrt_cmd=\"$use_g16_testrt_cmd\""
  fi
  echo "#"
  echo ""

  echo "# This script requires an installation of Open Babel."
  echo "# Syntax used is: obabel [-i<in-type>] <in-file> [-o<out-type>] -O<out-file>"
  echo "# Restrictions as above apply."
  echo "#"
  if [[ -z $use_obabel_cmd ]] ; then 
    echo "# obabel_cmd=\"obabel\""
  else
    echo "  obabel_cmd=\"$use_obabel_cmd\""
  fi
  echo "#"
  echo ""

  echo "# Default files, suffixes, and other for Gaussian 16"
  echo "# "
  if [[ -z $use_g16_input_suffix ]] ; then
    echo "# g16_input_suffix=\"com\""
  else
    echo "  g16_input_suffix=\"$use_g16_input_suffix\""
  fi
  if [[ -z $use_g16_output_suffix ]] ; then
    echo "# g16_output_suffix=\"log\""
  else
    echo "  g16_output_suffix=\"$use_g16_output_suffix\""
  fi
  echo "#"
  echo "# Predefined Route sections"
  if [[ -z $use_g16_route_section_default ]] ; then
    echo "# g16_route_section_default='#P B97D3/def2-SVP'"
  else
    echo "  g16_route_section_default=\"$use_g16_route_section_default\""
  fi
  if (( ${#use_g16_route_section_predefined[@]} == 0 )) ; then
    echo "# g16_route_section_predefined[0]='#P B97D3/def2-SVP'"
    echo "# g16_route_section_predefined_comment[0]='pure DFT method, double zeta BS'"
    echo "# g16_route_section_predefined[1]='#P B97D3/def2-TZVPP OPT'"
    echo "# g16_route_section_predefined_comment[1]='pure DFT method, triple zeta BS, optimisation'"
  else
    local array_index=0
    for array_index in "${!use_g16_route_section_predefined[@]}" ; do
      printf '  g16_route_section_predefined[%d]="%s"\n' "$array_index" "${use_g16_route_section_predefined[$array_index]}"
      printf '  g16_route_section_predefined_comment[%d]="%s"\n' "$array_index" "${use_g16_route_section_predefined_comment[$array_index]}"
    done
  fi
  echo "#"
  echo ""

  # These values are always set
  echo "#"
  echo "# Default options for printing and verbosity"
  echo "#"
  echo ""
  echo "# Delimit values in the printout with 'space' (default)/ 'comma'/ 'semicolon'/ 'colon'/ 'slash'/ 'pipe' "
  echo "#"
  echo "  values_delimiter=\"${use_values_delimiter:-space}\""
  echo ""
  echo "# Corresponds to any switches '-v' (default: 0)"
  echo "#"
  echo "  output_verbosity=${use_output_verbosity:-0}"
  echo ""
  echo "# Corresponds to any switches '-s' that silence the output (default: 0)"
  echo "#"
  echo "  stay_quiet=${use_stay_quiet:-0}"
  echo ""

  echo "#"
  echo "# Default values for the queueing system"
  echo "#"
  echo ""
  echo "# Specify default Walltime in [[HH:]MM:]SS"
  echo "#"
  if [[ -z $use_requested_walltime ]] ; then
    echo "# requested_walltime=\"72:00:00\""
  else
    echo "  requested_walltime=\"$use_requested_walltime\""
  fi
  echo ""

  echo "# Specify a default value for the memory (does not include overhead)"
  echo "#"
  if [[ -z $use_requested_memory ]] ; then
    echo "# requested_memory=512"
  else
    echo "  requested_memory=\"$use_requested_memory\""
  fi
  echo ""

  echo "# Set the number of professors doing the calculation"
  echo "#"
  if [[ -z $use_requested_numCPU ]] ; then
    echo "# requested_numCPU=4"
  else
    echo "  requested_numCPU=\"$use_requested_numCPU\""
  fi
  echo ""

  echo "# The default which should be written to the inputfile regarding disk space (in MB)"
  echo "#"
  if [[ -z $use_requested_maxdisk ]] ; then
    echo "# requested_maxdisk=30000"
  else
    echo "  requested_maxdisk=\"$use_requested_maxdisk\""
  fi
  echo ""

  echo "# Select a queueing system <queue>-<special>"
  echo "# (<queue>: pbs, slurm, bsub; <special>: gen, rwth)"
  echo "#"
  if [[ -z $use_request_qsys ]] ; then
    echo "# request_qsys=\"pbs-gen\""
  else
    echo "  request_qsys=\"$use_request_qsys\""
  fi
  echo ""

  echo "# Account to project (bsub) or account (slurm)"
  echo "#"
  if [[ -z $use_qsys_project ]] || [[ "$use_qsys_project" == "default" ]] ; then
    echo "# qsys_project=default"
  else
    echo "  qsys_project=\"$use_qsys_project\""
  fi
  echo ""

  echo "# Deliver the default queuing system email"
  echo "# Values are for using this '1/yes/active' (default) or not using it '0/no/disabled'"
  echo "#"
  echo "  qsys_email=\"${use_qsys_email:-active}\""
  echo ""

  echo "#"
  if [[ -z $use_user_email ]] || [[ "$use_user_email" == "default" ]] ; then
    echo "# user_email=default@default.com"
  else
    echo "  user_email=\"$use_user_email\""
  fi
  echo ""

  echo "# Activate/deactivate sending extra mail (this is a configuration file only option)"
  echo "# Values are for using this '1/yes/active' or not using it (default) '0/no/disabled'"
  echo "#"
  echo "  xmail_interface=\"${use_xmail_interface:-disabled}\""
  echo "#"
  echo "# Provide the interface command (this can be any script/binary)"
  echo "# The routine uses 'mail' as a template and sends"
  echo "# > mail -s 'a subject line' "
  echo "# This defaults to mail if empty and therefore would send an empty email."
  echo "#"
  if [[ -z $use_xmail_cmd ]] ; then 
    echo "# xmail_cmd=mail"
  else
    echo "  xmail_cmd=\"$use_xmail_cmd\""
  fi
  echo ""

  echo "# Use following machine type (only for bsub)"
  echo "#"
  if [[ -z $use_bsub_machinetype ]] || [[ "$use_bsub_machinetype" == "default" ]] ; then
    echo "# bsub_machinetype=default"
  else
    echo "  bsub_machinetype=\"$use_bsub_machinetype\""
  fi
  echo ""

  echo "# Calculations will be submitted to run (hold/keep)"
  if [[ -z $use_requested_submit_status ]] ; then
    echo "# requested_submit_status=\"run\""
  else
    echo "  requested_submit_status=\"$use_requested_submit_status\""
  fi
  echo ""
  echo "#"
  echo "# Meta information "
  echo "#"
  echo "# Created with $scriptname, which is part of $softwarename"
  echo "configured_version=$version"
  echo "configured_versiondate=$versiondate"
  echo "# End of automatic configuration, $(date)."
}

write_configuration_to_file ()
{
  local settings_filename
  if [[ "$overwrite_mode" == "true" ]] ; then 
    debug "Overwrite mode active ($overwrite_mode)."
    settings_filename="${g16_tools_rc_loc:-$scriptpath/../.g16.toolsrc}"
  fi
  if [[ -z $settings_filename ]] ; then
    ask "Where do you want to store these settings?"
    message "Predefined location: $PWD/g16.tools.rc"
    message "Recommended location: $g16_tools_path/.g16.toolsrc"
    settings_filename=$(read_human_input)
    settings_filename=$(expand_tilde "$settings_filename")
    debug "settings_filename=$settings_filename"
    if [[ -z $settings_filename ]] ; then
      settings_filename="$PWD/g16.tools.rc"
    elif [[ -d "$settings_filename" ]] ; then
      settings_filename="$settings_filename/g16.tools.rc"
      warning "No valid filename specified, will use '$settings_filename' instead."
    fi
  fi

  backup_if_exists "$settings_filename"

  print_configuration > "$settings_filename"
  message "Written configuration file '$settings_filename'."
}

create_softlinks_in_bin ()
{
  local link_target_path="$HOME/bin"
  local test_PATH
  local file_name link_target_name link_target

  test_PATH=$(expand_tilde_in_path "$PATH")
  debug "test_PATH=$test_PATH"
  if [[ "$test_PATH" =~ (^|:)"${link_target_path}"(/)?(:|$) ]] ; then
    debug "Found '$link_target_path' in PATH."
  else
    warning "Directory '$link_target_path' appears to not be in PATH."
    message "Continue anyway."
  fi

  if [[ -r "$link_target_path" ]] ; then
    debug "Target path is readable: $link_target_path"
  else
    warning "Cannot read '$link_target_path'."
    return 1
  fi

  if [[ -w "$link_target_path" ]] ; then
    debug "Target path is writeable: $link_target_path"
  else
    warning "Cannot write to '$link_target_path'."
    return 1
  fi
  
  while read -r file_name || [[ -n "$file_name" ]]; do
    debug "file_name=$file_name"
    link_target_name="${file_name##*/}"
    debug "link_target_name=$link_target_name"
    link_target_name="${link_target_name/.sh/}"
    debug "link_target_name=$link_target_name"
    link_target="$link_target_path/$link_target_name"
    debug "link_target=$link_target"

    if [[ -e "$link_target" ]] ; then
      message "The following symbolic link already exists:"
      message "$(ls -l "$link_target")"
    else
      [[ -x "$file_name" ]] || warning "The file '$file_name' is not executable."
      message "$(ln -vs "$file_name" "$link_target")"
    fi

  done < <(ls "$g16_tools_path"/*.sh)

}

#
# MAIN SCRIPT
#

# If this script is sourced, return before executing anything
if ( return 0 2>/dev/null ) ; then
  # [How to detect if a script is being sourced](https://stackoverflow.com/a/28776166/3180795)
  debug "Script is sourced. Return now."
  return 0
fi

# Save how script was called
printf -v script_invocation_spell "'%s' " "${0/#$HOME/<HOME>}" "$@"

# Sent logging information to stdout
exec 3>&1

# Need to define debug function if unknown (It should be unknown.)
if ! command -v debug > /dev/null ; then
  debug () {
    echo "DEBUG  : " "$*" >&4
  }
fi

# Secret debugging switch
if [[ "$1" == "debug" ]] ; then
  exec 4>&1
  stay_quiet=0 
  debugging=true
  shift 
else
  exec 4> /dev/null
fi

get_scriptpath_and_source_files || exit 1

# Remove the local directory from PATH
if [[ ":$PATH:" =~ :.: ]] ; then
  debug "PATH is '$PATH'"
  modpath=":$PATH:"
  modpath=${modpath/:.:/:}
  modpath=${modpath%:}
  modpath=${modpath#:}
  PATH="$modpath"
  debug "PATH is now '$PATH'"
  unset modpath
fi

# Get options
# Initialise options
OPTIND="1"

while getopts :hROT options ; do
  #hlp   Usage: $scriptname [options]
  #hlp
  #hlp   Options:
  #hlp
  case $options in
    #hlp     -h        Prints this help text
    #hlp
    h) helpme ;; 

    #hlp     -R        Route mode. 
    #hlp               Load default configuration file, skip immediately to the route section editor,
    #hlp               replace read file with updated file.
    #hlp
    R) 
      warning "This is highly experimental currently."
      route_mode="true"
      overwrite_mode="true"
      ;;

    #hlp     -O        Overwrite mode. 
    #hlp               Load (specified) configuration file, replace read file with updated file.
    #hlp
    O) 
      warning "This is highly experimental currently."
      overwrite_mode="true"
      ;;

    #hlp     -T        Translate mode. 
    #hlp               Load default configuration file, translate it to a newer version,
    #hlp               replace read file with updated file.
    #hlp
    T) 
      warning "This is highly experimental currently."
      translate_mode="true"
      overwrite_mode="true"
      ;;

    #hlp     --       Close reading options.
    #hlp
    # This is the standard closing argument for getopts, it needs no implemenation.

    \?) fatal "Invalid option: -$OPTARG." ;;

    :) fatal "Option -$OPTARG requires an argument." ;;

  esac
done

get_configuration_from_file
if [[ "$route_mode" == true ]] ; then
  translate_conf_settings_to_internal
  ask_g16_store_route_section
elif [[ "$translate_mode" == true ]] ; then
  translate_conf_settings_to_internal
else
  get_configuration_interactive
fi

write_configuration_to_file

if [[ "$route_mode" == "true" || "$translate_mode" == "true" ]] ; then
  debug "Route (${route_mode:-false}) / translate (${translate_mode:-false}) mode active, skipping question about symbolic links."
else
  ask "Would you like to create a symbolic links for the scripts in '~/bin'?"
  if read_boolean ; then create_softlinks_in_bin ; fi
fi

#hlp $scriptname is part of $softwarename $version ($versiondate) 
message "$scriptname is part of $softwarename $version ($versiondate)"
debug "$script_invocation_spell"
