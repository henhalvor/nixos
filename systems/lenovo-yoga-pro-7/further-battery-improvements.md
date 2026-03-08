# Further battery improvements for Lenovo Yoga Pro 7

## Goal
Improve battery life on the Lenovo Yoga Pro 7 beyond the current `battery.nix` setup, starting with undervolt-oriented tuning while keeping a fallback path for AMD power-limit tuning if true undervolting is not available on this hardware.

## Current state
- `systems/lenovo-yoga-pro-7/configuration.nix` imports both `./battery.nix` and `./amd-graphics.nix`, so the laptop already has a dedicated machine-specific power configuration.
- `systems/lenovo-yoga-pro-7/battery.nix` currently:
  - enables `powerManagement.powertop`
  - disables `power-profiles-daemon` and `thermald`
  - enables `services.auto-cpufreq`
  - applies aggressive AMDGPU udev power rules
- `systems/lenovo-yoga-pro-7/amd-graphics.nix` already sets AMDGPU runtime power-management kernel parameters and video-acceleration settings.
- There is no existing undervolt package, no dedicated runtime tuning service, and no validation or rollback flow for experimental battery tuning.

## Key constraints
- Do not assume that true voltage-offset undervolting is supported. Many modern Lenovo AMD laptops lock this down in firmware or do not expose it cleanly to Linux.
- Keep a single owner for power policy. The current setup already favors `auto-cpufreq` + `powertop`, so avoid adding conflicting tools such as TLP or re-enabling `power-profiles-daemon`.
- Prefer conservative, reversible changes over aggressive tuning that could harm stability, suspend/resume, or thermals.

## Implementation plan

### 1. Audit hardware and firmware capabilities
Confirm the exact CPU and firmware path for this Yoga Pro 7 and determine whether true undervolting is exposed at all.

Tasks:
- identify the exact APU model and confirm whether the commented `7840HS` assumption is still correct
- check BIOS/UEFI options for voltage control or advanced power tuning
- verify whether Linux exposes any supported undervolt interface for this machine
- determine whether the practical path is a real voltage offset or an SMU/power-limit tuning workflow

Success criteria:
- a clear yes/no answer on whether true undervolting is possible on this laptop
- a documented fallback decision if the firmware blocks voltage offsets

### 2. Choose the control path
Select one implementation path and avoid mixing strategies.

Preferred decision tree:
1. If true undervolting is supported, implement a conservative declarative undervolt path.
2. If it is not supported, use the approved fallback path based on AMD mobile power-limit tuning.

Fallback candidates:
- `amd_pstate=active` if it is not already enabled elsewhere in the final merged config
- platform profile refinement
- `ryzenadj`-style STAPM/PPT/TDC/temperature tuning if the hardware and package support it cleanly

### 3. Align the existing power stack
Before adding new tuning, reconcile the current power-management layers so that only one layer controls each class of settings.

Review areas:
- `services.auto-cpufreq` battery and charger settings
- `powerManagement.powertop.enable`
- AMDGPU udev rules in `battery.nix`
- AMDGPU kernel parameters in `amd-graphics.nix`
- the commented `amd_pstate` and sysctl ideas in `battery.nix`

Goal:
- avoid overlapping governors, duplicated platform-profile changes, or settings that fight each other at runtime

### 4. Integrate runtime tuning declaratively
Add the chosen mechanism to the NixOS config in a way that is easy to understand and easy to roll back.

Likely implementation options:
- extend `systems/lenovo-yoga-pro-7/battery.nix` directly if the logic stays small
- move runtime tuning into a small helper script or dedicated module if service logic grows
- use a `systemd` oneshot service or a profile-aware service only if the selected tool requires runtime application

Requirements:
- define clear AC vs battery behavior
- keep defaults conservative
- make the feature easy to disable quickly if it causes instability

### 5. Validate battery gains and safety
Do not treat the change as complete until the new settings are measured and shown to be stable.

Validation checklist:
- build the system configuration successfully
- measure idle package power and discharge rate before and after the change
- watch CPU temperature and fan behavior under light and moderate load
- verify suspend/resume stability
- verify no regressions in graphics, video acceleration, or charging behavior
- keep rollback instructions simple and explicit

Suggested runtime checks:
- `powertop`
- `acpi`
- `btop`
- any additional tool required by the chosen undervolt or power-limit path

## Todo list
- `capability-audit`: Confirm whether true undervolting is actually exposed by the CPU, firmware, and Linux interfaces on this laptop.
- `choose-control-path`: Use a true undervolt path if supported; otherwise proceed with the approved AMD power-limit fallback.
- `align-existing-tunables`: Reconcile the current `auto-cpufreq`, `powertop`, AMDGPU rules, and kernel settings to avoid conflicts.
- `integrate-runtime-tuning`: Add the selected mechanism declaratively in `battery.nix`, with clear AC/BAT behavior.
- `validate-and-document`: Verify the config builds, measure results, and document rollback and stability checks.

## Notes
- The fallback AMD power-limit path is intentionally in scope because true undervolting may be unavailable on this platform.
- Battery gains are not worth random freezes, suspend issues, or degraded hardware behavior.
- The most likely implementation surface is `systems/lenovo-yoga-pro-7/battery.nix`, with a helper script or small module only if runtime logic becomes too large.
