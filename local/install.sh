#!/bin/sh

# Local file paths
ZFSMON_UPDATER_PATH='/usr/bin/updater.py'
ZFSMON_LOG_PATH='/var/log/zfsmond'
ZFSMON_EGG_PATH='/usr/lib/python2.6/site-packages/zfsmond-latest.egg'
ZFSMON_CONF_PATH='/etc/zfsmond.conf'

# Download URIs
SETUPTOOLS_DOWNLOAD_URI='http://pypi.python.org/packages/2.6/s/setuptools/setuptools-0.6c11-py2.6.egg'
ZFSMON_DOWNLOAD_EGG_URI='http://devilray.crbs.ucsd.edu/skip-proxy/zfsmond-latest.egg'
ZFSMON_DOWNLOAD_CONF_URI='http://devilray.crbs.ucsd.edu/skip-proxy/zfsmond.conf'

# Crontab line
ZFSMON_CRON="0,15,30,45 * * * * $ZFSMON_UPDATER_PATH 2>&1 >> $ZFSMON_LOG_PATH"

# Temporary working dir
TMP_DIR="/tmp/zfsmond_$$"
mkdir -p "$TMP_DIR"

# Use the UCSD proxy in case we're in private IP space.
http_proxy='http://webproxy.ucsd.edu:3128'
export http_proxy
https_proxy='http://webproxy.ucsd.edu:3128'
export https_proxy



function fatal_error() {
  printf '%s\n' "Fatal error: $*" >&2
  exit 1
}


function file_check() {
  FILE_NAME="$1"
  FILE_PATH="$2"

  printf '%s ' "Checking for $FILE_NAME..." >&2

  if [ -f "$FILE_PATH" ]; then
    printf '%s\n' "found." >&2
    return 0
  else
    printf '%s\n' 'not found.' >&2
    return 1
  fi

  unset FILE_PATH
  unset FILE_NAME
}


function curl_download() {
  FILE_NAME="$1"
  shift
  DOWNLOAD_URI="$*"

  printf '%s ' "Downloading $FILE_NAME..." >&2
  if ( curl --silent "$DOWNLOAD_URI" -o "$TMP_DIR/$FILE_NAME" ) ; then
    printf '%s\n' 'done.' >&2
  else
    printf '%s\n' 'failed.' >&2
    fatal_error "Failed to download $FILE_NAME"
  fi

  unset DOWNLOAD_URI
  unset FILE_NAME
}


function install_component() {
  COMPONENT_NAME="$1"
  shift
  INSTALL_COMMAND="$*"

  ORIG_DIR=`pwd`
  cd "$TMP_DIR"

  printf '%s ' "Installing $COMPONENT_NAME..." >&2
  if ( sh -c "$INSTALL_COMMAND" >/dev/null ); then
    printf '%s\n' 'done.' >&2
  else
    printf '%s\n' 'failed.' >&2
    fatal_error "Failed to install $COMPONENT_NAME"
  fi

  unset COMPONENT_NAME
  unset INSTALL_COMMAND
  cd "$ORIG_DIR"
}


# Checking for easy_install
function check_for_setuptools() {
  file_check "setuptools" `which easy_install`
}


# Verify updater.py exists in the expected location
function check_for_zfsmon_updater() {
  file_check "updater.py" "$ZFSMON_UPDATER_PATH"
}


# Remove existing zfsmond-latest.egg, if present
function check_for_zfsmon_egg() {
  file_check "zfsmond-latest.egg" "$ZFSMON_EGG_PATH"
}


function check_for_zfsmon_conf() {
  file_check "zfsmond.com" "$ZFSMON_CONF_PATH"
}


# Check crontab for the updater.py script
function check_for_crontab_entry() {
  printf '%s ' 'Checking for zfsmon crontab entry...' >&2
  if ( crontab -l 2>/dev/null | grep "$ZFSMON_UPDATER_PATH" 2>&1 >/dev/null ) ; then
    printf '%s\n' "found." >&2
    return 0
  else
    printf '%s\n' "not found." >&2
    return 1
  fi
}


# Install Python setuptools
function install_setuptools() {
  curl_download "setuptools.egg" "$SETUPTOOLS_DOWNLOAD_URI"
  install_component 'setuptools' 'sudo sh setuptools.egg'
}


# Install dependency: requests library
function install_requests_lib() {
  install_component 'requests' 'sudo easy_install requests'
}


# Install zfsmond egg
function install_zfsmon_egg() {
  curl_download "zfsmond-latest.egg" "$ZFSMON_DOWNLOAD_EGG_URI"
  install_component 'zfsmond-latest.egg' 'sudo easy_install ./zfsmond-latest.egg'
}


# Install zfsmond.conf if not yet installed.
function install_zfsmon_conf() {
  curl_download "zfsmond.conf" "$ZFSMON_DOWNLOAD_CONF_URI"
  install_component 'zfsmond.conf' "sudo cp zfsmond.conf $ZFSMON_CONF_PATH"
}


# Remove existing zfsmond egg, if present
function remove_zfsmon_egg() {
  printf '%s ' 'Removing zfsmon-latest.egg...' >&2
  sudo rm -rf "$ZFSMON_EGG_PATH" && printf '%s\n' "done."
}


function install_crontab_entry() {
  printf '%s\n' "$ZFSMON_CRON" | crontab || fatal_error "Error installing crontab entry."
}


# Prompt user with yes or no question.
# Usage:   prompt_user_yn 'Question' 'Prompt' && run_if_yes || run_if_no
# Example: prompt_user_yn 'Would you like to play a game?' 'Play a game?' && play_game || something_else
#          > Would you like to play a game?
#          > Play a game? (y/n): _
function prompt_user_yn() {
  while : ; do
	printf '%s\n' "$1" >&2
    printf '%s ' "$2 (y/n):" >&2
    read REPLY
    case "$REPLY" in
      [Yy]) return 0
            ;;
      [Nn]) 
            return 1
            ;;
         *) printf '%s\n' 'Invalid selection.' >&2
            ;;
    esac
  done
  printf '\n'
}


# Remove temporary files
function clean_up() {
  rm -rf "$TMP_DIR" || fatal_error "Failed to remove temporary files in $TMP_DIR."
}


## Main

# Cleanup on exit
trap "cleanup" EXIT

# Install setuptools (easy_install) if it's not yet installed
check_for_setuptools || install_setuptools

# Install the Python requests lib.
install_requests_lib

# If zfsmond egg is already installed, remove it
check_for_zfsmon_egg && remove_zfsmon_egg

# Install zfsmon egg
install_zfsmon_egg

# Install zfsmond.conf file unless it's already installed
check_for_zfsmon_conf || install_zfsmon_conf

# Check for the updater.py script
check_for_zfsmon_updater || fatal_error "Could not find $ZFSMON_UPDATER_PATH but we just installed it."

# Prompt the user to add the updater script to the crontab
if ! check_for_crontab_entry ; then
  if prompt_user_yn 'The update.py script should be run every 15 minutes.' "Add entry to $USER's crontab?" ; then
    install_crontab_entry
  else
    printf '%s\n' 'Okay, then you will have to add this line to the crontab yourself:' "$ZFSMON_CRON" >&2
  fi
fi

# Remove temporary files
clean_up