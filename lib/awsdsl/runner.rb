module AWSDSL
  class Runner
    def initialize(stackfile: 'Stackfile')
      @stack = Loader.load(stackfile)
      @cfn = AWS::CloudFormation.new
    end

    def build_amis
      AMIBuilder.build(@stack)
    end

    def create
      build_amis
      t = CfnBuilder.build(@stack)
      @cfn.stacks.create(@stack.name, t, capabilities: ['CAPABILITY_IAM'])
    end

    def update
      build_amis
      t = CfnBuilder.build(stack)
      @cfn.stacks[@stack.name].update(template: t, capabiltiies: ['CAPABILITY_IAM'])
    end

    def delete
      @cfn.stacks[@stack.name].delete
    end
  end
end
