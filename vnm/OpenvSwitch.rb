# -------------------------------------------------------------------------- #
# Copyright 2002-2014, OpenNebula Project (OpenNebula.org), C12G Labs        #
#                                                                            #
# Licensed under the Apache License, Version 2.0 (the "License"); you may    #
# not use this file except in compliance with the License. You may obtain    #
# a copy of the License at                                                   #
#                                                                            #
# http://www.apache.org/licenses/LICENSE-2.0                                 #
#                                                                            #
# Unless required by applicable law or agreed to in writing, software        #
# distributed under the License is distributed on an "AS IS" BASIS,          #
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.   #
# See the License for the specific language governing permissions and        #
# limitations under the License.                                             #
#--------------------------------------------------------------------------- #

require 'OpenNebulaNetwork'

class OpenvSwitchVLAN < OpenNebulaNetwork
    DRIVER = "ovswitch"

    FIREWALL_PARAMS =  [:black_ports_tcp,
                        :black_ports_udp,
                        :icmp]

    XPATH_FILTER = "TEMPLATE/NIC"

    def initialize(vm, deploy_id = nil, hypervisor = nil)
        super(vm,XPATH_FILTER,deploy_id,hypervisor)
        @locking = false
	@one_deploy_id = deploy_id
    end

    def activate
        lock

	vf_pos = 0	

        process do |nic|
            @nic = nic

	    #Check if this nic contains the sriov keyword
	    str=@nic[:bridge]
	    str=str.slice! "sriov"
            if str == "sriov"
	      #If it is a sriov device apply IB pkey maps
	      if @nic[:vlan] == "YES"
		#If the network should be isolated
		if @nic[:vlan_id]
		  #If a vlan is specfied create the requested mapping
		  cmd=`sudo /var/tmp/one/vnm/ovswitch/sbin/apply_pkey_map.sh #{@nic[:vlan_id]} #{@one_deploy_id} #{vf_pos}`
        	else
		  #If no vlan is specified generate the vlan from the base vlan
		  build_vlan_id=CONF[:start_vlan] + @nic[:network_id].to_i
		  cmd=`sudo /var/tmp/one/vnm/ovswitch/sbin/apply_pkey_map.sh #{build_vlan_id} #{@one_deploy_id} #{vf_pos}`
		end
              else
		#If the network should not be isolated apply the default pkey
		cmd=`sudo /var/tmp/one/vnm/ovswitch/sbin/apply_pkey_map.sh no_vlan #{@one_deploy_id} #{vf_pos}`
              end
              vf_pos = vf_pos + 1

	    else

              if @nic[:tap].nil?
                  STDERR.puts "No tap device found for nic #{@nic[:nic_id]}"
                  unlock
                  exit 1
              end

              # Apply VLAN
              if @nic[:vlan] == "YES"
                  tag_vlan
                  tag_trunk_vlans
              end

              # Prevent Mac-spoofing
              mac_spoofing

              # Apply Firewall
              configure_fw if FIREWALL_PARAMS & @nic.keys != []
	    end
        end

        unlock

        return 0
    end

    def deactivate
        lock

        process do |nic|
            @nic = nic

            # Remove flows
            del_flows
        end

        unlock
    end

    def vlan
        if @nic[:vlan_id]
            return @nic[:vlan_id]
        else
            return CONF[:start_vlan] + @nic[:network_id].to_i
        end
    end

    def tag_vlan
        cmd =  "#{COMMANDS[:ovs_vsctl]} set Port #{@nic[:tap]} "
        cmd << "tag=#{vlan}"

        run cmd
    end

    def tag_trunk_vlans
        range = @nic[:vlan_tagged_id]
        if range? range
            ovs_vsctl_cmd = "#{COMMANDS[:ovs_vsctl]} set Port #{@nic[:tap]}"

            cmd = "#{ovs_vsctl_cmd} trunks=#{range}"
            run cmd

            cmd = "#{ovs_vsctl_cmd} vlan_mode=native-untagged"
            run cmd
        end
    end

    def mac_spoofing
        add_flow("in_port=#{port},arp,dl_src=#{@nic[:mac]}",:drop,45000)
        add_flow("in_port=#{port},arp,dl_src=#{@nic[:mac]},nw_src=#{@nic[:ip]}",:normal,46000)
        add_flow("in_port=#{port},dl_src=#{@nic[:mac]}",:normal,40000)
        add_flow("in_port=#{port}",:drop,39000)
    end

    def configure_fw
        # TCP
        if range = @nic[:black_ports_tcp]
            if range? range
                range.split(",").each do |p|
                    base_rule = "tcp,dl_dst=#{@nic[:mac]},tp_dst=#{p}"
                    base_rule << ",dl_vlan=#{vlan}" if @nic[:vlan] == "YES"

                    add_flow(base_rule,:drop)
                end
            end
        end

        # UDP
        if range = @nic[:black_ports_udp]
            if range? range
                range.split(",").each do |p|
                    base_rule = "udp,dl_dst=#{@nic[:mac]},tp_dst=#{p}"
                    base_rule << ",dl_vlan=#{vlan}" if @nic[:vlan] == "YES"

                    add_flow(base_rule,:drop)
                end
            end
        end

        # ICMP
        if @nic[:icmp]
            if %w(no drop).include? @nic[:icmp].downcase
                base_rule = "icmp,dl_dst=#{@nic[:mac]}"
                base_rule << ",dl_vlan=#{vlan}" if @nic[:vlan] == "YES"

                add_flow(base_rule,:drop)
            end
        end
    end

    def del_flows
        in_port = ""

        dump_flows = "#{COMMANDS[:ovs_ofctl]} dump-flows #{@nic[:bridge]}"
        `#{dump_flows}`.lines do |flow|
            next unless flow.match("#{@nic[:mac]}")
            flow = flow.split.select{|e| e.match(@nic[:mac])}.first
            if in_port.empty? and (m = flow.match(/in_port=(\d+)/))
                in_port = m[1]
            end
            del_flow flow
        end

        del_flow "in_port=#{in_port}" if !in_port.empty?
    end

    def add_flow(filter,action,priority=nil)
        priority = (priority.to_s.empty? ? "" : "priority=#{priority},")

        run "#{COMMANDS[:ovs_ofctl]} add-flow " <<
            "#{@nic[:bridge]} #{filter},#{priority}actions=#{action}"
    end

    def del_flow(filter)
        filter.gsub!(/priority=(\d+)/,"")
        run "#{COMMANDS[:ovs_ofctl]} del-flows " <<
            "#{@nic[:bridge]} #{filter}"
    end

    def run(cmd)
        OpenNebula.exec_and_log(cmd)
    end

    def port
        return @nic[:port] if @nic[:port]

        dump_ports = `#{COMMANDS[:ovs_ofctl]} \
                      dump-ports #{@nic[:bridge]} #{@nic[:tap]}`

        @nic[:port] = dump_ports.scan(/^\s*port\s*(\d+):/).flatten.first
    end

    def range?(range)
        !range.to_s.match(/^\d+(,\d+)*$/).nil?
    end
end
