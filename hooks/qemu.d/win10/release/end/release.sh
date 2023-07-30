#!/bin/bash

# Helpful to read output when debugging
set -x

# Load config files
source "/etc/libvirt/hooks/cores.conf"
printer "hook $1 $2 $3 $4"

release_cores() {
    printer "Releasing CPUs $VIRT_CORES from VM $VM_NAME"
    systemctl set-property --runtime -- user.slice AllowedCPUs="$TOTAL_CORES"
    systemctl set-property --runtime -- system.slice AllowedCPUs="$TOTAL_CORES"
    systemctl set-property --runtime -- init.scope AllowedCPUs="$TOTAL_CORES"
    systemctl set-property --runtime -- machine.slice AllowedCPUs="$TOTAL_CORES"

    # Revert changes made to the writeback workqueue
    echo "$TOTAL_CORES_MASK" > /sys/bus/workqueue/devices/writeback/cpumask
    echo "1" > /sys/bus/workqueue/devices/writeback/numa
    printer "Successfully released CPUs $VIRT_CORES"
}

set_ondemand_governor() {
    # Switch to ondemand CPU governor
    for file in /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor; do echo "ondemand" > "$file"; done
    echo -n "1" > /sys/devices/system/cpu/cpufreq/ondemand/io_is_busy
    echo -n "50" > /sys/devices/system/cpu/cpufreq/ondemand/up_threshold
    echo -n "20" > /sys/devices/system/cpu/cpufreq/ondemand/sampling_down_factor
    printer "Successfully set ondemand CPU governor for host machine"
}

set_schedutil_governor() {
    # Switch to schedutil CPU governor
    for file in /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor; do echo "schedutil" > "$file"; done
    printer "Successfully set schedutil CPU governor for host machine"
}

remove_vfio_modules() {
    # Remove VFIO kernel modules
    modprobe -r vfio-pci
    modprobe -r vfio_virqfd
    modprobe -r vfio_iommu_type1
    printer "Successfully unloaded VFIO-PCI"
}

load_amd_gpu() {
    # Load AMD GPU driver
    modprobe amdgpu
    echo "efi-framebuffer.0" > /sys/bus/platform/drivers/efi-framebuffer/bind
    printer "Successfully loaded AMD GPU"
}

restart_systemd_services() {
    # Restart display manager, fan control service, ...
    # systemctl restart amdgpu-fancontrol.service
    systemctl restart gdm.service
    printer "Successfully restarted systemd services"
}

if [[ "$VM_ACTION" == "release/end" ]]; then
    release_cores
    set_ondemand_governor
    remove_vfio_modules
    load_amd_gpu
    restart_systemd_services
fi
