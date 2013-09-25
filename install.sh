#!/bin/bash
go=1
while [ $go -eq 1 ]
do
  echo "Select an option:"
  echo "1 Install"
  echo "0 Quit"
  read option
  if [ "$option" == "0" ]; then
    go=0
  elif [ "$option" == "1" ]; then
    echo "OpenNebula username: [oneadmin]"
    read username
    echo "OpenNebula group: [cloud]"
    read group
    echo "Enter VMM install directory: [/var/lib/one/remotes/vmm/kvm-sriov]"
    read vmm_dir
    echo "Enter Open vSwitch VNM directory: [/var/lib/one/remotes/vnm/ovswitch]"
    read vnm_dir
    backup_str=`date +%s`
    if [ "$username" == "" ]; then
      username="oneadmin"
    fi
    if [ "$group" == "" ]; then
      group="cloud"
    fi
    if [ "$vmm_dir" == "" ]; then
      vmm_dir="/var/lib/one/remotes/vmm/kvm-sriov"
    fi
    if [ "$vnm_dir" == "" ]; then
      vnm_dir="/var/lib/one/remotes/vnm/ovswitch"
    fi
    if [ -d $vmm_dir ]; then
      echo -e "VMM directory already exists, making a backup... \c"
      mv $vmm_dir $vmm_dir.backup_$backup_str
      echo "done."
    fi
    echo -e "Copying VMM directory... \c"
    cp -a vmm $vmm_dir
    chown -R $username:$group $vmm_dir
    echo "done."
    if [ -d $vnm_dir ]; then
      echo -e "VNM directory already exists, making a backup... \c"
      mv $vnm_dir $vnm_dir.backup_$backup_str
      echo "done."
    fi
    echo -e "Copying VNM directory... \c"
    cp -a vnm $vnm_dir
    chown -R $username:$group $vnm_dir
    echo "done."

    echo ""
    echo "-------------------------------------------------"
    echo "Installation complete, beginning configuration..."
    echo "-------------------------------------------------"

    echo "Specify the path to the VF map files: [/var/tmp/one/vmm/kvm-sriov/vf_maps]"
    read vf_map_path
    if [ "$vf_map_path" == "" ]; then
      vf_map_path="/var/tmp/one/vmm/kvm-sriov/vf_maps"
    fi
    line=`cat $vmm_dir/kvmrc | grep -n "VF_MAPS_PATH=" | cut -d ":" -f1`
    discard=`sed -i "${line}d" $vmm_dir/kvmrc`
    discard=`sed -i "${line}i\export VF_MAPS_PATH=$vf_map_path" $vmm_dir/kvmrc`

    echo "Specify the SR-IOV MAC prefix: [aa]"
    read mac_prefix
    if [ "$mac_prefix" == "" ]; then
      mac_prefix="aa"
    fi
    line=`cat $vmm_dir/kvmrc | grep -n "DUMMY_MAC_PREFIX=" | cut -d ":" -f1`
    discard=`sed -i "${line}d" $vmm_dir/kvmrc`
    discard=`sed -i "${line}i\export DUMMY_MAC_PREFIX=$mac_prefix" $vmm_dir/kvmrc`

    echo "Specify the SR-IOV bridge: [sriov_br]"
    read sriov_br
    if [ "$sriov_br" == "" ]; then
      sriov_br="sriov_br"
    fi
    line=`cat $vmm_dir/kvmrc | grep -n "DUMMY_BRIDGE=" | cut -d ":" -f1`
    discard=`sed -i "${line}d" $vmm_dir/kvmrc`
    discard=`sed -i "${line}i\export DUMMY_BRIDGE=$sriov_br" $vmm_dir/kvmrc`

    echo "Select the VMM driver mode:"
    echo "[1] generic"
    echo " 2  mlnx_ofed2"
    sel_err=1
    while [ $sel_err -eq 1 ]
    do
      read driver_mode
      if [ "$driver_mode" == "" ]; then
        driver_mode="1"
      fi
      if [ "$driver_mode" == "1" ]; then
        line=`cat $vmm_dir/kvmrc | grep -n "DRIVER_MODE=" | cut -d ":" -f1`
        discard=`sed -i "${line}d" $vmm_dir/kvmrc`
        discard=`sed -i "${line}i\export DRIVER_MODE=generic" $vmm_dir/kvmrc`
        sel_err=0
      elif [ "$driver_mode" == "2" ]; then
        line=`cat $vmm_dir/kvmrc | grep -n "DRIVER_MODE=" | cut -d ":" -f1`
        discard=`sed -i "${line}d" $vmm_dir/kvmrc`
        discard=`sed -i "${line}i\export DRIVER_MODE=mlnx_ofed2" $vmm_dir/kvmrc`
        sel_err=0
      else
        echo "Enter either 1 or 2"
      fi
    done

    echo "Do you want to enable HPC mode? y/[n]"
    sel_err=1
    while [ $sel_err -eq 1 ]
    do
      read hpc_mode
      if [ "$hpc_mode" == "" ]; then
        hpc_mode="n"
      fi
      if [ "$hpc_mode" == "y" ]; then
        line=`cat $vmm_dir/kvmrc | grep -n "HPC_MODE=" | cut -d ":" -f1`
        discard=`sed -i "${line}d" $vmm_dir/kvmrc`
        discard=`sed -i "${line}i\export HPC_MODE=on" $vmm_dir/kvmrc`
        sel_err=0
      elif [ "$hpc_mode" == "n" ]; then
        line=`cat $vmm_dir/kvmrc | grep -n "HPC_MODE=" | cut -d ":" -f1`
        discard=`sed -i "${line}d" $vmm_dir/kvmrc`
        discard=`sed -i "${line}i\export HPC_MODE=off" $vmm_dir/kvmrc`
        sel_err=0
      else
        echo "Enter either y or n"
      fi
    done

    echo -e "Calling onehost sync... \c"
    sudo -u $username -H sh -c "onehost sync"
    echo "done."

    echo ""
    echo "---------------------------------------------------------------------"
    echo "To finish the configuration you need to complete the following steps:"
    echo ""
    echo "1. Edit the sudoers file on the VM hosts and add these lines: "
    echo "   $username    ALL=(ALL) NOPASSWD: $vnm_dir/sbin/apply_pkey_map.sh *"
    echo "   $username    ALL=(ALL) NOPASSWD: $vmm_dir/sbin/wr_guid.sh *"
    echo ""
    echo "2. Create map files for your virtual functions. Detailed instructions"
    echo "   can be found here:"
    echo "   http://wiki.chpc.ac.za/acelab:opennebula_sr-iov_vmm_driver"
    echo "---------------------------------------------------------------------"
    echo ""

    go=0
  fi

done

exit 0
