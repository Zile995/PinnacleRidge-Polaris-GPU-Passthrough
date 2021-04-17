#!/bin/bash

## Enable CPU governor schedutil mode
echo "libvirt-qemu governor: Setting the CPU Governor to schedutil for host machine" > /dev/kmsg 2>&1
cat /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor
for file in /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor; do echo "schedutil" > $file; done
cat /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor
