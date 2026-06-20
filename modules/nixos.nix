{
  config,
  lib,
  pkgs,
  ...
}:

with lib;

let
  cfg = config.services.youtarr;
  configFile = (pkgs.formats.json { }).generate "youtarr-config.json" cfg.settings;

  youtarr-client = pkgs.callPackage ../pkgs/youtarr-client.nix { };
  youtarrPkg = pkgs.callPackage ../pkgs/youtarr.nix {
    inherit youtarr-client;
    ffmpeg = cfg.ffmpegPackage;
    yt-dlp = cfg.ytdlpPackage;
    atomicparsley = cfg.atomicparsleyPackage;
    apprise = cfg.apprisePackage;
  };
in
{
  options.services.youtarr = {
    enable = mkEnableOption "Youtarr YouTube DVR service";

    package = mkOption {
      type = types.package;
      default = youtarrPkg;
      defaultText = literalExpression "pkgs.callPackage ../pkgs/youtarr.nix { }";
      description = "The Youtarr package to use.";
    };

    ffmpegPackage = mkOption {
      type = types.package;
      default = pkgs.ffmpeg;
      defaultText = literalExpression "pkgs.ffmpeg";
      description = "The ffmpeg package to use.";
    };

    ytdlpPackage = mkOption {
      type = types.package;
      default = pkgs.yt-dlp;
      defaultText = literalExpression "pkgs.yt-dlp";
      description = "The yt-dlp package to use.";
    };

    atomicparsleyPackage = mkOption {
      type = types.package;
      default = pkgs.atomicparsley;
      defaultText = literalExpression "pkgs.atomicparsley";
      description = "The atomicparsley package to use.";
    };

    apprisePackage = mkOption {
      type = types.package;
      default = pkgs.apprise;
      defaultText = literalExpression "pkgs.apprise";
      description = "The apprise package to use.";
    };

    port = mkOption {
      type = types.port;
      default = 3011;
      description = "Port the Express backend server listens on.";
    };

    host = mkOption {
      type = types.str;
      default = "127.0.0.1";
      description = "Host IP address the backend server binds to.";
    };

    dataDir = mkOption {
      type = types.str;
      default = "/var/lib/youtarr";
      description = "Storage directory for configurations and cache.";
    };

    youtubeOutputDir = mkOption {
      type = types.path;
      default = "/var/lib/youtarr/downloads";
      description = "Directory where downloaded videos are saved.";
    };

    database = {
      host = mkOption {
        type = types.str;
        default = "127.0.0.1";
        description = "Database host name or IP address.";
      };
      port = mkOption {
        type = types.port;
        default = 3306;
        description = "Database port.";
      };
      user = mkOption {
        type = types.str;
        default = "youtarr";
        description = "Database username.";
      };
      name = mkOption {
        type = types.str;
        default = "youtarr";
        description = "Database name.";
      };
      passwordFile = mkOption {
        type = types.nullOr types.path;
        default = null;
        description = ''
          Path to a file containing the database password.
          The file must contain a line like:
          <programlisting>DB_PASSWORD=your_password_here</programlisting>
        '';
      };
    };

    auth = {
      enable = mkOption {
        type = types.bool;
        default = true;
        description = "Enable built-in authentication.";
      };
      presetUsername = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = "Pre-configured admin username for automated deployments.";
      };
      presetPasswordFile = mkOption {
        type = types.nullOr types.path;
        default = null;
        description = ''
          Path to a file containing the preset admin password.
          The file must contain a line like:
          AUTH_PRESET_PASSWORD=your_admin_password
        '';
      };
    };

    environmentFile = mkOption {
      type = types.nullOr types.path;
      default = null;
      description = "Path to an environment file containing additional custom environment variables.";
    };

    settings = import ./settings.nix { inherit lib pkgs; };
  };

  config = mkIf cfg.enable {
    systemd.services.youtarr = {
      description = "Youtarr DVR daemon";
      after = [ "network.target" ];
      wantedBy = [ "multi-user.target" ];

      serviceConfig = {
        Type = "simple";
        User = "youtarr";
        Group = "youtarr";
        StateDirectory = "youtarr";
        WorkingDirectory = cfg.dataDir;

        ExecStartPre = pkgs.writeShellScript "youtarr-pre-start" ''
          mkdir -p ${cfg.dataDir}/config
          mkdir -p ${cfg.youtubeOutputDir}
          cp -f ${configFile} ${cfg.dataDir}/config/config.json
          chmod 640 ${cfg.dataDir}/config/config.json
        '';

        ExecStart = "${cfg.package}/bin/youtarr";
        EnvironmentFile =
          (lib.optional (cfg.database.passwordFile != null) cfg.database.passwordFile)
          ++ (lib.optional (cfg.auth.presetPasswordFile != null) cfg.auth.presetPasswordFile)
          ++ (lib.optional (cfg.environmentFile != null) cfg.environmentFile);
        Restart = "on-failure";
        RestartSec = "5s";
      };

      environment = {
        PORT = toString cfg.port;
        HOST = cfg.host;
        DB_HOST = cfg.database.host;
        DB_PORT = toString cfg.database.port;
        DB_USER = cfg.database.user;
        DB_NAME = cfg.database.name;
        YOUTUBE_OUTPUT_DIR = cfg.youtubeOutputDir;
        YOUTARR_CONFIG_PATH = "${cfg.dataDir}/config/config.json";
        DATA_PATH = "${cfg.dataDir}/data";
        AUTH_ENABLED = lib.boolToString cfg.auth.enable;
      }
      // lib.optionalAttrs (cfg.auth.presetUsername != null) {
        AUTH_PRESET_USERNAME = cfg.auth.presetUsername;
      };
    };

    users.users.youtarr = {
      isSystemUser = true;
      group = "youtarr";
      description = "Youtarr daemon user";
      home = cfg.dataDir;
    };
    users.groups.youtarr = { };
  };
}
