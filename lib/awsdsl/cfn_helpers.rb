require 'aws'
require 'cfndsl'

module AWSDSL
  module CfnHelpers
    include CfnDsl::Functions

    def listener_defaults(listener)
      listener[:proto] ||= 'HTTP'
      listener[:instance_port] ||= listener[:port]
      listener[:loadbalancer_port] ||= listener[:port]
      listener
    end

    def format_listener(listener)
      listener = listener_defaults(listener)
      hash = {
        LoadBalancerPort: listener[:loadbalancer_port],
        InstancePort: listener[:instance_port],
        Protocol: listener[:proto]
      }
      hash[:SSLCertificateId] = listener[:cert] if listener[:cert]
      hash
    end

    def health_check_defaults(health_check)
      hash = {
        Target: health_check[:target]
      }
      hash[:HealthyThreshold] = health_check[:healthy_threshold] || 3
      hash[:UnhealthyThreshold] = health_check[:unhealthy_threshold] || 5
      hash[:Interval] = health_check[:interval] || 90
      hash[:Timeout] = health_check[:timeout] || 60
      hash
    end

    def update_policy_defaults(role)
      update_policy = role.update_policy || {}
      return nil if update_policy[:disable] == true
      hash = {}
      hash[:MaxBatchSize] = update_policy[:max_batch] || 1
      hash[:MinInstancesInService] = update_policy[:min_inservice] || role.min_size
      hash[:PauseTime] = update_policy[:pause_time] if update_policy[:pause_time]
      hash
    end

    def format_policy_statement(policy_statement)
      Hash[policy_statement.map { |k, v| [k.to_s.capitalize.to_sym, v] }]
    end

    def format_block_devices(devices)
      devices.map do |dev|
        h = { DeviceName: dev[:name] }
        if dev[:ephemeral]
          h[:VirtualName] = "ephemeral#{dev[:ephemeral]}"
        else
          h[:Ebs] = {
            VolumeSize: dev[:size],
            VolumeType: dev[:type] || 'gp2'
          }
        end
        h
      end
    end

    def get_zone_for_record(name)
      r53 = AWS::Route53.new
      zones = r53.hosted_zones.sort_by { |z| z.name.split('.').count }.reverse
      zones.find do |z|
        name.split('.').reverse.take(z.name.split('.').count) == z.name.split('.').reverse
      end
    end

    def get_vpc_by_name(vpc)
      ec2 = AWS::EC2.new
      ec2.vpcs.with_tag('Name', vpc).first
    end

    def resolve_vpc(vpc)
      return vpc if vpc.start_with?('vpc-')
      return Ref("#{vpc.capitalize}VPC") if vpc_defined?(vpc)
      get_vpc_by_name(vpc).id
    end

    def resolve_subnets(vpc, subnets)
      subnets.map do |subnet|
        resolve_subnet(vpc, subnet)
      end.flatten(1)
    end

    def subnet_refs(vpc, subnet)
      vpc = @stack.vpcs.find {|v| v.name == vpc }
      subnet = vpc.subnets.find {|s| s.name == subnet}
      subnet_name = "#{vpc.name.capitalize}#{subnet.name.capitalize}Subnet"
      azs = subnet.azs || fetch_availability_zones(vpc.region)
      azs.map do |az|
        Ref("#{subnet_name}#{az.capitalize}")
      end
    end

    def subnet_defined?(vpc, subnet)
      @stack.vpcs.find {|v| v.name == vpc }.subnets.map(&:name).include?(subnet)
    end

    def vpc_defined?(vpc)
      @stack.vpcs.map(&:name).include?(vpc)
    end

    def resolve_subnet(vpc, subnet)
      return [subnet] if subnet.start_with?('subnet-')
      return subnet_refs(vpc, subnet) if subnet_defined?(vpc, subnet)
      ec2 = AWS::EC2.new
      v = ec2.vpcs[vpc] if vpc.start_with?('vpc-')
      v ||= get_vpc_by_name(vpc)
      v.subnets.with_tag('Name', subnet).map(&:id)
    end

    def resolve_security_groups(vpc, security_groups)
      security_groups.map do |sg|
        resolve_security_group(vpc, sg)
      end.flatten
    end

    def resolve_security_group(vpc, sg)
      return [sg] if sg.start_with?('sg-')
      ec2 = AWS::EC2.new
      v = ec2.vpcs[vpc] if vpc.start_with?('vpc-')
      v ||= get_vpc_by_name(vpc)
      v.security_groups.with_tag('Name', sg).map(&:id)
    end
  end
end
