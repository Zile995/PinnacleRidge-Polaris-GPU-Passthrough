# My AMD Single GPU Passthrough

<details>
  <summary>Hardware specifications</summary>

    * Operating System: Arch Linux
    * DE: Gnome
    * Graphics Platform: Wayland
    * Processors: 12 × AMD Ryzen 5 2600 Six-Core Processor
    * Memory: 16 GiB of RAM
    * Graphics Processor: Radeon RX 580 Sapphire Nitro+
    * Motherboard: ASRock B450 Pro4

</details>

## Ryzen 5 2600 CPU Topology example:

<details>
  <summary>System topology (lstopo)</summary>
  
  ![Screenshot_20210417_121900](https://user-images.githubusercontent.com/32335484/115109624-32f87380-9f77-11eb-8081-7054ef6a1eff.png)          

</details>

<details>
  <summary>Coreinfo L3 cache</summary>
  
  ![Coreinfo](https://user-images.githubusercontent.com/32335484/150604836-d8f342f6-f35b-4aaa-b759-d4e83cb3ddc6.png)

</details>

<details>
<summary>XML Config, Ryzen 2600 2 x 3-core CCX CPU Pinning example</summary>
	
``` 
            L3                          L3

|   Core#0 Core#1 Core#2  | |  Core#3 Core#4 Core#5   |
|    |0|     1      2     | |   |3|     4      5      |
|    |6|     7      8     | |   |9|     10     11     |
|      \                  | |     \                   |
|      Reserved for Host  | |      Reserved for Host  |
| __ __ __ __ __ __ __ __ | | __ __ __ __ __ __ __ __ |
 
 <vcpu placement='static' current='8'>12</vcpu>  <!-- I will use only 8 cores, rest will be disabled in VM and used for the HOST machine (emulatorpin) -->
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
    <vcpupin vcpu='8' cpuset='4'/>    <!-- Notice that after vCPU3, we defined vCPU8. We disabled 4,5,6,7 vCPUs -->
    <vcpupin vcpu='9' cpuset='10'/>
    <vcpupin vcpu='10' cpuset='5'/>
    <vcpupin vcpu='11' cpuset='11'/>
    <emulatorpin cpuset='0,3,6,9'/>   <!-- Threads reserved for host machine (in my case Core#0 and Core#3) -->
  </cputune>
```

```
Enabling Hyper-V enlightenments (Windows only)

  <hyperv>
    <relaxed state='on'/>
    <vapic state='on'/>
    <spinlocks state='on' retries='8191'/>
    <vpindex state='on'/>
    <runtime state='on'/>
    <synic state='on'/>
    <stimer state='on'/>
    <reset state='on'/>
    <frequencies state='on'/>
  </hyperv>
```

```
  <cpu mode='host-passthrough' check='none' migratable='on'>  <!-- Set the cpu mode to passthrough -->
    <topology sockets='1' dies='1' cores='6' threads='2'/>    <!-- Match the cpu topology. In my case 6c/12t, or 2 threads per each core -->
    <cache mode='passthrough'/>                     <!-- The real CPU cache data reported by the host CPU will be passed through to the virtual CPU -->
    <feature policy='require' name='topoext'/>  
    <feature policy='require' name='svm'/>
    <feature policy='require' name='apic'/>         <!-- Enable various features improving behavior of guests running Microsoft Windows -->
    <feature policy='require' name='hypervisor'/>
    <feature policy='require' name='invtsc'/>
  </cpu>                               
```

```
  <clock offset="localtime">
    <timer name="rtc" present="no" tickpolicy="catchup"/>
    <timer name="pit" present="no" tickpolicy="delay"/>
    <timer name="hpet" present="no"/>
    <timer name="kvmclock" present="no"/>
    <timer name="hypervclock" present="yes"/>
    <timer name="tsc" present="yes" mode="native"/>
  </clock>
```	

</details>

## IOMMU, libvirt and QEMU configuration

* Make sure IOMMU is enabled in the BIOS. For the ASRock motherboard (in my case) it is located in Advanced > AMD CBS > NBIO Common Options > NB Configuration > IOMMU

* Append ```iommu=pt iommu=1``` [kernel parameters](https://wiki.archlinux.org/title/kernel_parameters). 
  If you are using the GRUB bootloader, change the /etc/default/grub: 
  ```
  GRUB_CMDLINE_LINUX_DEFAULT="loglevel=3 quiet amdgpu.ppfeaturemask=0xffffffff iommu=pt iommu=1"
  ```

* Update the GRUB configuration and reboot:
  ```
  sudo grub-mkconfig -o /boot/grub/grub.cfg 
  ```

* Install the necessary Arch Linux packages:
  ```
  sudo pacman -S qemu-desktop edk2-ovmf libvirt iptables-nft dnsmasq bridge-utils dmidecode virt-manager
  ```
  * For remote management over SSH, install this package:
    ```
    sudo pacman -S openbsd-netcat
    ```  
  * For Windows 11 installation, you will need a TPM emulator, install this package:
    ```
    sudo pacman -S swtpm
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

## Windows 10/11 virt-manager preparation and installation (without going into details)
* You can follow [this virt-manager tutorial](https://github.com/bryansteiner/gpu-passthrough-tutorial#part3)

* Open the virt-manager and prepare Windows iso, also use the ```raw``` image virtio disk. For Windows 11, you need to have over 54 GB of storage space.

* Use the Q35 chipset and UEFI OVMF_CODE loader. For Windows 11, use the secure boot loader OVMF_CODE.secboot.fd. 

* Before installing the Windows, mount the [virtio-win.iso](https://fedorapeople.org/groups/virt/virtio-win/direct-downloads/) disk first in virt-manager
  * <details>
	
      <summary>virt-manager virtio-win.iso mounting</summary>
  
      ![Screenshot from 2022-05-23 15-24-43](https://user-images.githubusercontent.com/32335484/169831867-c173ccae-de54-4bf4-bf7e-e1a29f855f33.png)

    </details>
    
* For Win11 installation, add a TPM emulator in your xml file:
  ```
  <tpm model="tpm-tis">
    <backend type="emulator" version="2.0"/>
  </tpm>
  ```

* In order to recognize virtio disk, don't forget to load virtio driver from virtio-win.iso in the Windows installation.
  * <details>
	
      <summary>Virtio storage driver loading procedure</summary>
  
      ![Screenshot from 2022-05-21 17-31-56](https://user-images.githubusercontent.com/32335484/169829750-a95c0d90-78ed-4b86-ad86-9d6f71557cf7.png)
	
      ![Screenshot from 2022-05-21 17-31-11](https://user-images.githubusercontent.com/32335484/169829787-58e1fa9e-994d-4b45-8726-9e28ce684049.png)
	
      ![Screenshot from 2022-05-21 17-32-27](https://user-images.githubusercontent.com/32335484/169829829-476fd7c4-fa7e-43f5-b0ee-de57a5d0e833.png)

    </details>

* After the installation, boot into Windows and install all virtio drivers from the device manager. You can get drivers from virtio-win.iso
    * <details>
	
        <summary>Virtio Windows drivers</summary>
  
        ![Screenshot from 2022-05-21 17-43-50](https://user-images.githubusercontent.com/32335484/169830239-0d79a8d8-3f13-42d1-bdb8-c3ba5429536b.png)

        ![Screenshot from 2022-05-21 17-45-29](https://user-images.githubusercontent.com/32335484/169830274-40d7e230-7183-4301-91df-6d8e8d5d227d.png)

    </details>

* Disable memballoon in your xml file:
  ```
  <memballoon model="none"/>
  ```

* Test the CPU pinning before the GPU passthrough. Edit your xml file, for details, [check out the 6-core CPUs topology and comments above](https://github.com/Zile995/Ryzen-2600_RX-580-GPU-Passthrough#ryzen-5-2600-cpu-topology-example). **For 8-core CPUs** check [this reddit post](https://www.reddit.com/r/VFIO/comments/erwzrg/comment/ftr99em/)! Also check the [win10.xml](https://github.com/Zile995/Ryzen-2600_RX-580-GPU-Passthrough/blob/main/win10.xml) example file

* Next, you will need to add and edit libvirt hook scripts 
 
## Libvirt hooks

* <details>
  <summary>Directory structure</summary>

  ![tree](https://user-images.githubusercontent.com/32335484/170743513-347ccb10-f963-4da2-8cd4-c0adfffe9870.png)

  </details>
  
* Move hooks [folder](https://github.com/Zile995/Ryzen-2600_RX-580-GPU-Passthrough/tree/main/hooks) from this repository to /etc/libvirt/
    * ```sudo cp -r hooks /etc/libvirt/```

* Make sure the folder name in ```/etc/libvirt/hooks/qemu.d/``` matches the name of the virtual machine. Rename win10 if necessary.
  
* You will need to **examine and edit** the scripts.
  * You have to edit ```/etc/libvirt/hooks/cores.conf``` file. Edit each core variable, for systemd cpu pinning. The values ​​must match the values (vcpupin and emulatiorpin cores) ​​in the xml file. Also, edit masks.
  
  * You have to edit ```/etc/libvirt/hooks/kvm.conf``` file. Edit ```VIRSH_GPU_VIDEO``` and ```VIRSH_GPU_VIDEO``` variables. You can find VGA GPU and GPU HDMI Audio PCI IDs with ```lspci -k``` command:
    ```
    0a:00.0 VGA compatible controller: Advanced Micro Devices, Inc. [AMD/ATI] Ellesmere [Radeon RX 470/480/570/570X/580/580X/590] (rev e7)
	  Subsystem: Sapphire Technology Limited Nitro+ Radeon RX 570/580/590
	  Kernel driver in use: amdgpu    <- We need to unload this driver
	  Kernel modules: amdgpu    
    
    0a:00.1 Audio device: Advanced Micro Devices, Inc. [AMD/ATI] Ellesmere HDMI Audio [Radeon RX 470/480 / 570/580/590]
 	  Subsystem: Sapphire Technology Limited Device aaf0
	  Kernel driver in use: snd_hda_intel
	  Kernel modules: snd_hda_intel
    ```
  * In my case, final IDs for ```0a:00.0``` and ```0a:00.1``` devices will be: 
    ```
    * Final IDs
    * VIRSH_GPU_VIDEO:   0000:0a:00.0
    * VIRSH_GPU_VIDEO:   0000:0a:00.1
    ```

* The release script [release.sh](https://github.com/Zile995/PinnacleRidge-Polaris-GPU-Passthrough/blob/main/hooks/qemu.d/win10/release/end/release.sh) will set the ondemand governor. Change ```set_ondemand_governor()``` function in ```release.sh``` to schedutil if necessary.
    
## Passthrough (virt-manager)
* You can follow [this virt-manager tutorial](https://github.com/bryansteiner/gpu-passthrough-tutorial#part3)

* Open the virt-manager and add GPU PCI Host devices, both GPU and HDMI Audio devices. Remove DisplaySpice, VideoQXL and other serial devices only from XML file.
  * ```
    <!-- Remove Display Spice -->
    <graphics type="spice" port="-1" tlsPort="-1" autoport="yes">
      <image compression="off"/>
    </graphics>
    
    <!-- Remove USB Redirection -->
    <redirdev bus="usb" type="spicevmc"/>
    <redirdev bus="usb" type="spicevmc"/>
    
    <!-- Remove Video QXL -->
    <video>
      <model type="qxl"/>
    </video>
    
    <!-- Remove Tablet -->
    <input type="tablet" bus="usb"/>
    
    <!-- Remove console -->
    <console type="pty"/>
    ```
  * <details>
	
      <summary>Adding GPU PCI Host devices</summary>
  
      ![Screenshot from 2022-05-23 15-48-07](https://user-images.githubusercontent.com/32335484/169833957-2c48ff46-bd9c-40a7-95c1-2c3bc72bc72a.png)

    </details>

* Add USB Host devices, like keyboard, mouse... You can also follow [this tutorial](https://wiki.archlinux.org/index.php/PCI_passthrough_via_OVMF#Passing_keyboard/mouse_via_Evdev)  

* For sound: You can passthrough the PCI HD Audio controler or you can use [qemu pusleaudio passthrough](https://wiki.archlinux.org/title/PCI_passthrough_via_OVMF#Passing_audio_from_virtual_machine_to_host_via_PulseAudio) or [qemu pipewire passthrough](https://wiki.archlinux.org/title/PCI_passthrough_via_OVMF#Passing_audio_from_virtual_machine_to_host_via_JACK_and_PipeWire)

* Set the network source to ```Bridge device``` with ```virbr0``` device name and ```virtio``` device model.
  * <details>
	
      <summary>virt-manager network configuration</summary>
	
      ![Screenshot from 2022-05-23 15-58-43](https://user-images.githubusercontent.com/32335484/169836330-874c4f3a-06dd-4fb9-81fd-ba3c89ec0359.png)
	
    </details>  

* Don't forget to add vbios.rom file inside the win10.xml for the GPU and HDMI host PCI devices, example:
  ```
    ...
    </source>
    <rom file='/var/lib/libvirt/vbios/yourvbiosname.rom'/>  <!-- Place here -->
    <address/>
    ...
  ``` 

## Logging

* Check all hook logs with ```sudo cat /dev/kmsg | grep libvirt-qemu```

* Check all libvirt logs in ```/var/log/libvirt/libvirtd.log``` file

* Check all qemu logs in ```/var/log/libvirt/qemu/``` directory 
