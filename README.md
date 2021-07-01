# My AMD Single GPU Passthrough
* Operating System: Arch Linux
* DE: KDE Plasma
* OS Type: 64-bit
* Graphics Platform: X11
* Processors: 12 × AMD Ryzen 5 2600 Six-Core Processor
* Memory: 16 GiB of RAM
* Graphics Processor: Radeon RX 580 Sapphire Nitro+
* Motherboard: ASRock B450 Pro4

## Ryzen 5 2600 CPU Topology example:

![Screenshot_20210417_121900](https://user-images.githubusercontent.com/32335484/115109624-32f87380-9f77-11eb-8081-7054ef6a1eff.png)


``` 
            L3                          L3

|   Core#0 Core#1 Core#2  | |  Core#3 Core#4 Core#5   |
|    |0|     1      2     | |   |3|     4      5      |
|    |6|     7      8     | |   |9|     10     11     |
|      \                  | |     \                   |
|      Reserved for Host  | |      Reserved for Host  |
| __ __ __ __ __ __ __ __ | | __ __ __ __ __ __ __ __ |


# XML Config, Ryzen 2600 topology example:

  <cpu mode='host-passthrough' check='none' migratable='on'>  <!-- Set the cpu mode to passthrough -->
    <topology sockets='1' dies='1' cores='6' threads='2'/>  <!-- Match the cpu topology. In my case 6c/12t, or 2 threads per each core -->
    <cache mode='passthrough'/>                       <!-- The real CPU cache data reported by the host CPU will be passed through to the virtual CPU -->
    <feature policy='require' name='topoext'/>  
    <feature policy='require' name='svm'/>
    <feature policy='require' name='apic'/>           <!-- Enable various features improving behavior of guests running Microsoft Windows -->
    <feature policy='require' name='hypervisor'/>
    <feature policy='require' name='invtsc'/>
  </cpu>
```

```
 XML Config, Ryzen 2600 2 x 3-core CCX CPU Pinning example:
 
 <vcpu placement='static' current='8'>12</vcpu> <!-- I will use only 8 cores, rest will be disabled in VM and used for the HOST machine (emulatorpin) -->
  <vcpus>
    <vcpu id='0' enabled='yes' hotpluggable='no'/>
    <vcpu id='1' enabled='yes' hotpluggable='yes'/>
    <vcpu id='2' enabled='yes' hotpluggable='yes'/>
    <vcpu id='3' enabled='yes' hotpluggable='yes'/>
    <vcpu id='4' enabled='no' hotpluggable='yes'/>  <!-- Workaround to use both L3 caches, check the Coreinfo -->
    <vcpu id='5' enabled='no' hotpluggable='yes'/>
    <vcpu id='6' enabled='no' hotpluggable='yes'/>
    <vcpu id='7' enabled='no' hotpluggable='yes'/>
    <vcpu id='8' enabled='yes' hotpluggable='yes'/>
    <vcpu id='9' enabled='yes' hotpluggable='yes'/>
    <vcpu id='10' enabled='yes' hotpluggable='yes'/>
    <vcpu id='11' enabled='yes' hotpluggable='yes'/>
  </vcpus>
  <cputune>
    <vcpupin vcpu='0' cpuset='1'/>
    <vcpupin vcpu='1' cpuset='7'/>
    <vcpupin vcpu='2' cpuset='2'/>
    <vcpupin vcpu='3' cpuset='8'/>
    <vcpupin vcpu='8' cpuset='4'/>     <!-- Notice that after vCPU3, we defined vCPU8. We disabled 4,5,6,7 vCPUs -->
    <vcpupin vcpu='9' cpuset='10'/>
    <vcpupin vcpu='10' cpuset='5'/>
    <vcpupin vcpu='11' cpuset='11'/>
    <emulatorpin cpuset='0,3,6,9'/>    <!-- Threads reserved for host machine (in my case Core#0 and Core#3) -->
  </cputune>                  
                               
```
## IOMMU, libvirt and QEMU configuration

* Make sure you enable IOMMU in the BIOS. For the ASRock motherboard (in my case) it is located in Advanced > AMD CBS > NBIO Common Options > NB Configuration > IOMMU

* Append ```amd_iommu=on iommu=pt``` kernel parameters in: /etc/default/grub
  ```
  GRUB_CMDLINE_LINUX_DEFAULT="loglevel=3 quiet amdgpu.ppfeaturemask=0xffffffff amd_iommu=on iommu=pt"
  ```

* Update the GRUB configuration and reboot:
  ```
  sudo grub-mkconfig -o /boot/grub/grub.cfg 
  ```

* Install all Arch Linux packages:
  ```
  sudo pacman -S qemu qemu-arch-extra edk2-ovmf vde2 iptables-nft dnsmasq bridge-utils libvirt virt-manager
  ```

* Enable and start libvirt services:
  ```
  systemctl enable --now libvirtd.service
  systemctl start virtlogd.service
  ```

* Add a user to ```libvirt``` and ```kvm``` groups:
  ```
  sudo usermod -aG libvirt kvm yourusername
  ```

* Check if you have the directory /dev/hugepages. If not, create it.

* Mount hugepages in /etc/fstab and reboot:
  ```
  hugetlbfs       /dev/hugepages  hugetlbfs       mode=01770,gid=kvm        0 0
  ```

* Don't forget to edit:
  * /etc/libvirt/libvirtd.conf
    ```
    unix_sock_group = "libvirt"
    unix_sock_ro_perms = "0777"
    unix_sock_rw_perms = "0770"
    auth_unix_ro = "none"
    auth_unix_rw = "none"
    log_filters = "2:libvirt.domain 1:qemu"
    log_outputs = "1:file:/var/log/libvirt/libvirtd.log"
    ```
  * /etc/libvirt/qemu.conf
    ```
    user = "yourusername"
    group = "kvm"
    ```

* Restart the libvirt services after every modification:
```
systemctl restart libvirtd.service
systemctl restart virtlogd.service
```

* Find your [RX 580 VBIOS.rom](https://www.techpowerup.com/vgabios/?architecture=AMD&manufacturer=&model=RX+580&version=&interface=&memType=GDDR5&memSize=&since=) file and place it in /var/lib/libvirt/vbios/
  * Set the correct permissions and ownership:
    ```
    sudo chmod -R 775 /var/lib/libvirt/vbios/yourvbiosname.rom
    sudo chown yourusername:yourusername /var/lib/libvirt/vbios/yourvbiosname.rom
    ```

## Windows 10 virt-manager preparation and installation (without going into details)

* Open the virt-manager and prepare Windows 10 iso, also use the raw image virtio disk.

* Use the Q35 chipset and UEFI OVMF_CODE loader 

* Before installing the Windows 10, mount the [virtio-win.iso](https://fedorapeople.org/groups/virt/virtio-win/direct-downloads/) disk first in virt-manager

* In order to recognize virtio disk, don't forget to load virtio driver from virtio-win.iso in Windows installation.

* After the installation, boot in Windows and install all virtio drivers from device manager. You can get drivers from virtio-win.iso

* Add GPU PCI Host devices, both GPU and HDMI devices. Remove DisplaySpice, VideoQXL and other serial devices.

* Add USB Host devices, like keyboard, mouse... You can also follow [this tutorial](https://wiki.archlinux.org/index.php/PCI_passthrough_via_OVMF#Passing_keyboard/mouse_via_Evdev)  

* For sound: You can passthrough the PCI HD Audio controler ([or you can use qemu pusleaudio passthrough](https://wiki.archlinux.org/index.php/PCI_passthrough_via_OVMF#Passing_VM_audio_to_host_via_PulseAudio)) 

* Set the network source to Bridge device with ```br0``` device name and virtio device model.

* Don't forget to add vbios.rom file inside the win10.xml for the GPU and HDMI host PCI devices, example:
  ```
    ...
    </source>
    <rom file='/var/lib/libvirt/vbios/yourvbiosname.rom'/>  <!-- Place here -->
    <address/>
    ...
  ```

* Enable hugepages and configure size:
  ```
    ...
    <memory unit='KiB'>12582912</memory>
    <currentMemory unit='KiB'>12582912</currentMemory>  
    <memoryBacking>
      <hugepages>
        <page size='2048' unit='KiB'/>
      </hugepages>
    </memoryBacking>
    ...
  ```

* Set the CPU pinning, [check out the topology and comments above](https://github.com/Zile995/Ryzen-2600_RX-580-GPU-Passthrough#ryzen-5-2600-cpu-topology-example). Also check the [win10.xml](https://github.com/Zile995/Ryzen-2600_RX-580-GPU-Passthrough/blob/main/win10.xml) example file

* Move hooks [folder](https://github.com/Zile995/Ryzen-2600_RX-580-GPU-Passthrough/tree/main/hooks) from this repository to /etc/libvirt/
    * ```sudo cp -r hooks /etc/libvirt/```
