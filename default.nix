{
  pkgs ? import <nixpkgs> { },
  system ? builtins.currentSystem,
}:
let
  inherit (pkgs) lib;
  sources = builtins.fromJSON (lib.strings.fileContents ./sources.json);
  mirrors = builtins.fromJSON (lib.strings.fileContents ./mirrors.json);

  # mkBinaryInstall makes a derivation that installs Zig from a binary.
  mkBinaryInstall =
    {
      url,
      version,
      sha256,
    }:
    let
      tarballName = lib.lists.last (lib.strings.split "/" url);
      srcIsFromZigLang = lib.strings.hasPrefix "https://ziglang.org/" url;
      urlFromMirrors = map (mirror: "${mirror}/${tarballName}?source=nix-zig-overlay") mirrors;
      urls = if srcIsFromZigLang then urlFromMirrors ++ [ url ] else [ url ];
    in
    pkgs.stdenv.mkDerivation (finalAttrs: {
      inherit version;

      pname = "zig";
      src = pkgs.fetchurl { inherit urls sha256; };
      dontConfigure = true;
      dontBuild = true;
      dontFixup = true;
      installPhase = ''
        mkdir -p $out/{doc,bin,lib}
        [ -d docs ] && cp -r docs/* $out/doc
        [ -d doc ] && cp -r doc/* $out/doc
        cp -r lib/* $out/lib
        cp zig $out/bin/zig
      '';

      propagatedNativeBuildInputs = lib.optionals pkgs.stdenv.hostPlatform.isDarwin [ pkgs.xcbuild ];

      env = {
        zig_default_cpu_flag = "-Dcpu=baseline";
        zig_default_optimize_flag = "--release=safe";
      };

      setupHook = ./setup-hook.sh;

      passthru = import ./passthru.nix {
        inherit (pkgs)
          stdenv
          callPackage
          wrapCCWith
          wrapBintoolsWith
          overrideCC
          ;
        zig = finalAttrs.finalPackage;
      };

      meta = {
        description = "General-purpose programming language and toolchain for maintaining robust, optimal, and reusable software";
        homepage = "https://ziglang.org/";
        changelog = "https://ziglang.org/download/${version}/release-notes.html";
        license = lib.licenses.mit;
        maintainers = with lib.maintainers; [ andrewrk ];
        teams = [ lib.teams.zig ];
        mainProgram = "zig";
        platforms = lib.platforms.unix;
      };
    });

  # The packages that are tagged releases
  taggedPackages =
    lib.attrsets.mapAttrs (k: v: mkBinaryInstall { inherit (v.${system}) version url sha256; })
      (
        lib.attrsets.filterAttrs (
          k: v: (builtins.hasAttr system v) && (v.${system}.url != null) && (v.${system}.sha256 != null)
        ) (removeAttrs sources [ "master" ])
      );

  # The master packages
  masterPackages =
    lib.attrsets.mapAttrs'
      (
        k: v:
        lib.attrsets.nameValuePair (if k == "latest" then "master" else ("master-" + k)) (mkBinaryInstall {
          inherit (v.${system}) version url sha256;
        })
      )
      (
        lib.attrsets.filterAttrs (
          k: v: (builtins.hasAttr system v) && (v.${system}.url != null)
        ) sources.master
      );

  # This determines the latest /released/ version.
  latest = lib.lists.last (
    builtins.sort (x: y: (builtins.compareVersions x y) < 0) (builtins.attrNames taggedPackages)
  );
in
# We want the packages but also add a "default" that just points to the
# latest released version.
taggedPackages // masterPackages // { "default" = taggedPackages.${latest}; }
