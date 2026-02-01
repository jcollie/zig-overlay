{
  description = "Zig compiler binaries.";

  inputs = {
    nixpkgs.url = "https://channels.nixos.org/nixos-unstable/nixexprs.tar.xz";
  };

  outputs =
    {
      self,
      nixpkgs,
      ...
    }:
    let
      inherit (nixpkgs) lib;
      systems = [
        "x86_64-linux"
        "aarch64-linux"
        "x86_64-darwin"
        "aarch64-darwin"
      ];
      eachSystem = lib.genAttrs systems;
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
      packages = lib.mapAttrs (system: pkgs: import ./default.nix { inherit system pkgs; }) pkgsFor;

      # "Apps" so that `nix run` works. If you run `nix run .` then
      # this will use the latest default.
      apps = eachSystem (system: {
        default = self.apps.${system}.zig;
        zig = {
          type = "app";
          program = "${lib.getExe self.packages.${system}.default}";
          meta = {
            description = "Run the latest tagged Zig";
          };
        };
      });

      # nix fmt
      formatter = lib.mapAttrs (_: pkgs: pkgs.nixpkgs-fmt) pkgsFor;

      devShells = lib.mapAttrs (system: pkgs: {
        default = pkgs.mkShell {
          nativeBuildInputs = with pkgs; [
            curl
            jq
            minisign
          ];
        };

      }) pkgsFor;

      # Overlay that can be imported so you can access the packages
      # using zigpkgs.master or whatever you'd like.
      overlays.default = final: prev: {
        zigpkgs = self.packages.${prev.stdenv.hostPlatform.system};
      };

      # Templates for use with nix flake init
      templates.compiler-dev = {
        path = ./templates/compiler-dev;
        description = "A development environment for Zig compiler development.";
      };

      templates.init = {
        path = ./templates/init;
        description = "A basic, empty development environment.";
      };
    };
}
