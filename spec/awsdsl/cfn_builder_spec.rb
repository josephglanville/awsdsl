require 'awsdsl'
require 'pry'

module AWSDSL
  describe CfnBuilder do
    describe :build do
      it 'should build the test stack' do
        stack = Loader.load(fixture_path('test_stack.rb'))
        CfnBuilder.new(stack).build
      end
    end
  end
end
