# home/main-user.nix
{ config, lib, pkgs, inputs, username, ... }:

{
  home.username = username;
  home.homeDirectory = "/home/${username}";
  home.stateVersion = "26.05"; # never change after install

  # ---------------------------------------------------------------- ghostty
  programs.ghostty = {
    enable = true;
    settings = {
      font-family = "JetBrains Mono";
      font-size = 11;
      theme = "dark:catppuccin-mocha,light:catppuccin-latte";
      window-padding-x = 8;
      window-padding-y = 8;
    };
  };

  # ------------------------------------------------------------------- niri
  # Niri reads ~/.config/niri/config.kdl. Minimal but usable config:
  # noctalia provides the bar/launcher/lock/notifications, niri does the
  # tiling. Full reference: https://yalter.github.io/niri/Configuration
  xdg.configFile."niri/config.kdl".text = ''
    input {
        keyboard {
            xkb {
                layout "ch"
                variant "fr"   // Swiss-French — adjust if needed
            }
        }
        touchpad {
            tap
            natural-scroll
            dwt
        }
    }

    layout {
        gaps 8
        center-focused-column "never"
        default-column-width { proportion 0.5; }
        focus-ring {
            width 2
        }
    }

    prefer-no-csd

    hotkey-overlay {
        skip-at-startup
    }

    // Desktop shell: bar, notifications, launcher, lock screen, OSD
    spawn-at-startup "noctalia-shell"

    screenshot-path "~/Pictures/Screenshots/%Y-%m-%d %H-%M-%S.png"

    binds {
        Mod+Shift+Slash { show-hotkey-overlay; }

        // Apps
        Mod+Return { spawn "ghostty"; }
        Mod+B      { spawn "firefox"; }

        // Noctalia IPC
        Mod+Space       { spawn "noctalia-shell" "ipc" "call" "launcher" "toggle"; }
        Super+Alt+L     { spawn "noctalia-shell" "ipc" "call" "lockScreen" "toggle"; }
        Mod+N           { spawn "noctalia-shell" "ipc" "call" "notifications" "toggleHistory"; }

        // Media keys (handled by noctalia OSD via wpctl/brightnessctl)
        XF86AudioRaiseVolume allow-when-locked=true { spawn "noctalia-shell" "ipc" "call" "volume" "increase"; }
        XF86AudioLowerVolume allow-when-locked=true { spawn "noctalia-shell" "ipc" "call" "volume" "decrease"; }
        XF86AudioMute        allow-when-locked=true { spawn "noctalia-shell" "ipc" "call" "volume" "muteOutput"; }
        XF86MonBrightnessUp   allow-when-locked=true { spawn "noctalia-shell" "ipc" "call" "brightness" "increase"; }
        XF86MonBrightnessDown allow-when-locked=true { spawn "noctalia-shell" "ipc" "call" "brightness" "decrease"; }

        // Window management
        Mod+Q { close-window; }
        Mod+F { maximize-column; }
        Mod+Shift+F { fullscreen-window; }
        Mod+V { toggle-window-floating; }

        Mod+Left  { focus-column-left; }
        Mod+Right { focus-column-right; }
        Mod+Up    { focus-window-up; }
        Mod+Down  { focus-window-down; }
        Mod+Shift+Left  { move-column-left; }
        Mod+Shift+Right { move-column-right; }

        Mod+R { switch-preset-column-width; }
        Mod+Comma { consume-window-into-column; }
        Mod+Period { expel-window-from-column; }

        // Workspaces (niri workspaces are dynamic, per-output, vertical)
        Mod+Page_Up   { focus-workspace-up; }
        Mod+Page_Down { focus-workspace-down; }
        Mod+1 { focus-workspace 1; }
        Mod+2 { focus-workspace 2; }
        Mod+3 { focus-workspace 3; }
        Mod+4 { focus-workspace 4; }
        Mod+Shift+1 { move-column-to-workspace 1; }
        Mod+Shift+2 { move-column-to-workspace 2; }
        Mod+Shift+3 { move-column-to-workspace 3; }
        Mod+Shift+4 { move-column-to-workspace 4; }

        Print { screenshot; }
        Mod+Print { screenshot-window; }

        Mod+Shift+E { quit; }
        Mod+Shift+P { power-off-monitors; }
    }
  '';

  # ----------------------------------------------------------------- extras
  home.packages = with pkgs; [
    brightnessctl # backlight control used above
  ];

  programs.git = {
    enable = true;
    # userName = "Your Name";
    # userEmail = "you@example.org";
  };
}
