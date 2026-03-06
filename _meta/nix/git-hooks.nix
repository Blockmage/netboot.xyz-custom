{
  config,
  lib,
  pkgs,
  ...
}: let
  wspRoot = ".";
  cfgDir = "_meta/config";
in {
  git-hooks = {
    enable = true;
    install.enable = true;
    default_stages = ["pre-commit"];

    excludes = [
      ".*-lock\..*"
      ".*\.lock$"
      ".*example.*"
      "cspell\.txt"
    ];

    hooks = {
      # -------------------------------- Hooks ---------------------------------
      mixed-line-endings.enable = true;
      end-of-file-fixer.enable = true;
      trim-trailing-whitespace.enable = true;

      check-added-large-files.enable = true;
      check-case-conflicts.enable = true;
      check-merge-conflicts.enable = true;
      check-symlinks.enable = true;

      cspell-commit-msg.enable = true;
      cspell-workspace-files.enable = true;

      pyright.enable = true;
      pytest.enable = true;

      treefmt.enable = true;
      trufflehog.enable = true;
      actionlint.enable = true;

      # ----------------------------- Hook Options -----------------------------
      check-added-large-files.args = ["--maxkb=8192"];
      mixed-line-endings.args = ["--fix=auto"];

      trufflehog = {
        stages = ["pre-commit" "pre-push"];

        args = [
          "git"
          "\"file://${wspRoot}\""
          "--since-commit"
          "HEAD"
          "--results=verified"
          "--fail"
          "--exclude-paths=\"${cfgDir}/trufflehog_exclude.txt\""
          "--detector-timeout=15s"
        ];
      };

      pyright = {
        types = ["python"];
        stages = ["pre-push"];
        args = ["--project" "${wspRoot}"];
      };

      cspell-workspace-files = {
        name = "check spelling: workspace files";
        language = "system";
        stages = ["pre-commit" "pre-push"];
        entry = "${pkgs.cspell}/bin/cspell";

        args = [
          "--config"
          "${wspRoot}/cspell.config.jsonc"
          "--no-summary"
          "--no-progress"
          "--no-must-find-files"
        ];
      };

      cspell-commit-msg = {
        name = "check spelling: commit message";
        language = "system";
        always_run = true;
        stages = ["commit-msg"];
        entry = "${pkgs.cspell}/bin/cspell";

        args = [
          "--config"
          "${wspRoot}/cspell.config.jsonc"
          "--no-must-find-files"
          "--no-progress"
          "--no-summary"
          "--files"
          ".git/COMMIT_EDITMSG"
        ];
      };

      pytest = {
        name = "pytest";
        language = "system";
        always_run = true;
        pass_filenames = false;
        stages = ["pre-push"];
        types = ["python"];

        entry = ''
          sh -c '
          _pytest="${wspRoot}/.devenv/state/venv/bin/pytest"
          if [ ! -x "$_pytest" ]; then
            echo "Skipping - pytest not found."
          else
            _found="$("${pkgs.findutils}/bin/find" "${wspRoot}" \
              -not \( \
                -path "*/node_modules/*"    -prune -o  \
                -path "*/data/*"            -prune -o  \
                -path "*/.*/*"              -prune -o  \
                -path "*/vendor/*"          -prune -o  \
                -path "*/target/debug/*"    -prune -o  \
                -path "*/.local/*"          -prune -o  \
                -path "*/python3.*/*"       -prune -o  \
                -path "*/target/release/*"  -prune  \) \
                -iname "*test*.py" -print)"
            if [ "$_found" != "" ]; then
              ".venv/bin/pytest"
            fi
          fi'
        '';
      };

      golangci-lint = {
        name = "golangci-lint";
        language = "system";
        pass_filenames = false;
        entry = "${lib.getExe pkgs.golangci-lint}";
        stages = ["pre-commit"];
        types = ["go"];

        args = [
          "run"
          "--config=${cfgDir}/.golangci.yml"
          "--timeout=5m"
          "--skip-dirs-re=^(vendor|build|dist)$"
        ];
      };
    };
  };
}
