module AWSDSL
  module Fn
    def stack(*a, &block)
      Stack.new(*a, &block)
    end

    def security_group_by_name(name)
      name
    end
  end
end
