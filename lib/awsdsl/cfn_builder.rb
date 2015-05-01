require 'cfndsl'
require 'netaddr'
require 'awsdsl/cfn_helpers'

module AWSDSL
  class CfnBuilder
    include CfnHelpers

    def initialize(stack)
      @stack = stack
    end

    def self.build(stack)
      CfnBuilder.new(stack).build
    end

    def build
      @t = CfnDsl::CloudFormationTemplate.new
      stack = @stack
      @t.declare do
        Description stack.description
      end
      AWS.memoize do
        build_vpcs
        build_elasticaches
        build_buckets
        build_roles
      end
      @t
    end

    def build_roles
      stack = @stack
      stack.roles.each do |role|
        role_name = role.name.capitalize
        role_vpc = resolve_vpc(role.vpc)

        # Create ELBs and appropriate security groups etc.
        role.load_balancers.each do |lb|
          listeners = lb.listeners.map { |l| format_listener(l) }
          health_check = health_check_defaults(lb.health_check) if lb.health_check

          lb_name = "#{role_name}#{lb.name.capitalize}ELB"
          subnets = lb.subnets.empty? ? role.subnets : lb.subnets
          lb_subnets = resolve_subnets(role.vpc, subnets)

          # ELB
          @t.declare do
            LoadBalancer lb_name do
              Listeners listeners
              ConnectionSettings lb.connection_settings if lb.connection_settings
              HealthCheck health_check if health_check
              CrossZone true
              Subnets lb_subnets
              SecurityGroups [Ref("#{lb_name}SG")]
            end
          end

          # ELB SG
          @t.declare do
            EC2_SecurityGroup "#{lb_name}SG" do
              GroupDescription "#{lb.name.capitalize} ELB Security Group"
              VpcId role_vpc
              listeners.map { |l| l[:LoadBalancerPort] }.each do |port|
                SecurityGroupIngress IpProtocol: 'tcp',
                                     FromPort: port,
                                     ToPort: port,
                                     CidrIp: '0.0.0.0/0'
              end
              lb.allows.each do |rule|
                ports = rule[:ports].is_a?(Array) ? rule[:ports] : [rule[:ports]]
                ports.each do |port|
                  SecurityGroupIngress IpProtocol: rule[:proto] || 'tcp',
                                       FromPort: port,
                                       ToPort: port,
                                       SourceSecurityGroupId: Ref("#{rule[:role].capitalize}SG")
                end
              end
            end
          end

          # ELB DNS records
          lb.dns_records.each do |record|
            zone = record[:zone] || get_zone_for_record(record[:name]).id
            record_name = record[:name].split('.').map(&:capitalize).join
            @t.declare do
              RecordSet record_name do
                HostedZoneId zone
                Name record
                Type 'A'
                AliasTarget HostedZoneId: FnGetAtt(lb_name, 'CanonicalHostedZoneNameID'),
                            DNSName: FnGetAtt(lb_name, 'CanonicalHostedZoneName')
              end
            end
          end
        end # end load_balancers

        # IAM Role
        @t.declare do
          IAM_Role "#{role_name}Role" do
            AssumeRolePolicyDocument Statement: [{
              Effect: 'Allow',
              Principal: {
                Service: ['ec2.amazonaws.com']
              },
              Action: ['sts:AssumeRole']
            }]
            Path '/'
          end
        end

        # Policy
        statements = role.policy_statements.map { |s| format_policy_statement(s) }
        if statements.count > 1
          policy_name = "#{role_name}Policy"
          @t.declare do
            Policy policy_name do
              PolicyName policy_name
              PolicyDocument Statement: statements
              Roles [Ref("#{role_name}Role")]
            end
          end
        end

        # Instance Profile
        @t.declare do
          InstanceProfile "#{role_name}InstanceProfile" do
            Path '/'
            Roles [Ref("#{role_name}Role")]
          end
        end

        # Autoscaling Group
        update_policy = update_policy_defaults(role)
        lb_names = role.load_balancers.map { |lb| "#{role_name}#{lb.name.capitalize}ELB" }
        subnets = resolve_subnets(role.vpc, role.subnets)
        min = role.min_size || 0
        max = role.max_size || 1
        tgt = role.tgt_size || 1
        @t.declare do
          AutoScalingGroup "#{role_name}ASG" do
            LaunchConfigurationName Ref("#{role.name.capitalize}LaunchConfig")
            UpdatePolicy 'AutoScalingRollingUpdate', update_policy if update_policy
            MinSize min
            MaxSize max
            DesiredCapacity tgt
            LoadBalancerNames lb_names.map { |name| Ref(name) }
            VPCZoneIdentifier subnets
            AvailabiltityZones FnGetAZs('')
          end
        end

        # Launch Configuration
        security_groups = resolve_security_groups(role.vpc, role.security_groups)
        block_devices = format_block_devices(role.block_devices)
        vars = (stack.vars || {}).merge(role.vars || {})
        @t.declare do
          LaunchConfiguration "#{role_name}LaunchConfig" do
            ImageId role.ami
            # TODO(jpg): Should support NAT at some stage even though it's nasty on AWS
            AssociatePublicIpAddress true
            InstanceType role.instance_type
            # TODO(jpg): Need to resolve this to IDs or Refs as necessary
            SecurityGroups [Ref("#{role_name}SG")] + security_groups
            IamInstanceProfile Ref("#{role_name}InstanceProfile")
            BlockDeviceMappings block_devices
            KeyName role.key_pair if role.key_pair
            vars.each do |k,v|
              Metadata k.to_s, v
            end
          end
        end

        lb_ingress_rules = role.load_balancers.map do |lb|
          lb.listeners.map do |l|
            h = listener_defaults(l)
            h[:sg] = "#{role_name}#{lb.name.capitalize}ELBSG"
            h
          end
        end.flatten
        # Security Group
        @t.declare do
          EC2_SecurityGroup "#{role_name}SG" do
            GroupDescription "#{role_name} Security Group"
            VpcId role_vpc
            # TODO(jpg): Better way of offering up defaults
            SecurityGroupIngress IpProtocol: 'tcp',
                                 FromPort: 22,
                                 ToPort: 22,
                                 CidrIp: '0.0.0.0/0'

            # Access from configured load_balancers
            lb_ingress_rules.each do |rule|
              SecurityGroupIngress IpProtocol: 'tcp',
                                   FromPort: rule[:instance_port],
                                   ToPort: rule[:instance_port],
                                   SourceSecurityGroupId: Ref(rule[:sg])
            end

            # Access from other roles
            # TODO(jpg): catch undefined roles before template generation
            role.allows.select { |r| r[:role] != role.name }.each do |rule|
              ports = rule[:ports].is_a?(Array) ? rule[:ports] : [rule[:ports]]
              ports.each do |port|
                SecurityGroupIngress IpProtocol: rule[:proto] || 'tcp',
                                     FromPort: port,
                                     ToPort: port,
                                     SourceSecurityGroupId: Ref("#{rule[:role].capitalize}SG")
              end
            end
          end

          # Intracluster communication
          role.allows.select { |r| r[:role] == role.name }.each do |rule|
            ports = rule[:ports].is_a?(Array) ? rule[:ports] : [rule[:ports]]
            proto = rule[:proto] || 'tcp'
            ports.each do |port|
              EC2_SecurityGroupIngress "#{role_name}SG#{proto.upcase}#{port}" do
                GroupId Ref("#{role_name}SG")
                IpProtocol proto
                FromPort port
                ToPort port
                SourceSecurityGroupId Ref("#{role_name}SG")
              end
            end
          end
        end
      end
    end

    def build_elasticaches
      default_ports = {
        'redis' => 6379,
        'memcached' => 11211
      }
      stack = @stack
      stack.elasticaches.each do |cache|
        # Default to Redis, also set default port if unset.
        engine ||= 'redis'
        port ||= default_ports[engine]
        num_nodes ||= 1
        cache_vpc = resolve_vpc(cache.vpc)
        cache_name = "#{cache.name.capitalize}Cache"

        # SG
        @t.declare do
          EC2_SecurityGroup "#{cache_name}SG" do
            GroupDescription "#{cache.name.capitalize} Cache Security Group"
            VpcId cache_vpc
            cache.allows.each do |rule|
              SecurityGroupIngress IpProtocol: 'tcp',
                                   FromPort: port,
                                   ToPort: port,
                                   SourceSecurityGroupId: Ref("#{rule[:role].capitalize}SG")
            end
          end
        end

        # ElastiCacheSubnetGroup
        cache_subnets = resolve_subnets(cache.vpc, cache.subnets)
        @t.declare do
          ElastiCache_SubnetGroup "#{cache_name}SubnetGroup" do
            Description "SubnetGroup for #{cache_name}"
            SubnetIds cache_subnets
          end
        end

        # CacheCluster
        @t.declare do
          CacheCluster cache_name do
            CacheNodeType cache.node_type
            NumCacheNodes num_nodes
            Engine engine
            Port port
            CacheSubnetGroupName Ref("#{cache_name}SubnetGroup")
            VpcSecurityGroupIds [FnGetAtt("#{cache_name}SG", 'GroupId')]
          end
        end

        # Add additional policy to each Role that can access this Cache
        # This will allow said Role to discover the Cache nodes
        cache.allows.each do |rule|
          role = stack.roles.find { |r| r.name = rule[:role] }
          role.policy_statement effect: 'Allow',
                                action: 'elasticache:Describe*',
                                resource: '*'
        end
      end
    end

    def build_vpcs
      stack = @stack
      stack.vpcs.each do |vpc|
        igw = vpc.igw || true
        dns = vpc.dns || true
        cidr = vpc.cidr || '10.0.0.0/16'
        subnet_bits = vpc.subnet_bits || 24
        dns_hostnames = vpc.dns_hostnames || true

        cidr = NetAddr::CIDR.create(cidr)
        subnets = cidr.subnet(Bits: subnet_bits).to_enum

        # VPC
        vpc_name = "#{vpc.name.capitalize}VPC"
        @t.declare do
          VPC vpc_name do
            CidrBlock cidr
            EnableDnsSupport dns
            EnableDnsHostnames dns_hostnames
          end
        end

        if igw # Don't create internet facing stuff if igw is not enabled
          igw_name = "#{vpc.name.capitalize}IGW"

          # IGW
          @t.declare do
            InternetGateway igw_name
          end

          # Attach to VPC
          @t.declare do
            VPCGatewayAttachment "#{vpc.name.capitalize}GWAttachment" do
              VpcId Ref(vpc_name)
              InternetGatewayId Ref(igw_name)
            end
          end

          # RouteTable
          rt_name = "#{vpc.name.capitalize}RouteTable"
          @t.declare do
            RouteTable rt_name do
              VpcId Ref(vpc_name)
            end
          end

          # Default route for RouteTable
          @t.declare do
            Route "#{vpc.name.capitalize}DefaultRoute" do
              RouteTableId Ref(rt_name)
              DestinationCidrBlock '0.0.0.0/0'
              GatewayId Ref(igw_name)
              # TODO(jpg): DependsOn rt_name
            end
          end
        end

        vpc.subnets.each do |subnet|
          subnet_igw = subnet.igw || igw
          azs = subnet.azs || fetch_availability_zones(vpc.region)
          subnet_name = "#{vpc.name.capitalize}#{subnet.name.capitalize}Subnet"
          azs.each do |az|
            subnet_name_az = "#{subnet_name}#{az.capitalize}"
            @t.declare do
              Subnet subnet_name_az do
                AvailabilityZone "#{vpc.region}#{az}"
                CidrBlock subnets.next
                VpcId Ref(vpc_name)
              end

              if subnet_igw
                SubnetRouteTableAssociation "#{subnet_name_az}DefaultRTAssoc" do
                  SubnetId Ref(subnet_name_az)
                  RouteTableId Ref(rt_name)
                  # TODO(jpg): DependsOn rt_name
                end
              end
            end
          end
        end
      end
    end

    def build_buckets
      stack = @stack
      stack.buckets.each do |bucket|
        @t.declare do
          Bucket "#{bucket.name.capitalize}Bucket" do
            BucketName bucket.bucket_name if bucket.bucket_name
            AccessControl bucket.access_control if bucket.access_control
          end
        end
      end
    end
  end
end
