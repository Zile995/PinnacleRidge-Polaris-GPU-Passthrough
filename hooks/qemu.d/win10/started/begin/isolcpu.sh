#!/bin/bash

LOG=/dev/kmsg
TOTAL_CORES='0-11'
TOTAL_CORES_MASK=FFF               # 0-11, bitmask 0b111111111111
HOST_CORES='0,3,6,9'               # Cores reserved for host
HOST_CORES_MASK=924                # 0,3,6,9 bitmask 0b100100100100
VIRT_CORES='1-2,4-5,7-8,10-11'     # Cores reserved for virtual machine(s)
CPUSET_PATH=/sys/fs/cgroup/machine.slice/machine-qemu*$VM_NAME.scope

VM_NAME="$1"
VM_ACTION="$2/$3"

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

set_virt_cores() {
    echo $(date) libvirt-qemu: Reserving CPUs $VIRT_CORES for VM $VM_NAME >> $LOG
    systemctl set-property --runtime -- machine.slice AllowedCPUs=$VIRT_CORES
    echo ${VIRT_CORES} > ${CPUSET_PATH}/cpuset.cpus
}

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

set_sched_policy() {
    if pid=$(pidof qemu-system-x86_64); then
      chrt -f -p 1 $pid
      echo $(date) libvirt-qemu: Changing scheduling to fifo for qemu pid $pid >> $LOG
    fi
}

set_affinity() {
    grep vfio /proc/interrupts | cut -d ":" -f 1 | while read -r i; do
        echo $(date) libvirt-qemu: Changing smp_affinity for vfio irq $i >> $LOG
        while [[ $VIRT_CORES -ne $(cat /proc/irq/$i/smp_affinity_list) ]]; do 
            echo $VIRT_CORES > /proc/irq/$i/smp_affinity_list
        done
    done
}

if [[ "$VM_ACTION" == "prepare/begin" ]]; then
    set_host_cores
    echo $(date) libvirt-qemu: Successfully reserved CPUs $HOST_CORES for host machine >> $LOG

elif [[ "$VM_ACTION" == "started/begin" ]]; then
    set_virt_cores
    echo $(date) libvirt-qemu: Successfully reserved CPUs $VIRT_CORES for VM $VM_NAME >> $LOG
    set_sched_policy
    set_affinity

elif [[ "$VM_ACTION" == "release/end" ]]; then
    release_cores
    echo $(date) libvirt-qemu: Successfully released CPUs $VIRT_CORES >> $LOG
fi
