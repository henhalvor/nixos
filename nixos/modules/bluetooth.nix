
{ config, pkgs, userSettings, systemSettings, ... }:
{
hardware.bluetooth.enable = true;
services.blueman.enable = true;
}
