module AWSDSL
  class Subnet
    include DSL
    attributes :igw, :tags
    multi_attributes :az
  end
end
