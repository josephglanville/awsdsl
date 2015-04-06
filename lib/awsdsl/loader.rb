require 'awsdsl/dsl'
require 'awsdsl/dsl/stack'
require 'awsdsl/dsl/role'
require 'awsdsl/dsl/role_profile'
require 'awsdsl/dsl/load_balancer'
require 'awsdsl/dsl/elasticache'
require 'awsdsl/fn'

module AWSDSL
  module Loader
    def self.stack(*a, &block)
      Stack.new(*a, &block)
    end

    def self.load(fname)
      stack = binding.eval(File.read(fname), fname)
      # TODO(jpg): Add default profiles to stack
      stack.mixin_profiles
      stack
    end
  end
end
