{
  name = "gnome";

  nodes.machine = {
    config,
    pkgs,
    ...
  }: {
    users.users.alice = {
      isNormalUser = true;
      password = "alice";
      extraGroups = ["wheel"];
      packages = with pkgs; [
        (pkgs.callPackage ../package.nix {})
      ];
    };

    # We need an XDG portal for various applications to work properly,
    # such as Flatpak applications.
    xdg.portal = {
      enable = true;
      extraPortals = [ pkgs.xdg-desktop-portal-gtk ];
      config.common.default = "*";
    };

    services.xserver = {
      enable = true;
      xkb.layout = "us";
      dpi = 220;

      desktopManager = {
        xterm.enable = false;
        wallpaper.mode = "fill";
      };

      displayManager = {
        defaultSession = "none+i3";
        lightdm.enable = true;
      };

      windowManager = {
        i3.enable = true;
      };
    };

    services.displayManager.autoLogin = {
      enable = true;
      user = "alice";
    };

    system.stateVersion = "24.11";
  };

  testScript = ''
    machine.wait_for_unit("default.target")
    machine.succeed("su -- alice -c 'which firefox'")
    machine.fail("su -- root -c 'which firefox'")
  '';
}
