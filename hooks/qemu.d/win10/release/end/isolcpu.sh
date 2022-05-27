#!/bin/bash
source "/etc/libvirt/hooks/cores.conf"
echo $(date) libvirt-qemu: hook $1 $2 $3 $4 >> $LOG

release_cores() {
    echo $(date) libvirt-qemu: Releasing CPUs $VIRT_CORES from VM $VM_NAME >> $LOG
    systemctl set-property --runtime -- user.slice AllowedCPUs=$TOTAL_CORES
    systemctl set-property --runtime -- system.slice AllowedCPUs=$TOTAL_CORES
    systemctl set-property --runtime -- init.scope AllowedCPUs=$TOTAL_CORES
    systemctl set-property --runtime -- machine.slice AllowedCPUs=$TOTAL_CORES

    # Revert changes made to the writeback workqueue
    echo $TOTAL_CORES_MASK > /sys/bus/workqueue/devices/writeback/cpumask
    echo 1 > /sys/bus/workqueue/devices/writeback/numa
}

if [[ "$VM_ACTION" == "release/end" ]]; then
    release_cores
    echo $(date) libvirt-qemu: Successfully released CPUs $VIRT_CORES >> $LOG
fi

