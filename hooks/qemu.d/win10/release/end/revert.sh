#!/bin/bash
set -x

# Unload VFIO-PCI Kernel Driver
modprobe -r vfio_iommu_type1
modprobe -r vfio-pci
modprobe -r vfio
  
# Re-Bind GPU to AMD Driver
virsh nodedev-reattach pci_0000_0a_00_1
virsh nodedev-reattach pci_0000_0a_00_0

# Rebind VT consoles
echo 1 > /sys/class/vtconsole/vtcon0/bind
echo 1 > /sys/class/vtconsole/vtcon1/bind

# Load all Radeon drivers
modprobe amdgpu
modprobe gpu_sched
modprobe ttm
modprobe drm_kms_helper
modprobe i2c_algo_bit
modprobe drm
modprobe snd_hda_intel

# Start AMD GPU Fan control and Display Manager
#systemctl restart amdgpu-fancontrol.service
systemctl restart amdfand.service
systemctl restart gdm.service
