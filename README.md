# KVM SR-IOV Drivers

## Description

The KVM SR-IOV driver enables support for SR-IOV devices, including Infiniband, in KVM virtual machines. The add-on has been developed for HPC orientated Clouds and includes a number of VM  performance enhancements.
 
The driver supports two modes for passing SR-IOV devices into VMs, generic and mlnx_ofed2. The generic mode is cable of passing any SR-IOV device into VMs, not limited to network devices.
 
The mlnx_ofed2 mode is tuned to pass IP information into VMs via GUIDs and also supports IB network isolation though a modification to the ovswitch VNM driver and IB partitions.
 
A HPC mode option can also be enabled to improve CPU and memory performance of the VM by passing though the exact CPU model and detecting and respecting NUMA nodes.

## Development

To contribute bug patches or new features, you can use the github Pull Request model. It is assumed that code and documentation are contributed under the Apache License 2.0. 

More info:
* [How to Contribute](http://opennebula.org/software:add-ons#how_to_contribute_to_an_existing_add-on)
* Support: [OpenNebula user mailing list](http://opennebula.org/community:mailinglists)
* Development: [OpenNebula developers mailing list](http://opennebula.org/community:mailinglists)
* Issues Tracking: Github issues

## Authors

* Leader: David Macleod (dmacleod@csir.co.za)
* Other

## Compatibility

This add-on has been tested with:
* CentOS 6.4
* Mellanox OFED 2.0-3.0.0
* libvirt 0.10.2
* OpenNebula 4.2

## Prerequisites and Limitations

1.	This driver has been developed to support OpenNebula 4.x and KVM. The driver should be backwards compatible the OpenNebula 3.x.
2.	SR-IOV capable hardware and software is required. Before using this driver SR-IOV must be functional on the VM host.
3.	Libvirt must run as root. This is required for the hypervisor to attach the SR-IOV virtual function to the VM.
4.	Any OpenNebula functions which rely on the .virsh save. command (stop, suspend and migrate) require the virtual functions to be hot plugged. This may cause unpredictable behaviour on the OS running in the VM. (More info)
5.	A virtual bridge is required when using the driver in generic mode. The VM will attach interfaces to this bridge but the OS will not use them. They are only required to pass IP address information into the VM. The bridge does not require any external connectivity, it just needs to exist. (More info)
6.	VF usage tracking is implemented in the /tmp file system. During a fatal host error the VF usage tracking might become out of sync with actual VF usage. You will have to manually recover. (More info)
7.	A modified context script is required to decode the SR-IOV interface information inside the VM. An example is given for Infiniband.
8.	The maximum number of VMs with SR-IOV interfaces that the host can support is limited by the number of VFs the root device exposes. Usually around 64.
9.	To use this driver with Ethernet SR-IOV devices you will need to modify the VM context script and take into consideration MAC prefixes. (More info)
10.	Network isolation with SR-IOV interfaces is only supported on Mellanox ConnectX-3 HCAs with OFED v2.0-3.0.0 and a patched version of the ovswitch VNM driver is required. (More info)
11.	IPv6 has not been tested.

## Installation

1- Clone Download and extract SR-IOV KVM Driver v0.2 to a temporary location

2- As root execute install.sh and follow the on-screen instructions

3- Edit /etc/one/oned.conf and add:

	VM_MAD = [
		name       = "kvm_sriov",
		executable = "one_vmm_exec",
		arguments  = "-t 15 -r 0 kvm-sriov",
		default    = "vmm_exec/vmm_exec_kvm.conf",
		type       = "kvm" ]

4- Use this guide to extract the bus slot and function addresses for the virtual functions: [Virtualization Host Configuration and Guest Installation Guide - SR_IOV - How SR_IOV_Libvirt Works](https://access.redhat.com/site/documentation/en-US/Red_Hat_Enterprise_Linux/6/html/Virtualization_Host_Configuration_and_Guest_Installation_Guide/sect-Virtualization_Host_Configuration_and_Guest_Installation_Guide-SR_IOV-How_SR_IOV_Libvirt_Works.html "Virtualization Host Configuration and Guest Installation Guide - SR_IOV - How SR_IOV_Libvirt Works")

5- In the /var/lib/one/remotes/vmm/kvm-sriov/vf_maps directory create a file with the name of the VF's root device, e.g. "ib0". In the file write the bus, slot and function for each VF you want the driver to use. The address must be in hexadecimal. Each line in the file represents a VF, the bus, slot and function addresses are separated by a single space character " ". __There may not be additional text, spaces or lines in the table.__

Example, four virtual functions:

/var/lib/one/remotes/vmm/kvm-sriov/vf_maps/ib0:

	0x07 0x00 0x01
	0x07 0x00 0x02
	0x07 0x00 0x03
	0x07 0x00 0x04
6- If using the driver in "mlnx_ofed2" mode you need to specify the device and port number of the interface. To find the device ID execute:

  ls /sys/class/infiniband
You will see a list of Infiniband devices "mlx4_<x>". The device ID is the <x>. To find the port ID execute:

  ls /sys/class/infiniband/mlx4_<x>/ports
You will see a list of numbers representing the ports available on the device.

Each interface which you have created a map for needs an additional file called "<map_name>_ofed", eg. "ib0_ofed". The file contains two lines specifying its associated device and port.

Example,

/var/lib/one/remotes/vmm/kvm-sriov/vf_maps/ib0_ofed:

	device 0
	port   1

7- On VM hosts using this driver edit /etc/libvirt/qemu.conf and change the user and group to "root" then restart libvirtd.

8- On the head node restart OpenNebula.

9- Create a virtual network in OpenNebula. The "Bridge" field must contain "sriov_" prepended to the name of the file that contains the VF mapings, e.g. "sriov_ib0"

10- Update the contextualisation scripts for the VMs with the code provided here.

11- Create hosts to use the "kvm_sriov" driver.

## Configuration

VF_MAPS_PATH:	The path where the driver must look for the VF map files

DUMMY_BRIDGE:	The bridge to which the dummy interfaces will be connected to

DUMMY_MAC_PREFIX:	The prefix used to differentiate SR-IOV devices from virtual devices

DRIVER_MODE:	Either "generic" or "mlnx_ofed2". Generic mode passes IP address to VMs through dummy interfaces. Mlnx_ofed2 mode encodes IP address in VF GUIDs

HPC_MODE:	Either "on" or "off". HPC mode improves the performance of VMs. The host's CPU is passed through to the VM, may break migration. The memory backing for the VM is set to huge pages, additional host configuration required. If a VM has as many vCPUs and the host has CPUs it is detected as a special case and the hosts NUMA architecture is passed to the VM. If a VM has as many vCPUs as a single NUMA node on the host the VM's CPUs will be pinned to a NUMA node.

## License

Apache v2.0 license.
