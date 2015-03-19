module AWSDSL
  class Role
    include DSL
    sub_components :load_balancer
    multi_attributes :policy_statement,
                     :include_profile,
                     :security_group,
                     :chef_provisioner,
                     :ansible_provisioner
    attributes :min_size,
               :max_size,
               :tgt_size,
               :update_policy,
               :instance_type,
               :vpc,
               :subnets,
               :ami
  end
end
