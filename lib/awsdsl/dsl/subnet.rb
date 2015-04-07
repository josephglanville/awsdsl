module AWSDSL
  class Subnet
    include DSL
    attributes :igw
    multi_attributes :az
  end
end
