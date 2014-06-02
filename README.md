# OpenNebula KVM SR-IOV Driver

The KVM SR-IOV driver enables support for SR-IOV devices, including Infiniband, in KVM virtual machines. The add-on has been developed for HPC orientated Clouds and includes a number of VM performance enhancements.

The driver supports two modes for passing SR-IOV devices into VMs, generic and mlnx_ofed2. The generic mode is capable of passing any SR-IOV device into VMs, not limited to network devices.

The mlnx_ofed2 mode is tuned to pass IP information into VMs via GUIDs and also supports IB network isolation though a modification to the ovswitch VNM driver and IB partitions.

A HPC mode option can also be enabled to improve CPU and memory performance of the VM by passing though the exact CPU model and detecting and respecting NUMA nodes.

Demonstration Video:
[OpenNebula KVM SR-IOV Driver](http://www.youtube.com/watch?v=wB-Z1o2jGaY)

## Prerequisites and Limitations

1. This driver has been developed to support OpenNebula 4.x and KVM. The driver should be backwards compatible the OpenNebula 3.x.
2. SR-IOV capable hardware and software is required. Before using this driver SR-IOV must be functional on the VM host. 
3. Libvirt must run as root. This is required for the hypervisor to attach the SR-IOV virtual function to the VM. 
4. Any OpenNebula functions which rely on the .virsh save. command (stop, suspend and migrate) require the virtual functions to be hot plugged. This may cause unpredictable behaviour on the OS running in the VM. ([More info](https://github.com/OpenNebula/addon-kvm-sr-iov/wiki#libvirt-save-command))
5. A virtual bridge is required when using the driver in generic mode. The VM will attach interfaces to this bridge but the OS will not use them. They are only required to pass IP address information into the VM. The bridge does not require any external connectivity, it just needs to exist. ([More info](https://github.com/OpenNebula/addon-kvm-sr-iov/wiki/#dummy-bridge-and-interfaces))
6. VF usage tracking is implemented in the _/tmp_ file system. During a fatal host error the VF usage tracking might become out of sync with actual VF usage. You will have to manually recover. ([More info](https://github.com/OpenNebula/addon-kvm-sr-iov/wiki/#vf-usage-tracking))
7. A modified context script is required to decode the SR-IOV interface information inside the VM. An [example](https://github.com/OpenNebula/addon-kvm-sr-iov/wiki/#context-script-modification) is given for Infiniband.
8. The maximum number of VMs with SR-IOV interfaces that the host can support is limited by the number of VFs the root device exposes. Usually around 64.
9. To use this driver with Ethernet SR-IOV devices you will need to modify the VM context script and take into consideration MAC prefixes. ([More info](https://github.com/OpenNebula/addon-kvm-sr-iov/wiki/#ethernet-sr-iov-devices))
10. Network isolation with SR-IOV interfaces is only supported on Mellanox ConnectX-3 HCAs with OFED v2.0-3.0.0 or newer and a patched version of the ovswitch VNM driver is required. ([More info](https://github.com/OpenNebula/addon-kvm-sr-iov/wiki/#network-isolation))
11. IPv6 has not been tested.

## Testing Environment

* CentOS 6.5
* Mellanox OFED 2.2-1.0.1
* libvirt 0.10.2
* OpenNebula 4.6

## Installation 

1- Download and extract the [SR-IOV KVM Driver](https://github.com/OpenNebula/addon-kvm-sr-iov/archive/version_0.2.tar.gz) to a temporary location

2- As root execute _/install.sh_ and follow the on-screen instructions

3- Edit _/etc/one/oned.conf_ and add:

	VM_MAD = [
		name       = "kvm_sriov",
		executable = "one_vmm_exec",
		arguments  = "-t 15 -r 0 kvm-sriov",
		default    = "vmm_exec/vmm_exec_kvm.conf",
		type       = "kvm" ]

4- Use this guide to extract the bus slot and function addresses for the virtual functions: [Virtualization Host Configuration and Guest Installation Guide - SR_IOV - How SR_IOV_Libvirt Works](https://access.redhat.com/site/documentation/en-US/Red_Hat_Enterprise_Linux/6/html/Virtualization_Host_Configuration_and_Guest_Installation_Guide/sect-Virtualization_Host_Configuration_and_Guest_Installation_Guide-SR_IOV-How_SR_IOV_Libvirt_Works.html)

5- In the */var/lib/one/remotes/vmm/kvm-sriov/vf_maps* directory create a file with the name of the VF's root device, e.g. "ib0". In the file write the bus, slot and function for each VF you want the driver to use. The address must be in hexadecimal. Each line in the file represents a VF, the bus, slot and function addresses are separated by a single space character " ". **There may not be additional text, spaces or lines in the table**.

Example, four virtual functions:

*/var/lib/one/remotes/vmm/kvm-sriov/vf_maps/ib0*:

	0x07 0x00 0x01
	0x07 0x00 0x02
	0x07 0x00 0x03
	0x07 0x00 0x04

6- If using the driver in "mlnx\_ofed2" mode you need to specify the device and port number of the interface. To find the device ID execute: 
    ls /sys/class/infiniband
You will see a list of Infiniband devices "mlx4_\<x\>". The device ID is the \<x\>. To find the port ID execute:
    ls /sys/class/infiniband/mlx4_\<x\>/ports
You will see a list of numbers representing the ports available on the device.

Each interface which you have created a map for needs an additional file called "<map\_name>\_ofed", eg. "ib0\_ofed". The file contains two lines specifying its associated device and port.

Example,

*/var/lib/one/remotes/vmm/kvm-sriov/vf_maps/ib0_ofed*:

	device 0
	port   1

7- On VM hosts using this driver edit */etc/libvirt/qemu.conf* and change the user and group to "root" then restart libvirtd.

8- On the head node restart OpenNebula.

9- Create a virtual network in OpenNebula. The .Bridge. field must contain "sriov\_" prepended to the name of the file that contains the VF mapings, e.g. "sriov\_ib0"

10- Update the contextualisation scripts for the VMs with the code provided [here](https://github.com/OpenNebula/addon-kvm-sr-iov/wiki/#context-script-modification).

11- Create hosts to use the "kvm\_sriov" driver.

## Appendix

### Configuration Options

**VF_MAPS_PATH**: The path where the driver must look for the VF map files

**DUMMY_BRIDGE**: The bridge to which the dummy interfaces will be connected to

**DUMMY_MAC_PREFIX**: The prefix used to differentiate SR-IOV devices from virtual devices

**DRIVER_MODE**: Either "generic" or "mlnx\_ofed2". Generic mode passes IP address to VMs through dummy interfaces. "mlnx\_ofed2" mode encodes IP address in VF GUIDs

**HPC_MODE**: Either "on" or "off". HPC mode improves the performance of VMs. The host's CPU is passed through to the VM, may break migration. The memory backing for the VM is set to huge pages, [additional host configuration required](https://github.com/OpenNebula/addon-kvm-sr-iov/wiki/#huge-pages). If a VM has as many vCPUs and the host has CPUs it is detected as a special case and the hosts NUMA architecture is passed to the VM. If a VM has as many vCPUs as a single NUMA node on the host the VM's CPUs will be pinned to a NUMA node.

### Libvirt .save. command 

The .save. command saves the state of the VM's memory to the host's disk. This operation fails when a VM contains an SR-IOV device because it is passed through the hypervisor and not defined by it. As a result the device's memory state cannot be read, causing the save operation to fail.

To work around this issue the kvm-sriov driver will hot remove SR-IOV interfaces before executing the "save" command, and hot attach SR-IOV devices after executing the "restore" command.

This driver also supports live migration. Before migrating a VM the driver will attempt to acquire VF locks at the destination. If the migration fails the driver will attempt to reattach the devices at the source.

### Dummy Bridge and Interfaces

The dummy bridge and interfaces are only required if you operate the driver in the "generic" mode. In this mode the dummy interfaces will be attached to the dummy bridge to pass IP address into the VM.

If you operate the driver in the "mlnx_ofed2" mode it will encode IP address into the VM's Infiniband GUID. The contextualisation scripts must be modified to support reading IP address from GUIDs. An [example](https://github.com/OpenNebula/addon-kvm-sr-iov/wiki/#context-script-modification) is provided below.

### VF Usage Tracking

Libvirt does provide a built-in method for tracking VF usage but it does not support the Mellanox OFED 2 drivers. As a result I had to create my own usage tracking mechanism. If you are using this driver with an SR-IOV card which supports VF assignment from a pool then you can use the instructions found below to update the scripts:
[Libvirt VF Tracking](http://wiki.libvirt.org/page/Networking#Assignment_from_a_pool_of_SRIOV_VFs_in_a_libvirt_.3Cnetwork.3E_definition)

The independent tracking mechanism provided with this driver creates a vf_interfaces directory in the host's */tmp* directory. Inside the vf_interfaces directory a directory will be created for each SR-IOV root device. Inside the root device's directory files will be created to indicate that a VF is in use. For example, if the first, third and fourth VF are in use you see:

*/tmp/vf\_interfaces/ib0*:

	0
	2
	3

### Ethernet SR-IOV Devices

This driver will always put the libvirt interfaces used for passing IP information at the end of the devices list. This means that if you create a VM with a mix of SR-IOV and libvirt interfaces they will be labeled consecutively and in the same order as displayed in OpenNebula. 

Also, you must ensure that Ethernet VFs do not contain either the OpenNebula default MAC prefix or the one specified for identifying SR-IOV devices. To ensure this write a script that checks and sets the MAC addresses of the root device's VFs once the host has booted.

The context script will need to be updated to support the Ethernet devices, however the changes are minimal and simple.

### Huge Pages

Enabling huge pages on KVM virtual machines will greatly improve memory performance. To enable huge pages on your VM hosts follow these instructions:
[Huge Pages](http://www.linux-kvm.com/content/get-performance-boost-backing-your-kvm-guest-hugetlbfs)

Huge page backed VMs will be enabled if "HPC_MODE" is set to "on".

### Network Isolation

This driver supports network isolation on all virtual interfaces through the standard OpenNebula VNM drivers. Isolation on SR-IOV devices is only supported on Mellanox ConnectX-3 HCAs. The Infiniband isolation is implemented through a modified version of the "ovswitch" driver which ships with OpenNebula.

To use Infiniband isolation the host and network must be set to use the Open vSwitch driver. The IB Pkey is set in the VLAN field when creating a network. Note, the Pkey must be specified in decimal. It will be converted into hexadecimal and a full key will be generated from it.

The driver assumes the IB fabric has been correctly configured with the requested partitions. If during deployment the requested pkey is not found the virtual function will be blocked. If you do not specify a pkey the default partition will be used.

## Driver

  * [SR-IOV KVM Driver v0.2](https://github.com/OpenNebula/addon-kvm-sr-iov/archive/version_0.2.tar.gz)

### Context Script Modification

Edit the *00-network* script (in our case: */srv/one-context.d/00-network*). Update the gen\_network\_configuration() and gen\_iface\_conf() functions.

	gen_iface_conf() {
		cat <<EOT
		DEVICE=$DEV
		BOOTPROTO=none
		ONBOOT=yes
		####################
		# Update this      #
		####################
		TYPE=$TYPE
		#-------------------
		NETMASK=$MASK
		IPADDR=$IP
		EOT
		if [ -n "$GATEWAY" ]; then
			echo "GATEWAY=$GATEWAY"
		fi
		echo ""
	}
	
	gen_network_configuration() {
		IFACES=`get_interfaces`
		for i in $IFACES; do
			MAC=`get_mac $i`
			###################################
			# Update this                     #
			###################################
			ib_vf=$(echo "$MAC" | cut -c 1-2)
			ib_pos=$(echo "$MAC" | cut -c 5)
			if  [ "$ib_vf" == "AA" ]; then
				DEV="ib"$ib_pos
				UPCASE_DEV=`upcase $DEV`
				TYPE="Infiniband"
			else
				DEV=`get_dev $i`
				UPCASE_DEV=`upcase $DEV`
				TYPE="Ethernet"
			fi
			#-----------------------------------
			IP=$(get_ip)
			NETWORK=$(get_network)
			MASK=$(get_mask)
			GATEWAY=$(get_gateway)
			####################################
			# Update this                      #
			####################################
			if  [ "$ib_vf" == "AA" ]; then
				gen_iface_conf > /etc/sysconfig/network-scripts/ifcfg-ib$ib_pos
			else
				gen_iface_conf > /etc/sysconfig/network-scripts/ifcfg-${DEV}
			fi
			#-----------------------------------
		done
		####################################################################################################
		# Add this                                                                                         #
		####################################################################################################
		down_ifs=`ip addr | grep "mtu" | wc -l`
		position=0
		while [ $position -lt $down_ifs ]
		do
			position=$[$position + 1]
			is_ib=`ip addr | grep "mtu" -A 1 | grep link/ | sed "$position q;d" | grep infiniband | wc -l`
			if [ $is_ib -gt 0 ]; then
				DEV=`ip addr | grep "mtu" | sed "$position q;d" | awk '{print $2}' | cut -d ":" -f1`
				if [ ! -f /etc/sysconfig/network-scripts/ifcfg-${DEV} ]; then
					MAC=`ip addr | grep "mtu" -A 1 | grep link/ | sed "$position q;d" | awk '{print $2}' | rev | cut -c -17 | rev`
					UPCASE_DEV=`upcase $DEV`
					TYPE="Infiniband"
					IP=$(get_ip)
					NETWORK=$(get_network)
					MASK=$(get_mask)
					GATEWAY=$(get_gateway)
					gen_iface_conf > /etc/sysconfig/network-scripts/ifcfg-${DEV}
				fi
			fi
		done    
		#---------------------------------------------------------------------------------------------------
	}
  
Take note of:
  - "$ib\_vf" == "AA". This means that the script is expecting AA as the MAC prefix for SR-IOV devices.
  - gen\_iface_conf > /etc/sysconfig/network-scripts/ifcfg-ib$ib_pos. The ifcfg file is being generated for Infiniband.

## License

  Copyright 2013, CSIR Centre for High Performance Computing  
  Author: David Macleod
  
  Licensed under the Apache License, Version 2.0 (the "License"); you may
  not use this file except in compliance with the License. You may obtain
  a copy of the License at
  
  http://www.apache.org/licenses/LICENSE-2.0
  
  Unless required by applicable law or agreed to in writing, software
  distributed under the License is distributed on an "AS IS" BASIS, 
  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
  See the License for the specific language governing permissions and
  limitations under the License.

## Author Contact
  * David Macleod
  * dmacleod@csir.co.za 
