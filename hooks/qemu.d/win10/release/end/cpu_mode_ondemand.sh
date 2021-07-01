#!/bin/bash

## Switch to ondemand CPU governor
echo "libvirt-qemu governor: Setting the CPU Governor to ondemand for host machine" > /dev/kmsg 2>&1
cat /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor
for file in /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor; do echo "ondemand" > $file; done
cat /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor
echo -n 50 > /sys/devices/system/cpu/cpufreq/ondemand/up_threshold
echo -n 10 > /sys/devices/system/cpu/cpufreq/ondemand/sampling_down_factor
echo -n 1 > /sys/devices/system/cpu/cpufreq/ondemand/io_is_busy
