#!/bin/bash

VM_NAME="$1"

## Enable CPU governor performance mode
echo "libvirt-qemu governor: Setting the CPU Governor to performance for VM $VM_NAME" > /dev/kmsg 2>&1
cat /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor
for file in /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor; do echo "performance" > $file; done
cat /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor

