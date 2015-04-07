module AWSDSL
  class Vpc
    include DSL
    sub_components :subnet
    attributes :cidr, :dns, :dns_hostnames, :igw, :region, :subnet_bits
  end
end
