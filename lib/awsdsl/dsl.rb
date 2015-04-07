require 'awsdsl/ext/proc'
require 'awsdsl/ext/symbol'
require 'active_support/core_ext/object/blank'
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
          define_method(attr.plural_fn) do |*_args, &_b|
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
          define_method(attr.plural_fn) do |*_args, &_b|
            instance_variable_get(attr.plural_ivar) || []
          end
        end
      end

      instance_eval(&block) if block_given?
    end

    def to_h
      h = {}
      (self.class.attributes + [:name]).each { |attr| h.store(attr, send(attr)) }
      self.class.multi_attributes.each { |attr| h.store(attr.plural_fn, send(attr.plural_fn)) }
      self.class.sub_components.each do |attr|
        comp = send(attr.plural_fn).map(&:to_h)
        h.store(attr.plural_fn, comp)
      end
      h.delete_if { |_k, v| v.blank? }
      h
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
