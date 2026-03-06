{
  pkgs,
  lib,
  config,
  inputs,
  ...
}: {
  imports = [
    ./_meta/nix/devcontainer.nix
    ./_meta/nix/git-hooks.nix
    ./_meta/nix/scripts.nix
    ./_meta/nix/tasks.nix
    ./_meta/nix/treefmt.nix
  ];

  packages = [
    pkgs.biome
    pkgs.cspell
    pkgs.gawk
    pkgs.git
    pkgs.gnugrep
    pkgs.gnused
    pkgs.nodejs_24
    pkgs.pnpm_10
    pkgs.uv
  ];

  dotenv.enable = true;

  enterShell = ''
    _setup_workspace
  '';

  languages = {
    go.enable = false;

    shell.enable = true;

    nix.enable = true;
    nix.lsp.package = pkgs.nixd;

    typescript.enable = false;

    javascript = {
      enable = false;
      package = pkgs.nodejs_24;
      pnpm = {
        enable = false;
        package = pkgs.pnpm_10;
        install = {
          enable = false; # Whether to run 'pnpm install'
        };
      };
    };

    python = {
      enable = true;
      version = "3.13";
      uv = {
        enable = true;
        sync = {
          enable = true;
          allGroups = true;
          allPackages = true;
        };
      };
    };

    rust = {
      enable = false;
      channel = "stable";
      version = "latest";
      targets = [
        "x86_64-unknown-linux-gnu"
        "aarch64-unknown-linux-gnu"
      ];
    };

    solidity = {
      enable = false;
      package = pkgs.solc;
      foundry = {
        enable = true;
        package = pkgs.foundry;
      };
    };
  };
}
