{ config, pkgs, userSettings, systemSettings, ... }:

{
  # Video drivers configuration
  services.xserver.videoDrivers = [ "amdgpu" ];  # Modern AMD GPUs use amdgpu driver

  # Environment variables for AMD graphics
  environment.sessionVariables = {
    # Hardware acceleration API support
    LIBVA_DRIVER_NAME = "radeonsi";  # For VA-API
    VDPAU_DRIVER = "radeonsi";       # For VDPAU
    
    # Wayland-specific settings (if using Wayland)
    WLR_RENDERER = "vulkan";         # Better performance on AMD
    
    # Optional: Use Vulkan by default for games
    AMD_VULKAN_ICD = "RADV";         # Use RADV Vulkan driver
  };

  # Graphics and Hardware Acceleration
  hardware = {
    graphics = {
      enable = true;
      
      extraPackages = with pkgs; [
        # Vulkan support
        vulkan-loader
        vulkan-validation-layers
        amdvlk                    # AMD's Vulkan implementation
        
        # OpenGL and VA-API support
        mesa                      # Main OpenGL implementation
        libva                     # Video Acceleration API
        
        # The correct package for Mesa VA-API drivers
        mesa.drivers              # Contains the VA-API drivers
        
        libva-utils              
        
        # VDPAU support
        vaapiVdpau               # VDPAU backend for VA-API
        libvdpau-va-gl           # OpenGL backend for VDPAU
        
        # ROCm (compute) support if needed
        rocmPackages.clr         # OpenCL runtime
      ];
      
      # 32-bit support (for Steam and other gaming applications)
      extraPackages32 = with pkgs.pkgsi686Linux; [
        # Vulkan 32-bit support
        vulkan-loader
        
        # OpenGL 32-bit support
        mesa
        mesa.drivers             # 32-bit drivers
        
        # Video acceleration 32-bit support
        libva
        vaapiVdpau
      ];
    };
    
    # Enable firmware for amdgpu if needed
    firmware = [ pkgs.linux-firmware ];
  };

  # Optional: For better performance with AMDGPU
  boot.kernelParams = [
    "amdgpu.ppfeaturemask=0xffffffff"  # Enables all power management features
    "radeon.si_support=0"              # Disable Southern Islands support
    "radeon.cik_support=0"             # Disable Sea Islands support
    "amdgpu.si_support=1"              # Enable Southern Islands support in amdgpu
    "amdgpu.cik_support=1"             # Enable Sea Islands support in amdgpu
  ];
}
