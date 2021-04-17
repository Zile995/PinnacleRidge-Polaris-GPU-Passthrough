#!/bin/bash

LOG=/dev/kmsg
TOTAL_CORES='0-11'
TOTAL_CORES_MASK=FFF               # 0-11, bitmask 0b111111111111
HOST_CORES='0,3,6,9'               # Cores reserved for host
HOST_CORES_MASK=924                # 0,3,6,9 bitmask 0b100100100100
VIRT_CORES='1-2,4-5,7-8,10-11'     # Cores reserved for virtual machine(s)
CPUSET_PATH=/sys/fs/cgroup/machine.slice/machine-qemu*

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

set_virt_cores() {
    echo $(date) Reserving CPUs $VIRT_CORES for VM $VM_NAME >> $LOG
    systemctl set-property --runtime -- machine.slice AllowedCPUs=$VIRT_CORES
    /bin/echo ${VIRT_CORES} > ${CPUSET_PATH}/cpuset.cpus
}

release_cores() {
    echo $(date) Releasing CPUs $VIRT_CORES from VM $VM_NAME >> $LOG
    systemctl set-property --runtime -- user.slice AllowedCPUs=$TOTAL_CORES
    systemctl set-property --runtime -- system.slice AllowedCPUs=$TOTAL_CORES
    systemctl set-property --runtime -- init.scope AllowedCPUs=$TOTAL_CORES
    systemctl set-property --runtime -- machine.slice AllowedCPUs=$TOTAL_CORES

    # Revert changes made to the writeback workqueue
    echo $TOTAL_CORES_MASK > /sys/bus/workqueue/devices/writeback/cpumask
    echo 1 > /sys/bus/workqueue/devices/writeback/numa
}

set_sched_policy() {
    if pid=$(pidof qemu-system-x86_64); then
      chrt -f -p 1 $pid
      echo $(date) Changing scheduling to fifo for qemu pid $pid >> $LOG
    fi
}

set_affinity() {
    end=$((SECONDS+15))
    while [ $SECONDS -lt $end ]; do
        grep vfio /proc/interrupts | cut -d ":" -f 1 | while read -r i; do
            if [[ $VIRT_CORES -ne $(cat /proc/irq/$i/smp_affinity_list) ]]; then 
                echo $(date) Changing smp_affinity for vfio irq $i >> $LOG
                echo $VIRT_CORES > /proc/irq/$i/smp_affinity_list
            fi
        done
    done
}

