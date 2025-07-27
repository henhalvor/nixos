# AMD GPU Power Management Freakout Issue Documentation

## Issue Summary

**Problem**: System randomly enters suspend/sleep state while actively in use, occurring sporadically every 20 minutes to 2 hours.

**Root Cause**: Conflicting AMD GPU kernel parameters causing the System Management Unit (SMU) to malfunction and trigger emergency suspend as a hardware protection mechanism.

**System Configuration**:
- OS: NixOS
- CPU: AMD Ryzen 7900 (with integrated graphics)
- GPU: Discrete AMD graphics card
- Desktop Environment: Sway (Wayland)

## Technical Background

### What is the SMU?
The System Management Unit (SMU) is AMD's power management controller that handles:
- Dynamic power scaling (DPM)
- Thermal management
- Voltage regulation
- Power gating for GPU components

When the SMU receives conflicting instructions or encounters unresolvable power states, it can trigger system-wide suspend as a protective measure.

### The Conflicting Configuration

The issue was caused by contradictory kernel parameters across two NixOS configuration files:

**In `amd-graphics.nix`:**
```nix
boot.kernelParams = [
  "amdgpu.ppfeaturemask=0xffffffff"  # Enables ALL power management features
  # ... other params
];
```

**In main system configuration:**
```nix
boot.kernelParams = [
  "amdgpu.dpm=0"  # Disables dynamic power management
  # ... other params
];
```

This created a contradiction where the GPU was told to:
1. Enable all power management features (`ppfeaturemask=0xffffffff`)
2. Disable dynamic power management (`dpm=0`)

## Diagnostic Symptoms

### Primary Log Signature
The main indicator of this issue is massive spam in kernel logs:

```
amdgpu 0000:0c:00.0: SMU uninitialized but power gate requested for 6!
WARNING: CPU: X PID: X at drivers/gpu/drm/amd/amdgpu/../pm/swsmu/amdgpu_smu.c:365 smu_dpm_set_power_gate
```

### How to Check for This Issue

**1. Check kernel logs for SMU errors:**
```bash
journalctl -b | grep -i "SMU uninitialized\|smu_dpm_set_power_gate"
```

**2. Monitor for power management warnings:**
```bash
journalctl -b | grep -i "amdgpu.*power\|amdgpu.*dpm"
```

**3. Check for suspend events during active use:**
```bash
journalctl -b | grep -E "(Suspending|suspend entered|systemctl suspend)"
```

**4. Verify current kernel parameters:**
```bash
cat /proc/cmdline | grep -o "amdgpu\.[^[:space:]]*"
```

## The Solution

### Step 1: Remove Conflicting Parameters

**Updated `amd-graphics.nix`:**
```nix
boot.kernelParams = [
  # REMOVED: "amdgpu.ppfeaturemask=0xffffffff" 
  "radeon.si_support=0"
  "radeon.cik_support=0" 
  "amdgpu.si_support=1"
  "amdgpu.cik_support=1"
  "module_blacklist=nvidia,nvidia_drm,nvidia_modeset,nvidia_uvm"
];
```

**Updated main system configuration:**
```nix
boot.kernelParams = [ 
  "mem_sleep_default=s2idle"
  "amdgpu.dpm=0"          # Keep this since it prevents graphics crashes
  "amdgpu.runpm=0"        # Also disable runtime power management
];
```

### Step 2: Apply Changes
```bash
sudo nixos-rebuild switch
```

### Step 3: Reboot
A full reboot is required for kernel parameter changes to take effect.

## Verification and Testing

### Immediate Checks (After Reboot)

**1. Verify kernel parameters are applied correctly:**
```bash
cat /proc/cmdline | grep amdgpu
```
Expected output should show:
- `amdgpu.dpm=0`
- `amdgpu.runpm=0`
- NO `amdgpu.ppfeaturemask=0xffffffff`

**2. Check for immediate SMU errors:**
```bash
journalctl -b | grep -i "SMU uninitialized" | wc -l
```
Should return `0` or a very low number.

**3. Monitor power management state:**
```bash
# Check if DPM is properly disabled
find /sys/class/drm/card*/device/power_dpm_state 2>/dev/null | xargs cat
```

### Ongoing Monitoring

**1. Set up continuous monitoring for SMU errors:**
```bash
# Run this in a terminal and leave it open
journalctl -f | grep -i "SMU uninitialized\|smu_dpm_set_power_gate"
```

**2. Test system stability:**
- Use the system normally for extended periods
- Run GPU-intensive applications
- Monitor for unexpected suspend events

**3. Daily log check:**
```bash
# Check yesterday's logs for issues
journalctl --since yesterday | grep -i "SMU uninitialized" | wc -l
```

### Success Indicators

**✅ Issue is resolved when:**
- No SMU uninitialized errors in logs
- System stays awake during active use
- No unexpected suspend events
- GPU functions normally without crashes

**❌ Issue persists if:**
- SMU errors continue appearing in logs
- Random suspend events still occur
- New power management related errors appear

## Alternative Solutions (If Issue Persists)

If the primary solution doesn't work, try these progressive approaches:

### Option 1: More Aggressive Power Management Disable
```nix
boot.kernelParams = [
  "mem_sleep_default=s2idle"
  "amdgpu.dpm=0"
  "amdgpu.runpm=0"
  "amdgpu.bapm=0"          # Disable bidirectional application power management
];
```

### Option 2: Different Power Feature Mask
```nix
boot.kernelParams = [
  "mem_sleep_default=s2idle"
  "amdgpu.ppfeaturemask=0xfffffbff"  # Disable specific problematic features
  "amdgpu.gpu_recovery=1"
];
```

### Option 3: Firmware-level Fixes
```nix
hardware.firmware = [ 
  pkgs.linux-firmware 
  pkgs.amdgpu-pro  # If available
];
```

## Understanding the Fix

### Why `amdgpu.dpm=0` was needed
The user originally added this parameter because their system experienced graphics crashes without it. This suggests potential instability in AMD's dynamic power management for their specific hardware configuration.

### Why removing `ppfeaturemask=0xffffffff` fixed the issue
This parameter enables ALL power management features, directly conflicting with `dpm=0`. The SMU couldn't reconcile these contradictory instructions, leading to power state confusion and protective suspend activation.

### The role of `amdgpu.runpm=0`
Runtime power management can still cause issues even with DPM disabled. This parameter provides additional protection against power-related conflicts.

## Related NixOS Considerations

### Hardware Configuration
```nix
hardware.graphics = {
  enable = true;
  extraPackages = with pkgs; [
    vulkan-loader
    mesa
    libva
    # Avoid power-management-heavy packages if issues persist
  ];
};
```

### Swayidle Configuration
Since the user originally suspected swayidle, their configuration should remain simple:
```nix
services.swayidle = {
  enable = true;
  timeouts = [
    {
      timeout = 180;
      command = "${pkgs.swaylock}/bin/swaylock -fF";
    }
    # Avoid systemctl suspend - use monitor power off instead
    {
      timeout = 300;
      command = "swaymsg 'output * power off'";
    }
  ];
};
```

## Preventive Measures

1. **Always check for conflicting kernel parameters** when multiple AMD GPU configurations exist
2. **Test kernel parameter changes incrementally** rather than applying many at once
3. **Monitor logs immediately after changes** to catch issues early
4. **Keep power management settings consistent** across all configuration files
5. **Document hardware-specific workarounds** for future reference

---

**Last Updated**: July 2025  
**NixOS Version**: 25.05  
**Kernel Version**: 6.12.30