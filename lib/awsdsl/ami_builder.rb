require 'gersberms'
require 'awsdsl/base_ami'

module AWSDSL
  class AMIBuilder
    def initialize(stack)
      @stack = stack
    end

    def build
      @stack.roles.each do |role|
        build_ami(role)
      end
    end

    def self.build(stack)
      AMIBuilder.new(stack).build
    end

    def build_ami(role)
      output_ami = ami_name(role)
      @builder = Gersberms::Gersberms.new base_ami: base_ami(role),
                                          ami_name: output_ami
      begin
        start_builder
        role.file_provisioners.each do |provisioner|
          @builder.options[:files] = provisioner
          @builder.upload_files
        end
        role.chef_provisioners.each do |provisioner|
          runlist = provisioner[:runlist]
          runlist = [runlist] unless runlist.is_a? Array
          @builder.options[:runlist] = provisioner[:runlist]
          @builder.run_chef
        end
        shutdown_builder
        role.ami = @builder.image.id
      rescue => e
        @builder.destroy_instance
        @builder.destroy_keypair
        fail "Failed to build AMI for #{role.name}:\nError: #{e.message}\nBacktrace: #{e.backtrace.join("\n")}"
      end
    end

    def start_builder
      @builder.preflight
      @builder.create_keypair
      @builder.create_instance
      @builder.install_chef
    end

    def shutdown_builder
      @builder.stop_instance
      @builder.create_ami
      @builder.destroy_instance
      @builder.destroy_keypair
    end

    def base_ami(role)
      base = role.base_ami || @stack.base_ami || 'ubuntu'
      if BaseAMI::DISTROS.include?(base)
        base = BaseAMI.find(base)
      end
      base
    end

    def ami_name(role)
      last = latest_ami(role)
      num = last.name.split('-').last.to_i + 1 if last
      num ||= 1
      "#{@stack.name}-#{role.name}-#{num}"
    end

    def latest_ami(role)
      ec2 = AWS::EC2.new
      amis = ec2.images.with_owner('self').select do |i|
        i.name.start_with?("#{@stack.name}-#{role.name}")
      end
      latest_num = amis.map {|i| i.name.split('-').last.to_i }.sort.last
       amis.select {|i| i.name == "#{ami}-#{env}-#{latest_num}"}.first
    end
  end
end
