#!/bin/bash

# Helpful to read output when debugging
set -x

# Load config files
source "/etc/libvirt/hooks/cores.conf"
echo "$(date)" libvirt-qemu: hook "$1" "$2" "$3" "$4" >> "$LOG"

release_cores() {
    echo "$(date)" libvirt-qemu: Releasing CPUs "$VIRT_CORES" from VM "$VM_NAME" >> "$LOG"
    systemctl set-property --runtime -- user.slice AllowedCPUs="$TOTAL_CORES"
    systemctl set-property --runtime -- system.slice AllowedCPUs="$TOTAL_CORES"
    systemctl set-property --runtime -- init.scope AllowedCPUs="$TOTAL_CORES"
    systemctl set-property --runtime -- machine.slice AllowedCPUs="$TOTAL_CORES"

    # Revert changes made to the writeback workqueue
    echo "$TOTAL_CORES_MASK" > /sys/bus/workqueue/devices/writeback/cpumask
    echo "1" > /sys/bus/workqueue/devices/writeback/numa
    echo "$(date)" libvirt-qemu: Successfully released CPUs "$VIRT_CORES" >> "$LOG"
}

set_ondemand_governor() {
    # Switch to ondemand CPU governor
    for file in /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor; do echo "ondemand" > "$file"; done
    echo -n "1" > /sys/devices/system/cpu/cpufreq/ondemand/io_is_busy
    echo -n "50" > /sys/devices/system/cpu/cpufreq/ondemand/up_threshold
    echo -n "10" > /sys/devices/system/cpu/cpufreq/ondemand/sampling_down_factor
    echo "$(date)" libvirt-qemu: Successfully set ondemand CPU governor for host machine >> "$LOG"
}

set_schedutil_governor() {
    # Switch to schedutil CPU governor
    for file in /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor; do echo "schedutil" > "$file"; done
    echo "$(date)" libvirt-qemu: Successfully set schedutil CPU governor for host machine >> "$LOG"
}

remove_vfio_modules() {
    # Remove VFIO kernel modules
    modprobe -r vfio-pci
    modprobe -r vfio_virqfd
    modprobe -r vfio_iommu_type1
    echo "$(date)" libvirt-qemu: Successfully unloaded VFIO-PCI >> "$LOG"
}

load_amd_gpu() {
    # Load AMD GPU driver
    modprobe amdgpu
    echo "efi-framebuffer.0" > /sys/bus/platform/drivers/efi-framebuffer/bind
    echo "$(date)" libvirt-qemu: Successfully loaded AMD GPU >> "$LOG"
}

restart_systemd_services() {
    # Restart display manager, fan control service, ...
    # systemctl restart amdgpu-fancontrol.service
    systemctl restart gdm.service
    echo "$(date)" libvirt-qemu: Successfully restarted systemd services >> "$LOG"
}

if [[ "$VM_ACTION" == "release/end" ]]; then
    release_cores
    set_ondemand_governor
    remove_vfio_modules
    load_amd_gpu
    restart_systemd_services
fi
