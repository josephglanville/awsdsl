require 'awsdsl/ext/proc'
require 'awsdsl/ext/symbol'
require 'awsdsl/fn'

module AWSDSL
  module DSL
    include Fn
    attr_accessor :name

    def self.included(base)
      base.extend(ClassMethods)
    end

    def initialize(name, &block)
      @name = name
      self.class.class_eval do
        attributes.each do |attr|
          define_method(attr) do |*args|
            if args.length > 0
              args = args.length > 1 ? args : args.first
              instance_variable_set(attr.ivar, args)
            else
              instance_variable_get(attr.ivar)
            end
          end
        end

        multi_attributes.each do |attr|
          define_method(attr) do |*args|
            cur = instance_variable_get(attr.plural_ivar) || []
            instance_variable_set(attr.plural_ivar, cur + args)
          end
          define_method(attr.plural_fn) do |*args, &b|
            instance_variable_get(attr.plural_ivar) || []
          end
        end

        sub_components.each do |attr|
          define_method(attr) do |*args, &b|
            cur = instance_variable_get(attr.plural_ivar) || []
            klass_name = attr.to_s.split('_').collect!(&:capitalize).join
            klass = Object.const_get("AWSDSL::#{klass_name}")
            instance_variable_set(attr.plural_ivar, cur + [klass.new(args.first, &b)])
          end
          define_method(attr.plural_fn) do |*args, &b|
            instance_variable_get(attr.plural_ivar) || []
          end
        end
      end

      instance_eval(&block) if block_given?
    end

    module ClassMethods
      [:sub_components, :attributes, :multi_attributes].each do |method|
        define_method(method) do |*args|
          if args.length > 0
            instance_variable_set(method.ivar, args)
          else
            instance_variable_get(method.ivar) || []
          end
        end
      end
    end
  end
end
