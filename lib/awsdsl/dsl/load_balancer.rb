module AWSDSL
  class LoadBalancer
    include DSL
    multi_attributes :listener, :dns_record, :security_group, :subnet, :allow
    attributes :health_check, :internal, :connection_settings
  end
end
