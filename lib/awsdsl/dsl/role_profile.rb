module AWSDSL
  class RoleProfile
    include DSL
    attr_accessor :block

    def initialize(name, &block)
      @name = name
      @block = block if block_given?
    end
  end
end
