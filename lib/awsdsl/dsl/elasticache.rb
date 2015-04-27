module AWSDSL
  class Elasticache
    include DSL
    multi_attributes :allow, :subnet
    attributes :engine, :node_type, :port, :num_nodes, :vpc, :tags
  end
end
