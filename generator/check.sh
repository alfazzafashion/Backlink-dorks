#!/bin/bash
# Script is used to check if a specified link exists in a list of web pages.
# This is useful for SEO experts when you need to validate that your backlinks
# still exist on the web pages where you set them or bought them.
# Author: Ramil Valitov ramilvalitov@gmail.com
# First release: 13.08.2018
# Git: https://github.com/rvalitov/backlink-checker
# We use some code from:
#https://natelandau.com/bash-scripting-utilities/
#https://github.com/tlatsas/bash-spinner

#OPTIONS

#Maximum timeout in seconds
TOTAL_TIMEOUT="5"

#Number of retries if connection fails
WEB_RETRIES="3"

#SCRIPT VARS
E_WGET=$(type -P wget)
E_GREP=$(type -P grep)
SUCCESS_COUNT=0
FAIL_COUNT=0
LOG_COUNT=0
VERBOSE_LOG=0
GREP_MODE="-F"
APPEND_LOG=0

#HELPER FUNCTIONS
#Library with UI functions
# We use some code from:
#https://natelandau.com/bash-scripting-utilities/
#https://github.com/tlatsas/bash-spinner

#
#Set Colors
#

bold=$(tput bold)
underline=$(tput sgr 0 1)
reset=$(tput sgr0)

purple=$(tput setaf 171)
red=$(tput setaf 1)
green=$(tput setaf 76)
tan=$(tput setaf 3)
blue=$(tput setaf 38)

#
# Headers and  Logging
#

e_header() {
  printf "\n${bold}${purple}==========  %s  ==========${reset}\n" "$@"
}
e_arrow() {
  printf "➜ $@\n"
}
e_success() {
  printf "${green}✔ %s${reset}\n" "$@"
}
e_error() {
  printf "${red}✖ %s${reset}\n" "$@"
}
e_warning() {
  printf "${tan}➜ %s${reset}\n" "$@"
}
e_underline() {
  printf "${underline}${bold}%s${reset}\n" "$@"
}
e_bold() {
  printf "${bold}%s${reset}\n" "$@"
}
e_note() {
  printf "${underline}${bold}${blue}Note:${reset}  ${blue}%s${reset}\n" "$@"
}

#####################
# Example:
#seek_confirmation "Do you want to print a success message?"
#if is_confirmed; then
#  e_success "Here is a success message"
#else
#  e_error "You did not ask for a success message"
#fi

seek_confirmation() {
  printf "\n${bold}$@${reset}"
  read -r -p " (y/n) " -n 1
  printf "\n"
}

seek_confirmation_yes() {
  printf "\n${bold}$@${reset}"
  read -r -p " (y/n)[Y] " -n 1
  printf "\n"
  if [[ -z "$REPLY" ]]; then
    REPLY="y"
  fi
}

# Test whether the result of an 'ask' is a confirmation
is_confirmed() {
  if [[ "$REPLY" =~ ^[Yy]$ ]]; then
    return 0
  fi
  return 1
}

####################
# Example:
#Check for Git
#if type_exists 'git'; then
#  e_success "Git good to go"
#else
#  e_error "Git should be installed. It isn't. Aborting."
#  exit 1
#fi
#
#if is_os "darwin"; then
#  e_success "You are on a mac"
#else
#  e_error "You are not on a mac"
#  exit 1
#fi

type_exists() {
  if [ $(type -P "$1") ]; then
    return 0
  fi
  return 1
}

is_os() {
  if [[ "${OSTYPE}" == $1* ]]; then
    return 0
  fi
  return 1
}

# spinner.sh
#
# Display an awesome 'spinner' while running your long shell commands
#
# Do *NOT* call _spinner function directly.
# Use {start,stop}_spinner wrapper functions

# usage:
#   1. source this script in your's
#   2. start the spinner:
#       start_spinner [display-message-here]
#   3. run your command
#   4. stop the spinner:
#       stop_spinner [your command's exit status]
#
# Also see: test.sh

