{
  pkgs,
  lib,
  config,
  ...
}: {
  scripts = {
    git = {
      description = ''Alias for `git` that forces the use of UTC timestamps for commits'';
      exec = ''
        _TZ="$TZ"
        UTC_TIMESTAMP="$(date '+%s')+0000"
        export TZ="UTC" GIT_AUTHOR_DATE="$UTC_TIMESTAMP" GIT_COMMITTER_DATE="$UTC_TIMESTAMP"
        "${lib.getExe pkgs.git}" "$@"
        export TZ="$_TZ"
        unset _TZ UTC_TIMESTAMP GIT_AUTHOR_DATE GIT_COMMITTER_DATE
      '';
    };

    pnpf = {
      description = lib.concatStrings [
        ''Run a command with: `pnpm -F "''${1}" exec -- "''${@:2}"` ''
        ''where $1 is the workspace package name and $2 is the command and any arguments''
      ];
      exec = ''${lib.getExe pkgs.pnpm_10} -F "''${1}" exec -- "''${@:2}"'';
    };

    install-hooks = {
      description = ''Install pre-commit hooks'';
      exec = ''
        git config --unset-all core.hooksPath 2>/dev/null
        pre-commit install --install-hooks -f 2>/dev/null
      '';
    };

    _setup_workspace = {
      exec = ''
        if ! WORKSPACE_ROOT="$("${lib.getExe pkgs.git}" rev-parse --show-toplevel 2>/dev/null)"; then
          echo -n "WARNING: Not in a Git repository. " >&2
          echo "Inferring value for 'WORKSPACE_ROOT' based on \$PWD, which may be incorrect!" >&2
          WORKSPACE_ROOT="$PWD"
        fi

        export WORKSPACE_ROOT
        if [ -d "$WORKSPACE_ROOT" ]; then
          if mkdir -p "$WORKSPACE_ROOT"/_meta/{config,bin,nix,scripts,reports,log} 2>/dev/null; then
            [ -f "${lib.getExe pkgs.biome}" ]   && ln -sf "${lib.getExe pkgs.biome}"    "$WORKSPACE_ROOT/_meta/bin/biome"
            [ -f "${lib.getExe pkgs.treefmt}" ] && ln -sf "${lib.getExe pkgs.treefmt}"  "$WORKSPACE_ROOT/_meta/bin/treefmt"
            [ -f "${config.treefmt.config.build.configFile}" ] &&
              ln -sf "${config.treefmt.config.build.configFile}" "$WORKSPACE_ROOT/_meta/config/treefmt.toml"
          else
            printf "\nERROR: Failed to create symlinks to linter/formatter binaries in the workspace\n"
          fi
        else
          printf "\nWARNING: 'WORKSPACE_ROOT' is unset or empty\n"
        fi

        export TEMPLATES_DIR="$WORKSPACE_ROOT/_meta/templates";
        export SCRIPTS_DIR="$WORKSPACE_ROOT/_meta/scripts";
        export CONFIG_DIR="$WORKSPACE_ROOT/_meta/config";
        export BIN_DIR="$WORKSPACE_ROOT/_meta/bin";
        export LOG_DIR="$WORKSPACE_ROOT/_meta/log";
      '';
    };
  };
}
