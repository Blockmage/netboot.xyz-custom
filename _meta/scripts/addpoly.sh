#!/usr/bin/env bash

ARG0="${BASH_SOURCE[0]:-"$0"}"

: "${WORKSPACE_ROOT:=}"
: "${POLY_NAMESPACE:=}"
: "${SCRIPTS_DIR:="$WORKSPACE_ROOT/_meta/scripts"}"

usage() {
  echo -e "Usage:\t$(basename -- "${ARG0%.*}") component|project|base NAME" >&2
  exit 1
}

create_brick() {
  local brick="$1" name="$2"

  if [ "$brick" = "project" ]; then
    local dir="$WORKSPACE_ROOT/${brick}s/$name"
  else
    local dir="$WORKSPACE_ROOT/${brick}s/$POLY_NAMESPACE/$name"
  fi

  if [ -e "$dir" ]; then
    log_msg "e" "A $brick named '$name' already exists: $dir"
    return 1
  fi

  log_msg "i" "Adding $brick to Polylith: ${name}..."
  if echo "n" | uv run poly create "$brick" --name "$name" >/dev/null 2>&1; then
    mkdir -p "$dir" || return 1

    if [ "$brick" = "project" ]; then
      local template="$WORKSPACE_ROOT/_meta/templates/polylith.pyproject.template.toml"
      local pyproject="$dir/pyproject.toml"

      if [ -e "$template" ]; then
        [ -f "$pyproject" ] && rm -f "$pyproject"

        if uv init --directory "$dir" >/dev/null 2>&1; then
          if command -v envsubst >/dev/null 2>&1; then
            [ -f "$dir/main.py" ] && rm -f "$dir/main.py"

            SUB_PROJECT_NAME="$name" SUB_PROJECT_VERS="$(date -u '+%Y.%m.%d')"
            export SUB_PROJECT_NAME SUB_PROJECT_VERS POLY_NAMESPACE

            envsubst <"$template" >"$pyproject"
          else
            log_msg "w" "Command not found: 'envsubst'"
            log_msg "w" "New project in '$dir' may be only partially initialized"
          fi

        else
          log_msg "e" "Failed to initialize new project in '$dir'"
          return 1
        fi
      fi

    else
      [ -f "$dir/__init__.py" ] && echo >"$dir/__init__.py"
      [ -f "$dir/core.py" ] && mv -- "$dir/core.py" "$dir/_core.py"

      if [ "$brick" = "component" ]; then
        if mkdir -p "$dir/_tests"; then
          touch "$dir/_tests/__init__.py"
          touch "$dir/_tests/test_${name}.py"
        fi
      fi
    fi

  else
    log_msg "e" "Failed to create $brick anmed $name"
    return 1
  fi
}

if ! source "$SCRIPTS_DIR/lib.sh"; then
  echo "File not found: '$SCRIPTS_DIR/lib.sh'" >&2
  exit 1
fi

assert_is_dir WORKSPACE_ROOT "$WORKSPACE_ROOT"
assert_is_dir SCRIPTS_DIR "$SCRIPTS_DIR"
assert_not_empty POLY_NAMESPACE "$POLY_NAMESPACE"
assert_not_value SCRIPTS_DIR "$SCRIPTS_DIR" "/_meta/scripts"

if ! cd "$WORKSPACE_ROOT"; then
  echo "Failed to change directory to 'WORKSPACE_ROOT': '$WORKSPACE_ROOT'" >&2
  exit 1
fi

mkdir -p \
  "$WORKSPACE_ROOT/components/$POLY_NAMESPACE" \
  "$WORKSPACE_ROOT/bases/$POLY_NAMESPACE" \
  "$WORKSPACE_ROOT/projects"

if [ $# -eq 2 ]; then
  cmd="$1" args=("${@:2}")

  case "$cmd" in
    c*) _brick="component" ;;
    p*) _brick="project" ;;
    b*) _brick="base" ;;
    *) usage ;;
  esac

  if create_brick "$_brick" "${args[@]}"; then
    log_msg 's' "Added ${_brick} to Polylith: ${args[*]}"
  fi

else
  usage
fi
