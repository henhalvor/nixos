╰─❯ bash post-crash.sh
=== POST-CRASH INVESTIGATION ===
Run this immediately after a crash/reboot to find the cause

1. CHECKING BOOT REASON:
 -4 ba4ab24cbd9f485eb391cd1f5e024a6f Thu 2025-07-31 18:59:15 CEST Thu 2025-07-31 19:04:05 CEST
 -3 a40e4fb350384184aa680313b05cef97 Thu 2025-07-31 19:04:49 CEST Thu 2025-07-31 19:07:01 CEST
 -2 4f3a5ac4c2ad452baece903e249eb076 Thu 2025-07-31 19:08:19 CEST Thu 2025-07-31 19:09:54 CEST
 -1 ad29c0df0dae493ea875a6e8e774a1b0 Thu 2025-07-31 19:10:31 CEST Thu 2025-07-31 19:11:15 CEST
  0 da63cabab58a4578951dd2fa2eaf4f75 Thu 2025-07-31 19:11:53 CEST Thu 2025-07-31 19:12:11 CEST

Previous boot log summary:
Jul 31 19:11:10 workstation kernel: amdgpu 0000:0c:00.0: amdgpu: GPU mode2 reset failed
Jul 31 19:11:10 workstation kernel: amdgpu 0000:0c:00.0: amdgpu: ASIC reset failed with error, -95 for drm dev, 0000:0c:00.0
Jul 31 19:11:10 workstation kernel: amdgpu 0000:0c:00.0: amdgpu: GPU reset(1) failed
Jul 31 19:11:10 workstation kernel: amdgpu 0000:0c:00.0: amdgpu: GPU reset end with ret = -95
Jul 31 19:11:10 workstation kernel: amdgpu 0000:0c:00.0: amdgpu: GPU Recovery Failed: -95
Jul 31 19:11:11 workstation cupsd[2262]: Saving subscriptions.conf...
Jul 31 19:11:12 workstation systemd[2846]: hyprpaper.service: Scheduled restart job, restart counter is at 9.
Jul 31 19:11:12 workstation systemd[2846]: Started Hyprland Wallpaper.
Jul 31 19:11:12 workstation hyprpaper[4438]: [LOG] Welcome to hyprpaper!
Jul 31 19:11:12 workstation hyprpaper[4438]: built from commit v0.7.5 ()
Jul 31 19:11:12 workstation hyprpaper[4438]: [CRITICAL] Cannot launch multiple instances of Hyprpaper at once!
Jul 31 19:11:12 workstation systemd[2846]: hyprpaper.service: Main process exited, code=exited, status=1/FAILURE
Jul 31 19:11:12 workstation systemd[2846]: hyprpaper.service: Failed with result 'exit-code'.
Jul 31 19:11:15 workstation systemd[2846]: hyprpaper.service: Scheduled restart job, restart counter is at 10.
Jul 31 19:11:15 workstation systemd[2846]: Started Hyprland Wallpaper.
Jul 31 19:11:15 workstation hyprpaper[4464]: [LOG] Welcome to hyprpaper!
Jul 31 19:11:15 workstation hyprpaper[4464]: built from commit v0.7.5 ()
Jul 31 19:11:15 workstation hyprpaper[4464]: [CRITICAL] Cannot launch multiple instances of Hyprpaper at once!
Jul 31 19:11:15 workstation systemd[2846]: hyprpaper.service: Main process exited, code=exited, status=1/FAILURE
Jul 31 19:11:15 workstation systemd[2846]: hyprpaper.service: Failed with result 'exit-code'.

