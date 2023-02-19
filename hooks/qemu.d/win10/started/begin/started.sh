#!/bin/bash

# Helpful to read output when debugging
set -x

# Load config files
source "/etc/libvirt/hooks/cores.conf"
printer "hook $1 $2 $3 $4"

set_vcpus_nice_level() {
    for grp in /sys/fs/cgroup/machine.slice/machine-qemu*"$VM_NAME".scope/libvirt/vcpu*
    do
        printer "Setting $(basename "$grp")'s nice level to $TARGET_NICE"
        cat < "$grp"/cgroup.threads | while IFS= read -r pid 
        do
            renice -n "$TARGET_NICE" -p "$pid" 2> /dev/null
        done
    done
    printer "Prioritized vCPU threads of VM $VM_NAME"
}

set_sched_policy() {
    if pid=$(pidof qemu-system-x86_64); then
        chrt -f -p 1 "$pid"
        printer "Changing scheduling to fifo for qemu pid $pid"
    fi
}

set_affinity() {
    sleep 30
    grep vfio /proc/interrupts | cut -d ":" -f 1 | while read -r i; do
        printer "Changing smp_affinity for vfio irq $i"
        if [[ $VIRT_CORES -ne $(cat /proc/irq/"$i"/smp_affinity_list) ]]; then 
            echo "$VIRT_CORES" > /proc/irq/"$i"/smp_affinity_list
        fi
    done
}

if [[ "$VM_ACTION" == "started/begin" ]]; then
    set_vcpus_nice_level
    set_sched_policy
    set_affinity
fi
