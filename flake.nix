# SPDX-FileCopyrightText: © 2022 Mitchell Hashimoto
# SPDX-License-Identifier: MIT

{
  description = "Zig compiler binaries.";

  inputs = {
    nixpkgs.url = "https://channels.nixos.org/nixos-unstable/nixexprs.tar.xz";
    zon2nix = {
      url = "github:jcollie/zon2nix?ref=v0.9.0";
      inputs = {
        nixpkgs.follows = "nixpkgs";
      };
    };
  };

  outputs =
    {
      self,
      nixpkgs,
      zon2nix,
      ...
    }:
    let
      inherit (nixpkgs) lib;
      # Every system that Zig publishes a binary for and nixpkgs can run as a
      # host. The update tool writes `nix/sources-<system>.nix` for exactly
      # these. x86_64-darwin is missing because nixpkgs has dropped it.
      systems = [
        "aarch64-darwin"
        "aarch64-linux"
        "armv7l-linux"
        "i686-linux"
        "loongarch64-linux"
        "powerpc64le-linux"
        "riscv64-linux"
        "s390x-linux"
        "x86_64-linux"
      ];
      eachSystem = lib.genAttrs systems;
      # The systems the update tool and the development shell are offered on.
      # Its dependencies are not all built for the less common systems above.
      eachToolSystem = lib.genAttrs [
        "aarch64-darwin"
        "aarch64-linux"
        "x86_64-linux"
      ];
      pkgsFor = eachSystem (
        system:
        import nixpkgs {
          inherit system;
        }
      );
    in
    {
      # The packages exported by the Flake:
      #  - default - latest /released/ version
      #  - <version> - tagged version
      #  - master - latest nightly (updated daily)
      #  - master-<date> - nightly by date
      packages = eachSystem (
        system:
        import ./nix/packages.nix {
          inherit lib system;
          pkgs = pkgsFor.${system};
        }
      );

      # "Apps" so that `nix run` works. If you run `nix run .` then
      # this will use the latest default.
      apps =
        lib.recursiveUpdate
          (eachSystem (system: {
            default = self.apps.${system}.zig;
            zig = {
              type = "app";
              program = "${lib.getExe self.packages.${system}.default}";
              meta = {
                description = "Run the latest tagged Zig";
              };
            };
          }))
          (
            eachToolSystem (system: {
              update = {
                type = "app";
                program = lib.getExe (
                  pkgsFor.${system}.callPackage ./update/package.nix { zig = pkgsFor.${system}.zig_0_16; }
                );
                meta = {
                  description = "Fetch the Zig release index and regenerate nix/sources-*.nix";
                };
              };
            })
          );

      devShells = eachToolSystem (
        system:
        let
          pkgs = pkgsFor.${system};
        in
        {
          default = pkgs.mkShell {
            nativeBuildInputs = [
              pkgs.pinact
              pkgs.pkg-config
              pkgs.reuse
              pkgs.sqlite-interactive
              pkgs.zig_0_16
              # zon2nix shells out to `zig env`, so give it the Zig the update
              # tool builds with rather than whatever is on the caller's PATH.
              (pkgs.symlinkJoin {
                name = "zon2nix";
                paths = [ zon2nix.packages.${system}.zon2nix ];
                nativeBuildInputs = [ pkgs.makeWrapper ];
                postBuild = ''
                  wrapProgram $out/bin/zon2nix \
                    --prefix PATH : ${lib.makeBinPath [ pkgs.zig_0_16 ]}
                '';
              })
            ];
          };
        }
      );

    };
}