2. KERNEL CRASHES/PANICS FROM PREVIOUS BOOT:
Jul 31 19:10:31 workstation kernel: simple-framebuffer simple-framebuffer.0: [drm] Registered 1 planes with drm panic
Jul 31 19:10:39 workstation dockerd[2040]: time="2025-07-31T19:10:39.417830124+02:00" level=info msg="skip loading plugin \"io.containerd.snapshotter.v1.aufs\"..." error="aufs is not supported (modprobe aufs failed: exit status 1 \"modprobe: FATAL: Module aufs not found in directory /run/booted-system/kernel-modules/lib/modules/6.12.40\\n\"): skip plugin" type=io.containerd.snapshotter.v1
Jul 31 19:10:39 workstation org.gnome.Shell.desktop[2311]: Errors from xkbcomp are not fatal to the X server
Jul 31 19:10:39 workstation org.gnome.Shell.desktop[2337]: Errors from xkbcomp are not fatal to the X server
Jul 31 19:10:43 workstation /nix/store/k6alrqgjgwxykrjylzyzgc9xnyprszmc-gdm-48.0/libexec/gdm-wayland-session[3019]: Errors from xkbcomp are not fatal to the X server
Jul 31 19:10:43 workstation /nix/store/k6alrqgjgwxykrjylzyzgc9xnyprszmc-gdm-48.0/libexec/gdm-wayland-session[3021]: Errors from xkbcomp are not fatal to the X server

3. AMD GPU CRASHES FROM PREVIOUS BOOT:
Jul 31 19:10:31 workstation kernel: Command line: initrd=\EFI\nixos\lqy6vj39mji5q3b0vqpn4kkpqalavhx3-initrd-linux-6.12.40-initrd.efi init=/nix/store/vaw4mjhzw3wlci6gc8krhvq7xkdrffwq-nixos-system-workstation-25.05.20250729.1f08a4d/init radeon.si_support=0 radeon.cik_support=0 amdgpu.si_support=1 amdgpu.cik_support=1 module_blacklist=nvidia,nvidia_drm,nvidia_modeset,nvidia_uvm amdgpu.dpm=0 amdgpu.runpm=0 amdgpu.bapm=0 amdgpu.ppfeaturemask=0x0 amdgpu.noretry=1 amdgpu.lockup_timeout=0 mem_sleep_default=s2idle usbcore.old_scheme_first=1 usbcore.use_both_schemes=1 usbcore.initial_descriptor_timeout=2000 usb-storage.delay_use=3 usbhid.mousepoll=0 usbcore.autosuspend=-1 usb_core.autosuspend=-1 xhci_hcd.quirks=0x0008 loglevel=4 lsm=landlock,yama,bpf
Jul 31 19:10:31 workstation kernel: Kernel command line: initrd=\EFI\nixos\lqy6vj39mji5q3b0vqpn4kkpqalavhx3-initrd-linux-6.12.40-initrd.efi init=/nix/store/vaw4mjhzw3wlci6gc8krhvq7xkdrffwq-nixos-system-workstation-25.05.20250729.1f08a4d/init radeon.si_support=0 radeon.cik_support=0 amdgpu.si_support=1 amdgpu.cik_support=1 module_blacklist=nvidia,nvidia_drm,nvidia_modeset,nvidia_uvm amdgpu.dpm=0 amdgpu.runpm=0 amdgpu.bapm=0 amdgpu.ppfeaturemask=0x0 amdgpu.noretry=1 amdgpu.lockup_timeout=0 mem_sleep_default=s2idle usbcore.old_scheme_first=1 usbcore.use_both_schemes=1 usbcore.initial_descriptor_timeout=2000 usb-storage.delay_use=3 usbhid.mousepoll=0 usbcore.autosuspend=-1 usb_core.autosuspend=-1 xhci_hcd.quirks=0x0008 loglevel=4 lsm=landlock,yama,bpf
Jul 31 19:10:42 workstation kernel: amdgpu 0000:0c:00.0: [drm] REG_WAIT timeout 1us * 100 tries - dcn31_program_compbuf_size line:141
Jul 31 19:11:10 workstation kernel: amdgpu 0000:0c:00.0: amdgpu: ring gfx_0.1.0 timeout, signaled seq=2506, emitted seq=2509
Jul 31 19:11:10 workstation kernel: amdgpu 0000:0c:00.0: amdgpu: GPU reset begin!
Jul 31 19:11:10 workstation kernel: amdgpu 0000:0c:00.0: amdgpu: GPU pre asic reset failed with err, -95 for drm dev, 0000:0c:00.0 
Jul 31 19:11:10 workstation kernel: amdgpu 0000:0c:00.0: amdgpu: MODE2 reset
Jul 31 19:11:10 workstation kernel: amdgpu 0000:0c:00.0: amdgpu: GPU mode2 reset failed
Jul 31 19:11:10 workstation kernel: amdgpu 0000:0c:00.0: amdgpu: ASIC reset failed with error, -95 for drm dev, 0000:0c:00.0
Jul 31 19:11:10 workstation kernel: amdgpu 0000:0c:00.0: amdgpu: GPU reset(1) failed
Jul 31 19:11:10 workstation kernel: amdgpu 0000:0c:00.0: amdgpu: GPU reset end with ret = -95
Jul 31 19:11:10 workstation kernel: amdgpu 0000:0c:00.0: amdgpu: GPU Recovery Failed: -95

