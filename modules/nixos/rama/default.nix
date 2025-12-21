{
  config,
  lib,
  pkgs,
  ...
}:

let
  inherit (lib)
    mkEnableOption
    mkOption
    mkIf
    mkMerge
    types
    ;
  inherit (lib.generators) toYAML;

  cfg = config.services.rama;

  availableBackupProviders = cfg.package.availableBackupProviders;

  ramaPackage = cfg.package.override (previous: {
    ramaDir = cfg.dataDir;
    backupProviders =
      previous.backupProviders
      ++ (lib.optional (lib.attrsets.hasAttrByPath [
        "backup"
        "s3"
      ] cfg) availableBackupProviders.s3);
  });

  backupType = types.attrTag {
    s3 = types.submodule {
      options = {
        targetBucket = mkOption {
          type = types.str;
          description = "S3 bucket reference for backups";
        };
      };
    };
  };

  options = {
    package = mkOption {
      type = types.package;
      default = pkgs.rama;
      defaultText = lib.literalExpression "pkgs.rama";
      description = "The Rama package to use";
    };

    user = mkOption {
      type = types.str;
      default = "rama";
      description = "User account under which Rama runs";
    };

    group = mkOption {
      type = types.str;
      default = "rama";
      description = "Group under which Rama runs";
    };

    dataDir = mkOption {
      type = types.path;
      default = "/var/lib/rama";
      description = "Directory for Rama data files";
    };

    logDir = mkOption {
      type = types.path;
      default = "/var/log/rama";
      description = "Directory for Rama log files";
    };

    settings = mkOption {
      type = types.attrsOf types.anything;
      default = { };
      description = ''
        Configuration settings for rama.yaml.

        Note that Rama configuration keys are dot separated and are all top level.
        You really need to define

          settings = { "conductor.host" = "localhost"; }

        And not
          settings = { conductor.host = "localhost"; }  ;

        (which would create a nested attribute set under 'conductor')

      '';
      example = lib.literalExpression ''
        {
          "conductor.host" = "localhost";
        }
      '';
    };

    backup = mkOption {
      type = types.nullOr backupType;
      default = null;
      description = ''
        Backup configuration with provider-specific settings.
        Currently only 's3' provider is supported.
      '';
      example = lib.literalExpression ''
        {
          s3.targetBucket = "my-backup-bucket";
        }
      '';
    };

    log4jExtraSettings = mkOption {
      type = types.lines;
      default = "";
      description = "Extra settings for log4j.properties that get appened";
    };

    finalLog4jSettings = mkOption {
      type = types.lines;
      readOnly = true;
      default = lib.concatStringsSep "\n" [
        (lib.readFile "${ramaPackage}/share/rama/log4j2.properties")
        cfg.log4jExtraSettings
      ];
      description = "Final settings for log4j.properties";
    };

    conductor = {
      enable = mkEnableOption "Rama conductor service";
    };

    supervisor = {
      enable = mkEnableOption "Rama supervisor service";
    };
  };
in
{
  options.services.rama = options;

  config = mkIf (cfg.conductor.enable || cfg.supervisor.enable) {
    users.users.${cfg.user} = {
      isSystemUser = true;
      group = cfg.group;
      description = "Rama service user";
      home = cfg.dataDir;
    };

    users.groups.${cfg.group} = { };

    # Recreate the directory structure that rama expects under cfg.dataDir
    systemd.tmpfiles.rules = [
      "d '${cfg.dataDir}' 0750 ${cfg.user} ${cfg.group} - -"
      "d '${cfg.logDir}' 0750 ${cfg.user} ${cfg.group} - -"
      "L+ '${cfg.dataDir}/rama' - - - - ${ramaPackage}/bin/rama"
      "L+ '${cfg.dataDir}/rama.yaml' - - - - /etc/rama/rama.yaml"
      "L+ '${cfg.dataDir}/rama/log4j2.properties' - - - - /etc/rama/rama/log4j2.properties"
      "L+ '${cfg.dataDir}/lib' - - - - ${ramaPackage}/share/rama/lib"
      "L+ '${cfg.dataDir}/rama.jar' - - - - ${ramaPackage}/share/rama/rama.jar"
      "L+ '${cfg.dataDir}/logs' - - - - ${cfg.logDir}"
    ];

    environment.etc."rama/rama.yaml" = mkIf (cfg.settings != { }) {
      text = toYAML { } cfg.settings;
      mode = "0644";
    };

    environment.etc."rama/log4j2.properties" = {
      text = lib.concatStringsSep "\n" [
        (lib.readFile "${ramaPackage}/share/rama/log4j2.properties")
        cfg.log4jExtraSettings
      ];
      mode = "0644";
    };

    systemd.services =
      let
        mkRamaService =
          { role }:
          {
            description = "Rama ${role} service";
            wantedBy = [ "multi-user.target" ];
            after = [ "network.target" ];

            serviceConfig = {
              Type = "simple";
              User = cfg.user;
              Group = cfg.group;
              Restart = "on-failure";
              RestartSec = "10s";
              ExecStart = "${ramaPackage}/bin/rama ${role}";
            };
          };
      in
      mkMerge [
        (mkIf cfg.conductor.enable {
          rama-conductor = mkRamaService { role = "conductor"; };
        })
        (mkIf cfg.supervisor.enable {
          rama-supervisor = mkRamaService { role = "supervisor"; };
        })
      ];
  };
}
