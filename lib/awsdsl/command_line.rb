require 'clamp'
require 'awsdsl'

module AWSDSL
  class CommandLine < Clamp::Command
    option ['-s', '--stackfile'],
      'STACKFILE',
      'Path to Stackfile',
      default: 'Stackfile'
    option ['-b', '--build'], :flag, 'Build AMIs'

    def execute
      stack = Loader.load(stackfile)
      if build_amis
        AMIBuilder.build(stack)
      else
        # Get the latest AMIs
      end
      template = CfnBuilder.build(stack)
      cfm = AWS::CloudFormation.new
      # Check state of stack, create or update as necessary
    end
  end
end
