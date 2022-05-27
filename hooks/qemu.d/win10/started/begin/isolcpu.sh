#!/bin/bash
source "/etc/libvirt/hooks/cores.conf"
echo $(date) libvirt-qemu: hook $1 $2 $3 $4 >> $LOG

set_virt_cores() {
    echo $(date) libvirt-qemu: Reserving CPUs $VIRT_CORES for VM $VM_NAME >> $LOG
    systemctl set-property --runtime -- machine.slice AllowedCPUs=$VIRT_CORES
    echo ${VIRT_CORES} > ${CPUSET_PATH}/cpuset.cpus
}

set_sched_policy() {
    if pid=$(pidof qemu-system-x86_64); then
      chrt -f -p 1 $pid
      echo $(date) libvirt-qemu: Changing scheduling to fifo for qemu pid $pid >> $LOG
    fi
}

set_affinity() {
    sleep 30
    grep vfio /proc/interrupts | cut -d ":" -f 1 | while read -r i; do
        echo $(date) libvirt-qemu: Changing smp_affinity for vfio irq $i >> $LOG
        if [[ $VIRT_CORES -ne $(cat /proc/irq/$i/smp_affinity_list) ]]; then 
            echo $VIRT_CORES > /proc/irq/$i/smp_affinity_list
        fi
    done
}

if [[ "$VM_ACTION" == "started/begin" ]]; then
    set_virt_cores
    echo $(date) libvirt-qemu: Successfully reserved CPUs $VIRT_CORES for VM $VM_NAME >> $LOG
    set_sched_policy
    set_affinity
fi

