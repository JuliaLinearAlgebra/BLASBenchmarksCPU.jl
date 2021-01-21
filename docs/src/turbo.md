```@meta
CurrentModule = BLASBenchmarksCPU
```

# Disabling CPU Turbo

Most recent CPUs have the ability to turbo, increasing their clock speeds for brief durations of time as thermal envelope and longer term power-use limitations allow. This is great for performance, but bad for benchmarking.

If you're running Linux, it's probably easy to enable or disable turbo settings without having to reboot into your bios.
The Linux Kernel Documentation is fairly thorough in discussing [CPUFreq](https://www.kernel.org/doc/html/v4.12/admin-guide/pm/cpufreq.html) and [intel_pstate](https://www.kernel.org/doc/html/v4.12/admin-guide/pm/intel_pstate.html) scaling drivers.

To check those on my system, I can run:
```sh
> cat /sys/devices/system/cpu/cpu*/cpufreq/scaling_driver
intel_pstate
intel_pstate
intel_pstate
intel_pstate
intel_pstate
intel_pstate
intel_pstate
intel_pstate
```
This tells me it is using `intel_pstate` in active mode.

The documentation on `intel_pstate` mentions the `no_turbo` attribute:


> If set (equal to 1), the driver is not allowed to set any turbo P-states (see Turbo P-states Support). If unset (equalt to 0, which is the default), turbo P-states can be set by the driver.

This attribute is writable, so running
```sh
echo "1" | sudo tee /sys/devices/system/cpu/intel_pstate/no_turbo
```
disables turbo on this system. This, and closing programs that would compete for system resources (e.g., internet browsers; you can run `(h)top` to see if any processes are consuming non-negligible resources), should hopefully make benchmarking reasonably consistent and reliable.

Finally, when I'm done benchmarking, I can reenable turbo by running:
```sh
echo "0" | sudo tee /sys/devices/system/cpu/intel_pstate/no_turbo
```

If your system does not use the `intel_pstate` driver, check for
```sh
/sys/devices/system/cpu/cpufreq/boost
```
discussed [here](https://www.kernel.org/doc/html/v4.12/admin-guide/pm/cpufreq.html#frequency-boost-support) in the kernel documentation. If the file is present, you should be able to disable boost with
```sh
echo "0" | sudo tee /sys/devices/system/cpu/cpufreq/boost
```
and then reenable with
```sh
echo "1" | sudo tee /sys/devices/system/cpu/cpufreq/boost
```

In either case, you may find it convenient to place these snippets in `#! /bin/bash` scripts for conveniently turning your systems boost on and off as desired.

