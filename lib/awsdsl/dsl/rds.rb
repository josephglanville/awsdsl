module AWSDSL
  class Rds
    include DSL
    attributes :vpc,
               :engine,
               :az,
               :multi_az,
               :storage,
               :user,
               :password,
               :node_type
    multi_attributes :allow, :subnet
  end
end
