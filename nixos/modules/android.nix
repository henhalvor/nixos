{
  config,
  pkgs,
  userSettings,
  ...
}: {
  # Enable ADB system-wide with udev rules for unprivileged access
  programs.adb.enable = true;

  # Add user to necessary groups for Android development
  users.users.${userSettings.username}.extraGroups = [
    "adbusers" # Required for adb device access
    "kvm" # Required for hardware acceleration in emulators
  ];
}
