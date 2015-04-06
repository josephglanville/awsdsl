require 'cfndsl'
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
      AWS.memoize do
        t = CfnDsl::CloudFormationTemplate.new
        stack = @stack
        t.declare do
          Description stack.description
        end
        stack.roles.each do |role|
          role_name = role.name.capitalize
          role_vpc = role.vpc

          # Create ELBs and appropriate security groups etc.
          role.load_balancers.each do |lb|
            listeners = lb.listeners.map { |l| listener_defaults(l) }
            health_check = health_check_defaults(lb.health_check) if lb.health_check

            # ELB
            lb_name = "#{lb.name.capitalize}ELB"
            lb_subnets = resolve_subnets(role_vpc, lb.subnets || role.subnets)
            t.declare do
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
            lb_vpc = resolve_vpc(role.vpc)
            t.declare do
              EC2_SecurityGroup "#{lb_name}SG" do
                GroupDescription "#{lb.name.capitalize} ELB Security Group"
                VpcId lb_vpc
                listeners.map { |l| l[:LoadBalancerPort] }.each do |port|
                  SecurityGroupIngress IpProtocol: 'tcp',
                                       FromPort: port,
                                       ToPort: port,
                                       CidrIp: '0.0.0.0/0'
                end
              end
            end

            # ELB DNS records
            lb.dns_records.each do |record|
              zone = record[:zone] || get_zone_for_record(record[:name]).id
              t.declare do
                RecordSet record[:name] do
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
          t.declare do
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
          policy_name = "#{role_name}Policy"
          t.declare do
            Policy policy_name do
              PolicyName policy_name
              PolicyDocument Statement: statements
              Roles [Ref("#{role_name}Role")]
            end
          end

          # Instance Profile
          t.declare do
            InstanceProfile "#{role_name}InstanceProfile" do
              Path '/'
              Roles [Ref("#{role_name}Role")]
            end
          end

          # Autoscaling Group
          update_policy = update_policy_defaults(role)
          lb_names = role.load_balancers.map(&:name)
          subnets = resolve_subnets(role_vpc, role.subnets)
          t.declare do
            AutoScalingGroup "#{role_name}ASG" do
              LaunchConfigurationName Ref("#{role.name}LaunchConfig")
              UpdatePolicy 'AutoScalingRollingUpdate', update_policy if update_policy
              MinSize role.min_size
              MaxSize role.max_size
              DesiredCapacity role.tgt_size
              LoadBalancerNames lb_names.map { |name| Ref(name) }
              VPCZoneIdentifier subnets
              AvailabiltityZones FnGetAZs('')
            end
          end

          # Launch Configuration
          security_groups = resolve_security_groups(role_vpc, role.security_groups)
          t.declare do
            LaunchConfiguration "#{role_name}LaunchConfig" do
              ImageId role.ami
              # TODO(jpg): Should support NAT at some stage even though it's nasty on AWS
              AssociatePublicIpAddress true
              InstanceType role.instance_type
              # TODO(jpg): Need to resolve this to IDs or Refs as necessary
              SecurityGroups [Ref("#{role_name}SG")] + security_groups
              IamInstanceProfile Ref("#{role_name}InstanceProfile")
            end
          end

          # Security Group
          t.declare do
            EC2_SecurityGroup "#{role_name}SG" do
              GroupDescription "#{role_name} Security Group"
              VpcId role_vpc
              # TODO(jpg): Better way of offering up defaults
              SecurityGroupIngress IpProtocol: 'tcp',
                                   FromPort: 22,
                                   ToPort: 22,
                                   CidrIp: '0.0.0.0/0'
              # Access from other roles
              # TODO(jpg): catch undefined roles before template generation
              role.allows.select {|r| r[:role] != role.name }.each do |rule|
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
            role.allows.select {|r| r[:role] == role.name }.each do |rule|
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
        t
        # TODO(jpg): Think about how to handle non-role stuff and how
        # that will interact with roles. Also maybe consider inter-role
        # dependency issues.
      end
    end
  end
end
