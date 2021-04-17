#!/bin/bash
set -x

# Unload VFIO-PCI Kernel Driver
modprobe -r vfio_iommu_type1
modprobe -r vfio-pci
modprobe -r vfio
  
# Re-Bind GPU to AMD Driver
virsh nodedev-reattach pci_0000_0a_00_1
virsh nodedev-reattach pci_0000_0a_00_0
