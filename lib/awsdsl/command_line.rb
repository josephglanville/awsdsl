require 'clamp'
require 'awsdsl'

module AWSDSL
  class CommandLine < Clamp::Command
    option '--stackfile',
      'STACKFILE',
      'Path to Stackfile',
      default: 'Stackfile'

    subcommand 'build', 'Build Stack AMIs' do
      def execute
        stack = Loader.load(stackfile)
        AMIBuilder.build(stack)
      end
    end

    subcommand 'create', 'Create Stack' do
      def execute
        stack = Loader.load(stackfile)
        stack = AMIBuilder.latest_amis(stack)
        template = CfnBuilder.build(stack)
        cfm = AWS::CloudFormation.new
        cfm.stacks.create(stack.name.capitalize, template,
                          capabilities: ['CAPABILITY_IAM'])
      end
    end

    subcommand 'update', 'Update Stack' do
      def execute
        stack = Loader.load(stackfile)
        stack = AMIBuilder.latest_amis(stack)
        template = CfnBuilder.build(stack)
        cfm = AWS::CloudFormation.new
        cfm.stacks[stack.name.capitalize].update(template: template,
                                                 capabilities: ['CAPABILITY_IAM'])
      end
    end

    subcommand 'delete', 'Delete Stack' do
      def execute
        stack = Loader.load(stackfile)
        cfm = AWS::CloudFormation.new
        cfm.stacks[stack.name.capitalize].delete
      end
    end
  end
end
