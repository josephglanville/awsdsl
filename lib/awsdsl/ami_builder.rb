require 'gersberms'

module AWSDSL
  class AMIBuilder
    def initialize(stack)
      @stack = stack
    end

    def build
      @stack.each.map do |role|
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
          @builder.options[:runlist] = provisioner[:runlist]
          @builder.run_chef
        end
        shutdown_builder
        role.ami = @builder.image.id
      rescue => e
        @builder.destroy_instance
        @builder.destroy_keypair
        fail "Failed to build AMI for #{role.name}:\nError: #{e.message}\nBacktrace: #{e.backtrace}"
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
  end
end
