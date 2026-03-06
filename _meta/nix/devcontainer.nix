{
  pkgs,
  lib,
  config,
  ...
}: {
  devcontainer = {
    # Enabling this will only generate the 'devcontainer.json' in the workspace root.
    # It doesn't need to be enabled unless changes are being made here.
    enable = false;

    settings = {
      # The name of an image in a container registry.
      # Default: "ghcr.io/cachix/devenv/devcontainer:latest"
      image = "ghcr.io/cachix/devenv/devcontainer:latest";

      # A command to run after the container is created.
      # Default: "devenv test"
      updateContentCommand = "devenv test";

      customizations = {
        vscode = {
          extensions = [
            "1password.op-vscode"
            "bierner.color-info"
            "bierner.markdown-preview-github-styles"
            "biomejs.biome"
            "charliermarsh.ruff"
            "christian-kohler.path-intellisense"
            "davidanson.vscode-markdownlint"
            "editorconfig.editorconfig"
            "emeraldwalk.runonsave"
            "github.remotehub"
            "github.vscode-github-actions"
            "github.vscode-pull-request-github"
            "golang.go"
            "jnoortheen.nix-ide"
            "mads-hartmann.bash-ide-vscode"
            "mechatroner.rainbow-csv"
            "ms-azuretools.vscode-containers"
            "ms-python.debugpy"
            "ms-python.python"
            "ms-python.vscode-pylance"
            "ms-python.vscode-python-envs"
            "ms-toolsai.jupyter-keymap"
            "ms-toolsai.jupyter-renderers"
            "ms-toolsai.jupyter"
            "ms-toolsai.vscode-jupyter-cell-tags"
            "ms-toolsai.vscode-jupyter-slideshow"
            "ms-vscode-remote.remote-containers"
            "ms-vscode-remote.remote-ssh-edit"
            "ms-vscode-remote.remote-ssh"
            "ms-vscode.remote-explorer"
            "ms-vscode.remote-repositories"
            "ms-vscode.remote-server"
            "nhoizey.gremlins"
            "njpwerner.autodocstring"
            "redhat.vscode-xml"
            "redhat.vscode-yaml"
            "rust-lang.rust-analyzer"
            "streetsidesoftware.code-spell-checker"
            "tailscale.vscode-tailscale"
            "tamasfe.even-better-toml"
            "timonwong.shellcheck"
          ];
        };
      };
    };
  };
}