4. POWER MANAGEMENT CRASHES:

5. HYPRLAND CRASHES:

6. MEMORY/HARDWARE ISSUES:
Jul 31 19:10:31 workstation systemd[1]: Listening on Userspace Out-Of-Memory (OOM) Killer Socket.
Jul 31 19:10:31 workstation systemd[1]: Starting Userspace Out-Of-Memory (OOM) Killer...
Jul 31 19:10:31 workstation systemd[1]: Started Userspace Out-Of-Memory (OOM) Killer.
Jul 31 19:10:31 workstation systemd-oomd[789]: No swap; memory pressure usage will be degraded
Jul 31 19:10:31 workstation kernel: MCE: In-kernel MCE decoding enabled.

7. FAILED SERVICES FROM PREVIOUS BOOT:
Jul 31 19:11:09 workstation systemd[2846]: hyprpaper.service: Failed with result 'exit-code'.
Jul 31 19:11:10 workstation kernel: amdgpu 0000:0c:00.0: amdgpu: Failed to disallow df cstate
Jul 31 19:11:10 workstation kernel: [drm:amdgpu_device_ip_suspend_phase2 [amdgpu]] *ERROR* SMC failed to set mp1 state 3, -95
Jul 31 19:11:10 workstation kernel: amdgpu 0000:0c:00.0: amdgpu: GPU pre asic reset failed with err, -95 for drm dev, 0000:0c:00.0 
Jul 31 19:11:10 workstation kernel: amdgpu 0000:0c:00.0: amdgpu: GPU mode2 reset failed
Jul 31 19:11:10 workstation kernel: amdgpu 0000:0c:00.0: amdgpu: ASIC reset failed with error, -95 for drm dev, 0000:0c:00.0
Jul 31 19:11:10 workstation kernel: amdgpu 0000:0c:00.0: amdgpu: GPU reset(1) failed
Jul 31 19:11:10 workstation kernel: amdgpu 0000:0c:00.0: amdgpu: GPU Recovery Failed: -95
Jul 31 19:11:12 workstation systemd[2846]: hyprpaper.service: Failed with result 'exit-code'.
Jul 31 19:11:15 workstation systemd[2846]: hyprpaper.service: Failed with result 'exit-code'.

