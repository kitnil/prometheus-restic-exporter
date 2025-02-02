{
  description = "prometheus exporter for restic backups";

  inputs = { flake-utils.url = "github:numtide/flake-utils"; };

  outputs = { self, nixpkgs, flake-utils, ... }:

    {
      nixosModules.default = self.nixosModules.restic-exporter;

      nixosModules.restic-exporter = { lib, pkgs, config, ... }:
        with lib;

        let cfg = config.services.restic-exporter;
        in
        {

          options.services.restic-exporter = {

            enable = mkEnableOption "restic-exporter";

            port = mkOption {
              type = types.str;
              default = "8080";
              description = "Port under which restic-exporter is accessible.";
            };

            address = mkOption {
              type = types.str;
              default = "localhost";
              example = "127.0.0.1";
              description = "Address under which restic-exporter is accessible.";
            };

            targets = mkOption {
              type = types.listOf types.str;
              default = [ ];
              example = [ "server01" "server02" ];
              description = "hosts to monitor in backup repository";
            };

            environmentFile = mkOption {
              type = types.nullOr types.path;
              default = null;
              description = ''
                Environment file (see <literal>systemd.exec(5)</literal>
                "EnvironmentFile=" section for the syntax) to define extra variables
                for the exporter
              '';
            };

            user = mkOption {
              type = types.str;
              default = "restic-exporter";
              description = "User account under which restic-exporter runs.";
            };

            group = mkOption {
              type = types.str;
              default = "restic-exporter";
              description = "Group under which restic-exporter runs.";
            };

          };

          config = mkIf cfg.enable {

            systemd.services.restic-exporter = {
              description = "A restic metrics exporter";
              wantedBy = [ "multi-user.target" ];
              serviceConfig = mkMerge [{
                User = cfg.user;
                Group = cfg.group;
                ExecStart = "${self.packages."${pkgs.system}".default}/bin/restic-exporter";
                Restart = "on-failure";
                EnvironmentFile = mkIf (cfg.environmentFile != null) [ cfg.environmentFile ];
                Environment = [
                  "RESTIC_EXPORTER_BIN=${pkgs.restic}/bin/restic"
                  "RESTIC_EXPORTER_PORT=${cfg.port}"
                  "RESTIC_EXPORTER_ADDRESS=${cfg.address}"
                ];
              }];
            };

            users.users = mkIf (cfg.user == "restic-exporter") {
              restic-exporter = {
                isSystemUser = true;
                group = cfg.group;
                description = "restic-exporter system user";
              };
            };

            users.groups =
              mkIf (cfg.group == "restic-exporter") { restic-exporter = { }; };

          };
          meta.maintainers = with lib.maintainers; [ pinpox ];
        };
    }

    //

    flake-utils.lib.eachDefaultSystem (system:
      let pkgs = nixpkgs.legacyPackages.${system};
      in
      rec {

        formatter = pkgs.nixpkgs-fmt;
        packages = flake-utils.lib.flattenTree rec {

          default = pkgs.buildGoModule rec {
            pname = "restic-exporter";
            version = "1.0.0";
            src = self;
            vendorSha256 = "sha256-WtO+3uH6H2um6pcdqhU/Yaw6HDNkz1XGjslGQphyMiA=";
            installCheckPhase = ''
              runHook preCheck
              $out/bin/restic-exporter -h
              runHook postCheck
            '';
            # preConfigure phase to compile a statically linked executable
            preConfigure = ''
              export CGO_ENABLED=0
              export GOOS=linux
              export GOARCH=amd64
            '';
            ldflags = [ "-s" ]; # stripped binary
            doCheck = true;
            meta = with pkgs.lib; {
              description = "restic prometheus exporter";
              homepage = "https://github.com/pinpox/restic-exporter";
              platforms = platforms.unix;
              maintainers = with maintainers; [ pinpox ];
            };
          };

        };
      });
}
