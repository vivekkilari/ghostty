{nixpkgs}: let
  # mkTest does nothing special right now, its just a wrapper around
  # runNixOSTest, but it could be extended in the future so I pulled it out.
  mkTest = path:
    nixpkgs.testers.runNixOSTest {
      imports = [
        path
      ];
    };
in {
  basic = mkTest ./basic.nix;
  gnome = mkTest ./gnome.nix;
  i3 = mkTest ./i3.nix;
}
