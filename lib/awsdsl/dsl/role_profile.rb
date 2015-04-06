module AWSDSL
  class RoleProfile < Role
    include DSL
    attr_accessor :block

    sub_components :load_balancer
    multi_attributes :policy_statement,
                     :include_profile,
                     :security_group,
                     :file_provisioner,
                     :chef_provisioner,
                     :ansible_provisioner,
                     :subnet,
                     :allow
    attributes :min_size,
               :max_size,
               :tgt_size,
               :update_policy,
               :instance_type,
               :vpc,
               :base_ami

    def initialize(name, &block)
      @block = block if block_given?
      super
    end
  end
end