function _spinner() {
  # $1 start/stop
  #
  # on start: $2 display message
  # on stop : $2 process exit status
  #           $3 spinner function pid (supplied from stop_spinner)

  local on_success="DONE"
  local on_fail="FAIL"
  local green="\e[1;32m"
  local red="\e[1;31m"
  local nc="\e[0m"

  case $1 in
  start)
    # calculate the column where spinner and status msg will be displayed
    let column=$(tput cols)-${#2}-8
    # display message and position the cursor in $column column
    echo -ne "${2}"
    printf "%${column}s"

    # start spinner
    i=1
    sp='\|/-'
    delay=${SPINNER_DELAY:-0.15}

    while :; do
      printf "\b${sp:i++%${#sp}:1}"
      sleep "$delay"
    done
    ;;
  stop)
    if [[ -z ${3} ]]; then
      echo "spinner is not running.."
      exit 1
    fi

    kill "$3" >/dev/null 2>&1

    # inform the user uppon success or failure
    echo -en "\b["
    if [[ $2 -eq 0 ]]; then
      echo -en "${green}${on_success}${nc}"
    else
      echo -en "${red}${on_fail}${nc}"
    fi
    echo -e "]"
    ;;
  *)
    echo "invalid argument, try {start/stop}"
    exit 1
    ;;
  esac
}

function start_spinner() {
  # $1 : msg to display
  _spinner "start" "${1}" &
  # set global spinner pid
  _sp_pid=$!
  disown
}

function stop_spinner() {
  # $1 : command exit status
  _spinner "stop" "$1" $_sp_pid
  unset _sp_pid
}

#MAIN CODE
for ((i = 1; i <= $#; i++)); do
  case ${!i} in
  "-v")
    VERBOSE_LOG=1
    ;;
  "-append")
    APPEND_LOG=1
    ;;
  "-input")
    ((i++))
    URLS_FILE=${!i}
    ;;
  "-found-log")
    ((i++))
    SUCCESS_FILE=${!i}
    ;;
  "-missing-log")
    ((i++))
    FAILURE_FILE=${!i}
    ;;
  "-log")
    ((i++))
    OUTPUT_FILE=${!i}
    ;;
  "-link")
    ((i++))
    SEARCH_LINK=${!i}
    ;;
  "-mode")
    ((i++))
    GREP_MODE=${!i}
    ;;
  "-user-agent")
    ((i++))
    USER_AGENT=${!i}
    ;;
  *)
    e_warning "Unknown argument ${!i}"
    exit 1
    ;;
  esac
done

if [[ -z $URLS_FILE ]] || [[ -z $SEARCH_LINK ]]; then
  e_error "Required arguments missing."
  echo "${bold}SYNOPSIS${reset}"
  echo -e "\t${bold}$0${reset} ${bold}-input${reset} ${underline}FILE${reset} ${bold}-link${reset} ${underline}LINK${reset} [OPTIONS]"
  echo
  echo "${bold}DESCRIPTION${reset}"
  echo -e "\tScript is used to check if a specified ${underline}LINK${reset} exists in a list of web pages specified in a ${underline}FILE${reset}, one URL per line. The script is useful for SEO experts when you need to validate that your backlinks still exist on the web pages where you set them or bought them."
  echo

  echo "${bold}OPTIONS${reset}"

  echo -e "\t${bold}-v${reset}"
  echo -e "\t\tActivates verbose mode"

  echo -e "\t${bold}-mode${reset} ${underline}LETTER${reset}"
  echo -e "\t\tThe ${underline}LETTER${reset} defines how ${underline}LINK${reset} is interpreted."
  echo -e "\t\tWe use grep for search, for complete info refer to Matcher Selection of the grep manual."
  echo -e "\t\tUsually grep supports the following modes:"
  echo -e "\t\t${bold}-E${reset}"
  echo -e "\t\tInterpret ${underline}LINK${reset} as an extended regular expression (ERE)."
  echo -e "\t\t${bold}-F${reset}"
  echo -e "\t\tInterpret ${underline}LINK${reset} as a fixed string (instead of regular"
  echo -e "\t\texpression). This is the default."
  echo -e "\t\t${bold}-G${reset}"
  echo -e "\t\tInterpret ${underline}LINK${reset} as a basic regular expression (BRE)."
  echo -e "\t\t${bold}-P${reset}"
  echo -e "\t\tInterpret ${underline}LINK${reset} as a Perl-compatible regular expression (PCRE)."

  echo -e "\t${bold}-log${reset} ${underline}LOG${reset}"
  echo -e "\t\tSaves the log to file ${underline}LOG${reset}."

  echo -e "\t${bold}-found-log${reset} ${underline}LOG${reset}"
  echo -e "\t\tSaves URLs where the ${underline}LINK${reset} was found to file ${underline}LOG${reset}."

  echo -e "\t${bold}-missing-log${reset} ${underline}LOG${reset}"
  echo -e "\t\tSaves URLs where the ${underline}LINK${reset} was not found to file ${underline}LOG${reset}."

  echo -e "\t${bold}-append${reset}"
  echo -e "\t\tAll log files will be appended, otherwise they will be overwritten."

  echo -e "\t${bold}-user-agent${reset} ${underline}AGENT${reset}"
  echo -e "\t\tSets user-agent string to ${underline}AGENT${reset}."

  exit 1
