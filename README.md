# AMD Single GPU Passthrough

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

<h2>
    Table of Contents
</h2>

* [Ryzen 5 2600 CPU Topology example](#topology)
* [IOMMU, libvirt, QEMU and vBIOS configuration](#configuration)
* [Windows 10/11 virt-manager preparation and installation](#windows_preparation)
* [CPU Pinning](#cpu_pinning)
* [Libvirt hooks](#libvirt_hooks)
* [Passthrough](#passthrough)
* [Logging](#logging)

<h2 name="topology">
    Ryzen 5 2600 CPU Topology example:
</h2>

<details>
  <summary>System topology (lstopo)</summary>

  ![Screenshot_20210417_121900](https://user-images.githubusercontent.com/32335484/115109624-32f87380-9f77-11eb-8081-7054ef6a1eff.png)

</details>

<details>
  <summary>Coreinfo L3 cache</summary>

  ![Coreinfo](https://user-images.githubusercontent.com/32335484/150604836-d8f342f6-f35b-4aaa-b759-d4e83cb3ddc6.png)

</details>

<h2 name="configuration">
    IOMMU, libvirt, QEMU and vBIOS configuration
</h2>

* Make sure IOMMU is enabled in the BIOS. For ASRock motherboards it should be in: Advanced > AMD CBS > NBIO Common Options > NB Configuration > IOMMU

* Append `iommu=pt iommu=1` [kernel parameters](https://wiki.archlinux.org/title/kernel_parameters). 
  If you are using the GRUB bootloader, change the `/etc/default/grub`: 
  ```Shell
  GRUB_CMDLINE_LINUX_DEFAULT="loglevel=3 quiet iommu=pt iommu=1"
  ```

* Update the GRUB configuration and reboot:
  ```Shell
  sudo grub-mkconfig -o /boot/grub/grub.cfg 
  ```

* Install the necessary Arch Linux packages:
  ```Shell
  sudo pacman -S qemu-desktop edk2-ovmf libvirt iptables-nft dnsmasq bridge-utils dmidecode virt-manager
  ```
  * For remote management over SSH, install this package:
    ```Shell
    sudo pacman -S openbsd-netcat
    ```  
  * For Windows 11 installation, you will need a TPM emulator, install this package:
    ```Shell
    sudo pacman -S swtpm
    ```
 
* Enable and start libvirt services:
  ```Shell
  sudo systemctl enable --now libvirtd.service
  sudo systemctl start virtlogd.service
  ```

* Add a user to `libvirt` and `kvm` groups:
  ```Shell
  sudo usermod -aG libvirt kvm yourusername
  ```

* If you want to use static hugepages:
  * Check if you have the directory `/dev/hugepages`. If not, create it. 
  * Mount the hugepages in `/etc/fstab` and reboot:
    ```Shell
    hugetlbfs	/dev/hugepages	hugetlbfs	mode=01770,gid=kvm	0 0
    ```

* Don't forget to edit:
  * /etc/libvirt/libvirtd.conf
    ```Shell
    unix_sock_group = "libvirt"
    unix_sock_ro_perms = "0777"
    unix_sock_rw_perms = "0770"
    auth_unix_ro = "none"
    auth_unix_rw = "none"
    log_filters = "2:libvirt.domain 1:qemu"
    log_outputs = "1:file:/var/log/libvirt/libvirtd.log"
    ```
  * /etc/libvirt/qemu.conf
    ```Shell
    user = "yourusername"
    group = "kvm"
    ```
 
* You might need to start the default network manually:
  ```Shell
  sudo virsh net-start default
  sudo virsh net-autostart default
  ```

* Restart the libvirt services after every modification:
  ```Shell
  sudo systemctl restart libvirtd.service virtlogd.service
  ```

* Dump your vBIOS with [amdvbflash](https://github.com/stylesuxx/amdvbflash):
  * Dump it with: `sudo amdvbflash -s 0 yourvbiosname.rom`
  * vBIOS will be created in home directory
  * Move your GPU vBIOS file to `/var/lib/libvirt/vbios` directory. If you don't have this directory, create it. 
  * Set the correct permissions and ownership for your vBIOS file:
    ```Shell
    sudo chmod -R 775 /var/lib/libvirt/vbios/yourvbiosname.rom
    sudo chown yourusername:yourusername /var/lib/libvirt/vbios/yourvbiosname.rom
    ```

<h2 name="windows_preparation">
    Windows 10/11 virt-manager preparation and installation (without going into details)
</h2>

* You can follow [this virt-manager tutorial](https://github.com/bryansteiner/gpu-passthrough-tutorial#part3)

* Open the virt-manager and prepare Windows iso, also use the `raw` image virtio disk. For Windows 11, you need to have over 54 GB of storage space.

* Use the `Q35` chipset and UEFI `OVMF_CODE` loader. For Windows 11, use the secure boot loader `OVMF_CODE.secboot.fd`. 

* Before installing the Windows, mount the [virtio-win.iso](https://fedorapeople.org/groups/virt/virtio-win/direct-downloads/) disk first in virt-manager
  * <details>
	
      <summary>virt-manager virtio-win.iso mounting</summary>

      ![virtio-win.iso mounting](https://user-images.githubusercontent.com/32335484/169831867-c173ccae-de54-4bf4-bf7e-e1a29f855f33.png)

    </details>

* For Win11 installation, add a TPM emulator in your xml file:
  ```XML
  <tpm model="tpm-tis">
    <backend type="emulator" version="2.0"/>
  </tpm>
  ```

* In order to recognize virtio disk, don't forget to load virtio driver from `virtio-win.iso` in the Windows installation.
  * <details>
	
      <summary>Virtio storage driver loading procedure</summary>

      ![Load driver](https://user-images.githubusercontent.com/32335484/169829750-a95c0d90-78ed-4b86-ad86-9d6f71557cf7.png)
	
      ![Select folder](https://user-images.githubusercontent.com/32335484/169829787-58e1fa9e-994d-4b45-8726-9e28ce684049.png)
	
      ![Install driver](https://user-images.githubusercontent.com/32335484/169829829-476fd7c4-fa7e-43f5-b0ee-de57a5d0e833.png)

    </details>

* After the installation, boot into Windows and install all virtio drivers from the device manager. You can get drivers from virtio-win.iso
    * <details>
	
        <summary>Virtio Windows drivers</summary>

        ![Virtio win drivers 1](https://user-images.githubusercontent.com/32335484/169830239-0d79a8d8-3f13-42d1-bdb8-c3ba5429536b.png)

        ![Virtio win drivers 2](https://user-images.githubusercontent.com/32335484/169830274-40d7e230-7183-4301-91df-6d8e8d5d227d.png)

    </details>

* Disable `memballoon` in your xml file:
  ```XML
  <devices>
    ...
    <memballoon model='none'/>
  </devices>
  ```

<h2 name="cpu_pinning">
    CPU Pinning
</h2>

* You should edit your xml file and test the CPU pinning before the GPU passthrough. For details check out the 6-core CPUs topology and comments below:

  * <details>
      <summary>XML Config, Ryzen 2600 2 x 3-core CCX CPU Pinning example</summary>

      ### CPU Pinning
      ```XML 
                   L3                         L3
	
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

      ### Enabling Hyper-V enlightenments (Windows only)
      ```XML
      <hyperv mode='custom'>
        <relaxed state='on'/>
        <vapic state='on'/>
        <spinlocks state='on' retries='8191'/>
        <vpindex state='on'/>
        <runtime state='on'/>
        <synic state='on'/>
        <stimer state='on'/>
        <reset state='on'/>
        <vendor_id state='on' value='ASRock'/>  <!-- The value doesn't matter -->
        <frequencies state='on'/>
        <reenlightenment state='off'/>   <!-- We use only one guest. Not fully supported on KVM, disable it. -->
        <tlbflush state='on'/>
        <ipi state='on'/>
        <evmcs state='off'/> 		<!-- We do not use nested KVM in Hyper-v -->
      </hyperv>
      ```

      ### KVM features
      ```XML
      <kvm>
        <hidden state='on'/>
        <hint-dedicated state='on'/>
      </kvm>
      <vmport state='off'/>
      <ioapic driver='kvm'/>
      ```

      ### Passthrough mode and policy
      ```XML

      <cpu mode='host-passthrough' check='none' migratable='on'>  <!-- Set the cpu mode to passthrough -->
        <topology sockets='1' dies='1' cores='6' threads='2'/>    <!-- Match the cpu topology. In my case 6c/12t, or 2 threads per each core -->
        <cache mode='passthrough'/>                     <!-- The real CPU cache data reported by the host CPU will be passed through to the virtual CPU -->
        <feature policy='require' name='topoext'/>  <!-- Required for the AMD CPUs -->
        <feature policy='require' name='svm'/>
        <feature policy='require' name='apic'/>         <!-- Enable various features improving behavior of guests running Microsoft Windows -->
        <feature policy='require' name='hypervisor'/>
        <feature policy='require' name='invtsc'/>
      </cpu>                               
      ```

      ### Timers
      ```XML
     
      <clock offset="localtime">
        <timer name="rtc" present="no" tickpolicy="catchup"/>
        <timer name="pit" present="no" tickpolicy="delay"/>
        <timer name="hpet" present="no"/>
        <timer name="kvmclock" present="no"/>
        <timer name="hypervclock" present="yes"/>
        <timer name="tsc" present="yes" mode="native"/>
      </clock>
      ```

      ### Additional libvirt attributes
      ```XML
      <devices>
      ...
        <memballoon model='none'/>    <!-- Disable memory ballooning -->
        <panic model='hyperv'/>	<!-- Provides additional crash information when Windows crashes -->
      </devices>
     ```

     ### Additional QEMU agrs
     ```XML
     <domain type='kvm' xmlns:qemu='http://libvirt.org/schemas/domain/qemu/1.0'> <!-- Modify virtual machine domain configuration! -->
     ...
       </devices>
       <qemu:commandline>
         <qemu:arg value='-overcommit'/>
         <qemu:arg value='cpu-pm=on'/>
       </qemu:commandline>
     </domain>  
     ```

</details>

* **For 8-core CPUs** and 6 physical cores / 12 virtual cores setups, check [this reddit post](https://www.reddit.com/r/VFIO/comments/erwzrg/comment/ftr99em/)! Also check the [win10.xml](https://github.com/Zile995/Ryzen-2600_RX-580-GPU-Passthrough/blob/main/win10.xml) example file.
 
<h2 name="libvirt_hooks">
    Libvirt hooks
</h2>

* <details>
  <summary>Directory structure</summary>

  ![tree](https://user-images.githubusercontent.com/32335484/219906789-a7ab85a8-2c0a-4e23-a806-6d4c89c6b860.png)

  </details>

* Move [hooks](https://github.com/Zile995/Ryzen-2600_RX-580-GPU-Passthrough/tree/main/hooks) directory from this repository to `/etc/libvirt/`
    * `sudo cp -r hooks /etc/libvirt/`

* Make sure the directory name in `/etc/libvirt/hooks/qemu.d/` matches the name of the virtual machine. Rename win10 if necessary.

* You will need to **examine and edit** the scripts.
  * You have to edit `/etc/libvirt/hooks/cores.conf` file. Edit each core variable used for systemd cpu pinning. The values **must** match the values (`vcpupin` and `emulatiorpin` cores) in the xml file. Emulator pin cores represent host machine cores, while vcpupin cores represents virtual machine cores. The variable names are self-explanatory. Also, edit masks:
    ```Shell
    TOTAL_CORES='0-11'
    TOTAL_CORES_MASK=FFF               # 0-11, bitmask 0b111111111111
    HOST_CORES='0,3,6,9'               # Cores reserved for host
    HOST_CORES_MASK=924                # 0,3,6,9 bitmask 0b100100100100
    VIRT_CORES='1-2,4-5,7-8,10-11'     # Cores reserved for virtual machine(s)
    ```

  * You have to edit `/etc/libvirt/hooks/kvm.conf` file. Edit `VIRSH_GPU_VIDEO` and `VIRSH_GPU_VIDEO` variables. You can find VGA GPU and GPU HDMI Audio PCI IDs using the `lspci -k` command:
    ```Shell
    0a:00.0 VGA compatible controller: Advanced Micro Devices, Inc. [AMD/ATI] Ellesmere [Radeon RX 470/480/570/570X/580/580X/590] (rev e7)
	  Subsystem: Sapphire Technology Limited Nitro+ Radeon RX 570/580/590
	  Kernel driver in use: amdgpu    <- We need to unload this driver
	  Kernel modules: amdgpu    
    
    0a:00.1 Audio device: Advanced Micro Devices, Inc. [AMD/ATI] Ellesmere HDMI Audio [Radeon RX 470/480 / 570/580/590]
 	  Subsystem: Sapphire Technology Limited Device aaf0
	  Kernel driver in use: snd_hda_intel
	  Kernel modules: snd_hda_intel
    ```
  * In my case, final IDs for `0a:00.0` and `0a:00.1` devices will be: 
    ```Shell
    * Final IDs
    * VIRSH_GPU_VIDEO:   0000:0a:00.0
    * VIRSH_GPU_VIDEO:   0000:0a:00.1
    ```

* The release script [release.sh](https://github.com/Zile995/PinnacleRidge-Polaris-GPU-Passthrough/blob/main/hooks/qemu.d/win10/release/end/release.sh) will set the ondemand governor. Change to schedutil governor by using the `set_schedutil_governor` function instead of the `set_ondemand_governor` function:
  ```Shell
  if [[ "$VM_ACTION" == "release/end" ]]; then
      release_cores
      # set_ondemand_governor
      set_schedutil_governor
      remove_vfio_modules
      load_amd_gpu
      restart_systemd_services
  fi
  ```
 
* You should stop your display manager systemd service in [prepare.sh](https://github.com/Zile995/PinnacleRidge-Polaris-GPU-Passthrough/blob/main/hooks/qemu.d/win10/prepare/begin/prepare.sh) script and restart it in [release.sh](https://github.com/Zile995/PinnacleRidge-Polaris-GPU-Passthrough/blob/main/hooks/qemu.d/win10/release/end/release.sh) script. I am using `gdm`, so these scripts stop/restart it by default. For example, for SDDM, the recommended display manager for the `KDE Plasma` and `LXQt` desktop environments, you can use `systemctl stop sddm.service` command to stop it. **Stop/restart** your display manager service in the `stop_systemd_services`/`restart_systemd_services` function:
  ```Shell
  stop_systemd_services() {
      # systemctl stop sddm.service
      # systemctl stop lightdm.service
      # --> Set your display manager instead of gdm if necessary...
      systemctl stop gdm.service
      printer "Successfully stopped systemd services"
  }
  
  restart_systemd_services() {
      # --> Restart your display manager...
      systemctl restart gdm.service
      printer "Successfully restarted systemd services"
  }
  ```

<h2 name="passthrough">
    Passthrough
</h2>

* Open the virt-manager and add the GPU PCI devices, both GPU and HDMI Audio devices. Remove DisplaySpice, VideoQXL and other serial devices from the XML file:

  * <details>
	
      <summary>Adding the GPU PCI devices</summary>

      ![GPU PCI devices](https://user-images.githubusercontent.com/32335484/169833957-2c48ff46-bd9c-40a7-95c1-2c3bc72bc72a.png)

    </details>

  * ```XML
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

* Add USB Host devices, like keyboard, mouse... You can also follow [this tutorial](https://wiki.archlinux.org/index.php/PCI_passthrough_via_OVMF#Passing_keyboard/mouse_via_Evdev)

* You can passthrough the PCI HD Audio controller, but be careful with adding controllers, they can be problematic. Instead, you can use [qemu pusleaudio passthrough](https://wiki.archlinux.org/title/PCI_passthrough_via_OVMF#Passing_audio_from_virtual_machine_to_host_via_PulseAudio) or [qemu pipewire passthrough](https://wiki.archlinux.org/title/PCI_passthrough_via_OVMF#Passing_audio_from_virtual_machine_to_host_via_JACK_and_PipeWire)
  * In case you are using pipewire, you need to set the `connectPorts` pipewire-jack ports. To see the required jack ports, install the following package:
     `sudo pacman -S jack-example-tools`
  * Then run the `jack_lsp` command and find the appropriate ports.
  * Add one `ich9` sound device with one `jack` audio device and set `connectPorts`, as it can be seen in the xml example, below:

    ```XML
    <sound model='ich9'>
      <codec type='micro'/>
      <audio id='1'/>
      <address type='pci' domain='0x0000' bus='0x00' slot='0x1b' function='0x0'/>
    </sound>
    <audio id='1' type='jack'>
      <input clientName='win10' connectPorts='Family 17h.*capture_F[LR]'/>       <!-- The client name is usually set as the vm name -->
      <output clientName='win10' connectPorts='Family 17h.*playback_F[LR]'/>
    </audio>
    ```
  * Then modify the virtual machine domain configuration (`<domain ... >` line) and add the following QEMU arguments, `PIPEWIRE_RUNTIME_DIR` and `PIPEWIRE_LATENCY`:

    ```XML
    <domain type='kvm' xmlns:qemu='http://libvirt.org/schemas/domain/qemu/1.0'>
      <devices>    
      ...
      </devices>
      <qemu:commandline>
        <qemu:env name='PIPEWIRE_RUNTIME_DIR' value='/run/user/1000'/>  <!-- Use the id command to find the correct ID -->
        <qemu:env name='PIPEWIRE_LATENCY' value='512/48000'/>  <!-- Set desired latency --> 
      </qemu:commandline>
    </domain>
    ```
  * If you cannot save changes in the virt-manager XML editor, edit with the following command: `sudo virsh edit win10`. Replace `win10` with your VM name. This command expects the `vi` editor. If you don't have it installed, you can run the command with different `EDITOR` like this: `sudo EDITOR=nano virsh edit vmname`

* Set the network source to `Bridge device` with `virbr0` device name and `virtio` device model.
  * <details>
	
      <summary>virt-manager network configuration</summary>
	
      ![virtio-net](https://user-images.githubusercontent.com/32335484/169836330-874c4f3a-06dd-4fb9-81fd-ba3c89ec0359.png)
	
    </details> 

* Don't forget to add vbios.rom file inside the win10.xml for the GPU and HDMI host PCI devices, example:
  ```XML
    ...
    </source>
    <rom file='/var/lib/libvirt/vbios/yourvbiosname.rom'/>  <!-- Place here -->
    <address/>
    ...
  ``` 

<h2 name="logging">
    Logging
</h2>

* Check hook logs with `journalctl | grep 'libvirt-qemu'`
  * <details>
	
      <summary>Journal output</summary>
      
      ![journal](https://user-images.githubusercontent.com/32335484/219905798-08385d4d-a2f5-40ee-9926-e1cc1a68d7e9.png)

    </details> 

* Check libvirt logs in `/var/log/libvirt/libvirtd.log` file

* Check qemu logs in `/var/log/libvirt/qemu/` directory 
