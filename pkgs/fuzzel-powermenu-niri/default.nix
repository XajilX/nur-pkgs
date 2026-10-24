{
  lib,
  writeTextFile,
  runtimeShell,
  fuzzel,
  swaylock,
  niri,
}:
writeTextFile {
  name = "fuzzel-powermenu";
  text = ''
    #! ${runtimeShell}
    SELECTION="$(printf "1 - Lock\n2 - Suspend\n3 - Log out\n4 - Reboot\n5 - Reboot to UEFI\n6 - Hard reboot\n7 - Hibernate\n8 - Shutdown" | ${lib.getExe fuzzel} --dmenu -l 8 -p "Power Menu: ")"

    case $SELECTION in
      *"Lock")
        ${swaylock};;
      *"Suspend")
        systemctl suspend;;
      *"Log out")
        ${lib.getExe niri} msg action quit;;
      *"Reboot")
        systemctl reboot;;
      *"Reboot to UEFI")
        systemctl reboot --firmware-setup;;
      *"Hard reboot")
        pkexec "echo b > /proc/sysrq-trigger";;
      *"Hibernate")
        systemctl hibernate;;
      *"Shutdown")
        systemctl poweroff;;
    esac
  '';
  executable = true;
  destination = "/bin/fuzzel-powermenu";
  meta = {
    description = "A small power menu implementation for niri WM, based on fuzzel";
    mainProgram = "fuzzel-powermenu";
    platform = [
      "aarch64-linux"
      "i686-linux"
      "x86_64-linux"
    ];
    license = "mit";
  };
}