fi

if [[ ! -f $E_WGET ]]; then
  e_error "Failed to find wget. Please, install the related package."
  exit 1
fi
if [[ ! -f $E_GREP ]]; then
  e_error "Failed to find grep. Please, install the related package."
  exit 1
fi
if [[ ! -f $URLS_FILE ]]; then
  e_error "The specified file $URLS_FILE not found"
  exit 1
fi

function SaveToLog() {
  if [[ -z $1 ]] || [[ -z $2 ]]; then
    echo "Internal error. Invalid parameters in save log function."
    return 1
  fi

  unset FILENAME

  case $1 in
  "SUCCESS")
    FILENAME=$SUCCESS_FILE
    ((SUCCESS_COUNT++))
    OVERWRITE=$SUCCESS_COUNT
    ;;
  "FAIL")
    FILENAME=$FAILURE_FILE
    ((FAIL_COUNT++))
    OVERWRITE=$FAIL_COUNT
    ;;
  "LOG")
    FILENAME=$OUTPUT_FILE
    ((LOG_COUNT++))
    OVERWRITE=$LOG_COUNT
    ;;
  *)
    echo "Internal error. Invalid log type."
    return 1
    ;;
  esac

  if [[ -z $FILENAME ]]; then
    return 0
  fi

  if [[ $APPEND_LOG == 0 ]] && [[ $OVERWRITE == 1 ]]; then
    echo "$2" >"$FILENAME"
  else
    echo "$2" >>"$FILENAME"
  fi

  return 0
}

function CheckWebsiteLink() {
  if [[ -z $1 ]]; then
    echo "Internal error. No server specified."
    return 1
  fi
  if [[ $VERBOSE_LOG -gt 0 ]]; then
    start_spinner "Checking $1"
    sleep 1
  fi
  if [[ -n $USER_AGENT ]]; then
    RESPONSE=$($E_WGET -O- -nv -q --timeout=$TOTAL_TIMEOUT --tries=$WEB_RETRIES --user-agent="$USER_AGENT" "$1" 2>&1)
  else
    RESPONSE=$($E_WGET -O- -nv -q --timeout=$TOTAL_TIMEOUT --tries=$WEB_RETRIES "$1" 2>&1)
  fi
  THE_STATUS=$?
  if [[ $THE_STATUS != 0 ]]; then
    if [[ $VERBOSE_LOG -gt 0 ]]; then
      stop_spinner 1
    fi
    SaveToLog "LOG" "$1 failed to donwload link. Error code $THE_STATUS. Response: $RESPONSE"
    return 1
  fi
  if [[ $VERBOSE_LOG -gt 0 ]]; then
    stop_spinner 0
  fi
  SEARCH_RESULT=$(echo "$RESPONSE" | $E_GREP "$GREP_MODE" "$SEARCH_LINK" 2>&1)
  if [[ -n $SEARCH_RESULT ]]; then
    SaveToLog "LOG" "$1 OK"
    return 0
  fi
  SaveToLog "LOG" "$1 NOT FOUND"
  return 1
}

while IFS= read -r line; do
  if [[ -n $line ]]; then
    CheckWebsiteLink "$line"
    THE_STATUS=$?

    if [[ $THE_STATUS != 0 ]]; then
      SaveToLog "FAIL" "$line"
      e_warning "$line link NOT found"
    else
      SaveToLog "SUCCESS" "$line"
      e_success "$line link found"
    fi
  fi
done < <($E_GREP "" $URLS_FILE)

if [[ $VERBOSE_LOG -gt 0 ]]; then
  echo "All operations complete"
fi
exit 0
