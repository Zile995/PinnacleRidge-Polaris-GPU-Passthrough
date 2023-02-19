#!/bin/bash

# Helpful to read output when debugging
set -x

# Load config files
source "/etc/libvirt/hooks/kvm.conf"
source "/etc/libvirt/hooks/cores.conf"
printer "hook $1 $2 $3 $4"

stop_systemd_services() {
    # Stop display manager, fan control service, ...
    # systemctl stop amdgpu-fancontrol.service
    systemctl stop gdm.service
    printer "Successfully stopped systemd services"
}

unload_amd_gpu() {
    # Unnbind AMD GPU PCI devices
    echo "$VIRSH_GPU_VIDEO" > /sys/bus/pci/drivers/amdgpu/unbind
    echo "$VIRSH_GPU_AUDIO" > /sys/bus/pci/drivers/snd_hda_intel/unbind

    # Remove AMD GPU kernel modules
    modprobe -r amdgpu
    printer "Successfully unloaded AMD GPU"
}

set_host_cores() {
    printer "Reserving CPUs $HOST_CORES for host machine"
    systemctl set-property --runtime -- user.slice AllowedCPUs="$HOST_CORES"
    systemctl set-property --runtime -- system.slice AllowedCPUs="$HOST_CORES"
    systemctl set-property --runtime -- init.scope AllowedCPUs="$HOST_CORES"

    # Restrict the workqueue to use only cpu 0.
    echo "$HOST_CORES_MASK" > /sys/bus/workqueue/devices/writeback/cpumask
    echo "0" > /sys/bus/workqueue/devices/writeback/numa
    printer "Successfully reserved CPUs $HOST_CORES for host machine"
}

set_performance_governor() {
    # Enable CPU governor performance mode
    for file in /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor; do echo "performance" > "$file"; done
    printer "Successfully set performance CPU governor for VM $VM_NAME"
}

defragment_memory_and_drop_caches() {
    # Finish writing any outstanding writes to disk.
    sync

    # Drop all filesystem caches to free up more memory.
    echo "3" > /proc/sys/vm/drop_caches

    # Do another run of writing any possible new outstanding writes.
    sync

    # Tell the kernel to "defragment" memory where possible.
    echo "1" > /proc/sys/vm/compact_memory
    printer "Successfully defragmented memory"
}

if [[ "$VM_ACTION" == "prepare/begin" ]]; then
    stop_systemd_services
    unload_amd_gpu
    set_host_cores
    set_performance_governor
    defragment_memory_and_drop_caches
fi
