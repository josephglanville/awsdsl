module AWSDSL
  class Role
    include DSL
    attr_accessor :ami

    sub_components :load_balancer
    multi_attributes :policy_statement,
                     :include_profile,
                     :security_group,
                     :chef_provisioner,
                     :ansible_provisioner,
                     :subnet
    attributes :min_size,
               :max_size,
               :tgt_size,
               :update_policy,
               :instance_type,
               :vpc,
               :base_ami
  end
end
