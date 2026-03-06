#!/usr/bin/env bash

log_msg() {
  local level="" msg="" color=""

  : "${LOG_NAME:="scripts"}"
  : "${LOG_DIR:="$WORKSPACE_ROOT/_meta/logs"}"
  : "${LOG_FILE:="$LOG_DIR/${LOG_NAME%.*}.log"}"
  : "${LOG_STDOUT:=0}"
  : "${LOG_NO_TIMESTAMP:=}"

  level="$(printf '%.3s' "$1" | tr '[:upper:]' '[:lower:]')"
  case "$level" in
    8 | f | fat) shift 1 && level=" FATAL    " color="\e[40;91m" msg="$*" ;;  # bright red
    7 | x | eme) shift 1 && level=" EMERG    " color="\e[40;91m" msg="$*" ;;  # bright red
    6 | a | ale) shift 1 && level=" ALERT    " color="\e[40;91m" msg="$*" ;;  # bright red
    5 | c | cri) shift 1 && level=" CRITICAL " color="\e[40;91m" msg="$*" ;;  # red
    4 | e | err) shift 1 && level=" ERROR    " color="\e[40;31m" msg="$*" ;;  # red
    3 | w | war) shift 1 && level=" WARNING  " color="\e[40;93m" msg="$*" ;;  # bright yellow
    2 | n | not) shift 1 && level=" NOTICE   " color="\e[40;33m" msg="$*" ;;  # yellow
    1 | i | inf) shift 1 && level=" INFO     " color="\e[40;97m" msg="$*" ;;  # bright white
    0 | d | deb) shift 1 && level=" DEBUG    " color="\e[40;96m" msg="$*" ;;  # bright cyan
    00 | t | tra) shift 1 && level=" TRACE    " color="\e[40;35m" msg="$*" ;; # magenta
    s | ok | suc) shift 1 && level=" SUCCESS  " color="\e[40;92m" msg="$*" ;; # bright green
    *) level=" INFO     " color="\e[40;97m" msg="$*" ;;
  esac

  case "$level" in
    *DEBU*) [ "${DEBUG:=0}" -ge 1 ] || return ;;
    *TRAC*) [ "${DEBUG:=0}" -ge 2 ] || return ;;
  esac

  if [ "${msg:-}" != "" ]; then
    local dr="" color_msg="" timestamp=""

    [ "${NO_COLOR:-}" != "" ] && color=""
    [ "${DRY_RUN:=0}" = "1" ] && dr="| DRY RUN "
    [ "${LOG_NO_TIMESTAMP:=}" = "" ] && timestamp="$(date -u -- '+%Y-%m-%dT%H:%M:%S%z') "

    if [ "${LOG_FILE:-}" != "" ] && [ ! -e "$LOG_FILE" ]; then
      mkdir -p -- "$(dirname -- "$LOG_FILE")" && touch -- "$LOG_FILE"
    fi

    color_msg="${timestamp:-}|${color:-}${level:-}\e[0m${dr:-}| ${msg}"
    msg="${timestamp:-}|${level:-}${dr:-}| ${msg}"

    [ -e "${LOG_FILE:-}" ] && printf -- '%b\n' "$msg" >>"$LOG_FILE"
    [ "${LOG_STDOUT:=0}" = "0" ] && printf -- '%b\n' "$color_msg" >&2
  fi

  return 0
}

assert_not_empty() {
  if [ "$2" = "" ]; then
    log_msg "f" "'$1' is unset or empty: $1='$2'" >&2
    exit 1
  fi
}

assert_not_value() {
  if [ "$2" = "$3" ]; then
    log_msg "f" "'$1' is misconfigured: $1='$2'" >&2
    exit 1
  fi
}

assert_exists() {
  if assert_not_empty "$1" "$2" && [ ! -e "$2" ]; then
    log_msg "f" "'$1' does not exist: '$2'" >&2
    exit 1
  fi
}

assert_is_dir() {
  if assert_exists "$1" "$2" && [ ! -d "$2" ]; then
    log_msg "f" "'$1' is not a directory: '$2'" >&2
    exit 1
  fi
}

assert_is_file() {
  if assert_exists "$1" "$2" && [ ! -f "$2" ]; then
    log_msg "f" "'$1' is not a file: '$2'" >&2
    exit 1
  fi
}

__usage_cd_or_die() {
  cat >&2 <<-EOF
Usage:
  cd_or_die [VAR_NAME] DEST_DIR"

Examples:
  cd_or_die WORKSPACE_ROOT \${WORKSPACE_ROOT}
  cd_or_die \${WORKSPACE_ROOT}
EOF
}

cd_or_die() {
  local var_name dest_dir
  if [ "$#" -eq 1 ]; then
    var_name="$1" dest_dir="$1"
  elif [ "$#" -eq 2 ]; then
    var_name="" dest_dir="$2"
  else
    __usage_cd_or_die
    log_msg "f" "Invalid arguments for 'cd_or_die': $*"
    exit 1
  fi

  if [ "$var_name" != "" ]; then
    assert_is_dir "$var_name" "$dest_dir"
  fi

  if ! cd "$dest_dir"; then
    log_msg "f" "Failed to change directory to '$dest_dir'"
    exit 1
  fi
}
