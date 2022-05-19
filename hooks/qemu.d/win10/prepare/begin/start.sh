#!/bin/bash
# Helpful to read output when debugging
set -x

# Stop display manager, fan control service
systemctl stop gdm.service
systemctl stop amdfand.service
#systemctl stop amdgpu-fancontrol.service

# Unbind VTconsoles
echo 0 > /sys/class/vtconsole/vtcon0/bind
echo 0 > /sys/class/vtconsole/vtcon1/bind

# Avoid a Race condition by waiting x seconds.
sleep 7

# Unload Radeon GPU driver
modprobe -r amdgpu

# Unbind the GPU from display driver
virsh nodedev-detach pci_0000_0a_00_0
virsh nodedev-detach pci_0000_0a_00_1

# Load VFIO Kernel Module  
modprobe vfio
modprobe vfio_pci
modprobe vfio_iommu_type1
