{ self, ... }:
{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.programs.atlantic;
  system = pkgs.stdenv.hostPlatform.system;

  jsonFormat = pkgs.formats.json { };
  inherit (import ./settings-options.nix { inherit lib pkgs; }) settingsSubmodule;

  templateSettings = builtins.fromJSON (builtins.readFile "${self}/config/atlantic/settings.json");

  userSettings = lib.filterAttrsRecursive (_: v: v != null) cfg.settings;

  mergedSettings = lib.recursiveUpdate templateSettings userSettings;
  settingsFile = jsonFormat.generate "atlantic-settings.json" mergedSettings;

  settingsTarget = "${config.xdg.configHome}/atlantic/settings.json";
in
{
  options.programs.atlantic = {
    enable = mkEnableOption "the atlantic Quickshell desktop shell";

    package = mkOption {
      type = types.package;
      default = self.packages.${system}.default;
      defaultText = literalExpression "atlantic.packages.<system>.default";
      description = "The atlantic package to use.";
    };

    settings = mkOption {
      type = settingsSubmodule;
      default = { };
      example = literalExpression ''
        {
          bar.position = "left";
          bar.modules.right = [ "tray" [ "kb" "wifi" "bt" "vol" "bat" ] ];
          theme.fontFamily = "Adwaita Mono";
          notifications.dnd = true;
        }
      '';
      description = ''
        atlantic configuration, layered on top of the package's
        bundled `config/atlantic/settings.json` and written to
        `$XDG_CONFIG_HOME/atlantic/settings.json`.
        See settings-options.nix for the full list of typed fields;
        anything not listed there can still be set as a plain
        attribute.
      '';
    };

    systemd = {
      enable = mkOption {
        type = types.bool;
        default = pkgs.stdenv.isLinux;
        description = "Whether to run atlanticd as a `systemd --user` service.";
      };

      target = mkOption {
        type = types.str;
        default = "graphical-session.target";
        description = "Target atlanticd is tied to (start/stop/restart with it).";
      };

      environment = mkOption {
        type = types.attrsOf types.str;
        default = { };
        example = { QT_QPA_PLATFORM = "wayland"; };
        description = "Extra environment variables for the atlanticd unit.";
      };
    };
  };

  config = mkIf cfg.enable {
    home.packages = [ cfg.package ];

    programs.atlantic.settings.wallpaperDir = mkDefault "${config.home.homeDirectory}/Pictures/Wallpapers";

    home.activation.atlanticSettings = hm.dag.entryAfter [ "writeBoundary" ] ''
      run mkdir -p ${escapeShellArg (builtins.dirOf settingsTarget)}
      if [ ! -e ${escapeShellArg settingsTarget} ]; then
        run install -m 0644 ${settingsFile} ${escapeShellArg settingsTarget}
      fi
    '';

    systemd.user.services.atlantic = mkIf cfg.systemd.enable {
      Unit = {
        Description = "atlantic shell daemon";
        After = [ cfg.systemd.target ];
        PartOf = [ cfg.systemd.target ];
        X-Restart-Triggers = [ "${settingsFile}" ];
      };

      Service = {
        ExecStart = "${cfg.package}/bin/atlantic start";
        Restart = "on-failure";
        KillMode = "mixed";
        TimeoutStopSec = "5s";
        Environment = mapAttrsToList (n: v: "${n}=${v}") cfg.systemd.environment;
      };

      Install.WantedBy = [ cfg.systemd.target ];
    };
  };
}