8. MOMENT OF CRASH/SHUTDOWN:
Last 50 lines before previous boot ended:
Jul 31 19:11:04 workstation systemd[1]: user@132.service: Consumed 255ms CPU time, 41.9M memory peak, 21.1M read from disk.
Jul 31 19:11:04 workstation systemd[1]: Stopping User Runtime Directory /run/user/132...
Jul 31 19:11:04 workstation systemd[1]: run-user-132.mount: Deactivated successfully.
Jul 31 19:11:04 workstation systemd[1]: user-runtime-dir@132.service: Deactivated successfully.
Jul 31 19:11:04 workstation systemd[1]: Stopped User Runtime Directory /run/user/132.
Jul 31 19:11:05 workstation systemd[2846]: hyprpaper.service: Scheduled restart job, restart counter is at 7.
Jul 31 19:11:05 workstation systemd[2846]: Started Hyprland Wallpaper.
Jul 31 19:11:05 workstation hyprpaper[4395]: [LOG] Welcome to hyprpaper!
Jul 31 19:11:05 workstation hyprpaper[4395]: built from commit v0.7.5 ()
Jul 31 19:11:05 workstation hyprpaper[4395]: [CRITICAL] Cannot launch multiple instances of Hyprpaper at once!
Jul 31 19:11:05 workstation systemd[2846]: hyprpaper.service: Main process exited, code=exited, status=1/FAILURE
Jul 31 19:11:05 workstation systemd[2846]: hyprpaper.service: Failed with result 'exit-code'.
Jul 31 19:11:09 workstation systemd[2846]: hyprpaper.service: Scheduled restart job, restart counter is at 8.
Jul 31 19:11:09 workstation systemd[2846]: Started Hyprland Wallpaper.
Jul 31 19:11:09 workstation hyprpaper[4412]: [LOG] Welcome to hyprpaper!
Jul 31 19:11:09 workstation hyprpaper[4412]: built from commit v0.7.5 ()
Jul 31 19:11:09 workstation hyprpaper[4412]: [CRITICAL] Cannot launch multiple instances of Hyprpaper at once!
Jul 31 19:11:09 workstation systemd[2846]: hyprpaper.service: Main process exited, code=exited, status=1/FAILURE
Jul 31 19:11:09 workstation systemd[2846]: hyprpaper.service: Failed with result 'exit-code'.
Jul 31 19:11:10 workstation systemd[1]: systemd-localed.service: Deactivated successfully.
Jul 31 19:11:10 workstation systemd[1]: systemd-hostnamed.service: Deactivated successfully.
Jul 31 19:11:10 workstation kernel: amdgpu 0000:0c:00.0: amdgpu: Dumping IP State
Jul 31 19:11:10 workstation kernel: amdgpu 0000:0c:00.0: amdgpu: Dumping IP State Completed
Jul 31 19:11:10 workstation kernel: amdgpu 0000:0c:00.0: amdgpu: ring gfx_0.1.0 timeout, signaled seq=2506, emitted seq=2509
Jul 31 19:11:10 workstation kernel: amdgpu 0000:0c:00.0: amdgpu: Process information: process .Hyprland-wrapp pid 2876 thread Hyprland:cs0 pid 2894
Jul 31 19:11:10 workstation kernel: amdgpu 0000:0c:00.0: amdgpu: GPU reset begin!
Jul 31 19:11:10 workstation kernel: amdgpu 0000:0c:00.0: amdgpu: Failed to disallow df cstate
Jul 31 19:11:10 workstation kernel: [drm:amdgpu_device_ip_suspend_phase2 [amdgpu]] *ERROR* SMC failed to set mp1 state 3, -95
Jul 31 19:11:10 workstation kernel: amdgpu 0000:0c:00.0: amdgpu: GPU pre asic reset failed with err, -95 for drm dev, 0000:0c:00.0 
Jul 31 19:11:10 workstation kernel: amdgpu 0000:0c:00.0: amdgpu: MODE2 reset
Jul 31 19:11:10 workstation kernel: amdgpu 0000:0c:00.0: amdgpu: GPU mode2 reset failed
Jul 31 19:11:10 workstation kernel: amdgpu 0000:0c:00.0: amdgpu: ASIC reset failed with error, -95 for drm dev, 0000:0c:00.0
Jul 31 19:11:10 workstation kernel: amdgpu 0000:0c:00.0: amdgpu: GPU reset(1) failed
Jul 31 19:11:10 workstation kernel: amdgpu 0000:0c:00.0: amdgpu: GPU reset end with ret = -95
Jul 31 19:11:10 workstation kernel: amdgpu 0000:0c:00.0: amdgpu: GPU Recovery Failed: -95
Jul 31 19:11:11 workstation cupsd[2262]: Saving subscriptions.conf...
Jul 31 19:11:12 workstation systemd[2846]: hyprpaper.service: Scheduled restart job, restart counter is at 9.
Jul 31 19:11:12 workstation systemd[2846]: Started Hyprland Wallpaper.
Jul 31 19:11:12 workstation hyprpaper[4438]: [LOG] Welcome to hyprpaper!
Jul 31 19:11:12 workstation hyprpaper[4438]: built from commit v0.7.5 ()
Jul 31 19:11:12 workstation hyprpaper[4438]: [CRITICAL] Cannot launch multiple instances of Hyprpaper at once!
Jul 31 19:11:12 workstation systemd[2846]: hyprpaper.service: Main process exited, code=exited, status=1/FAILURE
Jul 31 19:11:12 workstation systemd[2846]: hyprpaper.service: Failed with result 'exit-code'.
Jul 31 19:11:15 workstation systemd[2846]: hyprpaper.service: Scheduled restart job, restart counter is at 10.
Jul 31 19:11:15 workstation systemd[2846]: Started Hyprland Wallpaper.
Jul 31 19:11:15 workstation hyprpaper[4464]: [LOG] Welcome to hyprpaper!
Jul 31 19:11:15 workstation hyprpaper[4464]: built from commit v0.7.5 ()
Jul 31 19:11:15 workstation hyprpaper[4464]: [CRITICAL] Cannot launch multiple instances of Hyprpaper at once!
Jul 31 19:11:15 workstation systemd[2846]: hyprpaper.service: Main process exited, code=exited, status=1/FAILURE
Jul 31 19:11:15 workstation systemd[2846]: hyprpaper.service: Failed with result 'exit-code'.

