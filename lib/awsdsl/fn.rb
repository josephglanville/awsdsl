module AWSDSL
  module Fn
    def stack(*a, &block)
      Stack.new(*a, &block)
    end
  end
end
