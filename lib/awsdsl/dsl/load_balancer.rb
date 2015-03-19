module AWSDSL
  class LoadBalancer
    include DSL
    multi_attributes :listener, :dns_record, :security_group
    attributes :health_check, :internal, :connection_settings, :subnets
  end
end