9. SYSTEM ACTIVITY BEFORE CRASH:
Looking for X11/Wayland, GPU activity, or power events...
Jul 31 19:10:31 workstation systemd-journald[786]: Journal started
Jul 31 19:10:32 workstation nsncd[1189]: Jul 31 17:10:32.963 INFO started, config: Config { ignored_request_types: {}, worker_count: 8, handoff_timeout: 10s }, path: "/var/run/nscd/socket"
Jul 31 19:10:32 workstation nsncd[1282]: Jul 31 17:10:32.994 INFO started, config: Config { ignored_request_types: {}, worker_count: 8, handoff_timeout: 10s }, path: "/var/run/nscd/socket"
Jul 31 19:10:33 workstation accounts-daemon[1221]: started daemon version 23.13.9
Jul 31 19:10:34 workstation fail2ban.jail[1807]: INFO Jail 'sshd' started
Jul 31 19:10:38 workstation nsncd[1945]: Jul 31 17:10:38.811 INFO started, config: Config { ignored_request_types: {}, worker_count: 8, handoff_timeout: 10s }, path: "/var/run/nscd/socket"
Jul 31 19:10:39 workstation tailscaled[2002]: logtail started
Jul 31 19:10:39 workstation dockerd[2001]: time="2025-07-31T19:10:39.351536454+02:00" level=info msg="started new containerd process" address=/var/run/docker/containerd/containerd.sock module=libcontainerd pid=2040
Jul 31 19:10:39 workstation nsncd[2498]: Jul 31 17:10:39.915 INFO started, config: Config { ignored_request_types: {}, worker_count: 8, handoff_timeout: 10s }, path: "/var/run/nscd/socket"
Jul 31 19:10:42 workstation gdm-password][2809]: gkr-pam: gnome-keyring-daemon started properly and unlocked keyring
Jul 31 19:10:42 workstation hyprsunset[2945]: [LOG] hyprsunset socket started at /run/user/1000/hypr/9958d297641b5c84dcff93f9039d80a5ad37ab00_1753981842_1460479039/.hyprsunset.sock (fd: 4)

=== INVESTIGATION COMPLETE ===
Look for:
- Kernel panics or oops
- GPU resets or hangs
- Hyprland crashes
- Power management failures
- Memory errors
