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
      t = CfnDsl::CloudFormationTemplate.new
      stack = @stack
      t.declare do
        Description stack.description
      end
      stack.roles.each do |role|
        role_name = role.name.capitalize

        # Create ELBs and appropriate security groups etc.
        role.load_balancers.each do |lb|
          listeners = lb.listeners.map { |l| listener_defaults(l) }
          health_check = health_check_defaults(lb.health_check) if lb.health_check

          # ELB
          lb_name = "#{lb.name.capitalize}ELB"
          t.declare do
            LoadBalancer lb_name do
              Listeners listeners
              ConnectionSettings lb.connection_settings if lb.connection_settings
              HealthCheck health_check if health_check
              CrossZone true
              Subnets resolve_subnets(lb.subnets || role.subnets)
              SecurityGroups [Ref("#{lb_name}ELBSG")]
            end
          end

          # ELB SG
          t.declare do
            EC2_SecurityGroup "#{lb_name}ELBSG" do
              GroupDescription "#{lb.name.capitalize} ELB Security Group"
              VpcId resolve_vpc(role.vpc)
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
            t.declare do
              RecordSet record[:name] do
                HostedZoneId record[:zone] || get_zone_for_record(record[:name]).id
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
        t.declare do
          AutoScalingGroup "#{role_name}ASG" do
            LaunchConfigurationName Ref("#{role.name}LaunchConfig")
            UpdatePolicy 'AutoScalingRollingUpdate', update_policy if update_policy
            MinSize role.min_size
            MaxSize role.max_size
            DesiredCapacity role.tgt_size
            LoadBalancerNames lb_names.map { |name| Ref(name) }
            VPCZoneIdentifier resolve_subnets(role.vpc, role.subnets)
            AvailabiltityZones FnGetAZs('')
          end
        end

        # Launch Configuration
        t.declare do
          LaunchConfiguration "#{role_name}LaunchConfig" do
            ImageId role.ami
            # TODO(jpg): Should support NAT at some stage even though it's nasty on AWS
            AssociatePublicIpAddress true
            InstanceType role.instance_type
            # TODO(jpg): Need to resolve this to IDs or Refs as necessary
            SecurityGroups [Ref("#{role_name}SG")] + role.security_groups
            IamInstanceProfile Ref("#{role_name}InstanceProfile")
          end
        end

        # Security Group
        t.declare do
          EC2_SecurityGroup "#{role_name}SG" do
            GroupDescription "#{role_name} Security Group"
            VpcId role.vpc
            # TODO(jpg): Better way of offering up defaults
            SecurityGroupIngress IpProtocol: 'tcp',
                                 FromPort: 22,
                                 ToPort: 22,
                                 CidrIp: '0.0.0.0/0'
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
