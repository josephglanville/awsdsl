module AWSDSL
  class Role
    include DSL
    attr_accessor :ami

    sub_components :load_balancer
    multi_attributes :policy_statement,
                     :include_profile,
                     :security_group,
                     :block_device,
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
               :base_ami,
               :vars,
               :key_pair,
               :tags,
               :init
  end
end
