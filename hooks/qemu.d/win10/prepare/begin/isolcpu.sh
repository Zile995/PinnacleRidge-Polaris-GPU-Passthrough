#!/bin/bash
source "/etc/libvirt/hooks/cores.conf"
echo $(date) libvirt-qemu: hook $1 $2 $3 $4 >> $LOG

set_host_cores() {
    echo $(date) libvirt-qemu: Reserving CPUs $HOST_CORES for host machine >> $LOG
    systemctl set-property --runtime -- user.slice AllowedCPUs=$HOST_CORES
    systemctl set-property --runtime -- system.slice AllowedCPUs=$HOST_CORES
    systemctl set-property --runtime -- init.scope AllowedCPUs=$HOST_CORES

    # Restrict the workqueue to use only cpu 0.
    echo $HOST_CORES_MASK > /sys/bus/workqueue/devices/writeback/cpumask
    echo 0 > /sys/bus/workqueue/devices/writeback/numa
}

if [[ "$VM_ACTION" == "prepare/begin" ]]; then
    set_host_cores
    echo $(date) libvirt-qemu: Successfully reserved CPUs $HOST_CORES for host machine >> $LOG
fi
