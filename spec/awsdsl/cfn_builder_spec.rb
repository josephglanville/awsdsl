require 'English'
require 'awsdsl'
require 'pry'

module AWSDSL
  describe CfnBuilder do
    describe :build do
      it 'should build the test stack' do
        stack = Loader.load(fixture_path('test_stack.rb'))
        CfnBuilder.new(stack).build
      end

      it 'should generate valid cloudformation', type: :integration do
        stack = Loader.load(fixture_path('test_stack.rb'))
        stack.roles.each do |role|
          role.ami = 'ami-id'
        end
        json = CfnBuilder.new(stack).build.to_json
        temp = Tempfile.new('awsdsl_cfn_json')
        temp.write(json)
        `aws cloudformation validate-template --template-body file://#{temp.path}`
        temp.close
        temp.unlink
        expect($CHILD_STATUS.exitstatus).to eq(0)
      end
    end
  end
end
