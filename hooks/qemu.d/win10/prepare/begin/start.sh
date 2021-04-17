#!/bin/bash
# Helpful to read output when debugging
set -x

IP_ADDR=192.168.1.110/24
DEVICE=$(nmcli -g device connection show | head -1)

# Set the bridge network
ip link add name br0 type bridge
ip addr add $IP_ADDR dev br0
ip link set br0 up
ip link set $DEVICE master br0

[[ ! -d /etc/qemu ]] && mkdir /etc/qemu
if [ ! -f /etc/qemu/bridge.conf ]; then
    echo allow br0 > /etc/qemu/bridge.conf
fi

sysctl net.ipv4.ip_forward=1
sysctl net.ipv6.conf.default.forwarding=1
sysctl net.ipv6.conf.all.forwarding=1

# Stop display manager, fan control service
systemctl stop sddm.service
systemctl stop amdgpu-fancontrol.service

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
