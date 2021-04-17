#!/bin/bash

LOG=/dev/kmsg
TOTAL_CORES='0-11'
TOTAL_CORES_MASK=FFF               # 0-11, bitmask 0b111111111111
HOST_CORES='0,3,6,9'               # Cores reserved for host
HOST_CORES_MASK=924                # 0,3,6,9 bitmask 0b100100100100
VIRT_CORES='1-2,4-5,7-8,10-11'     # Cores reserved for virtual machine(s)

VM_NAME="$1"
VM_ACTION="$2/$3"

echo $(date) libvirt hook $1 $2 $3 $4 >> $LOG

set_host_cores() {
    echo $(date) Reserving CPUs $HOST_CORES for host machine >> $LOG
    systemctl set-property --runtime -- user.slice AllowedCPUs=$HOST_CORES
    systemctl set-property --runtime -- system.slice AllowedCPUs=$HOST_CORES
    systemctl set-property --runtime -- init.scope AllowedCPUs=$HOST_CORES

    # Restrict the workqueue to use only cpu 0.
    echo $HOST_CORES_MASK > /sys/bus/workqueue/devices/writeback/cpumask
    echo 0 > /sys/bus/workqueue/devices/writeback/numa
}
