require 'awsdsl'
require 'pry'

module AWSDSL
  describe Loader do
    describe :load do
      it 'should load the test data' do
        Loader.load(fixture_path('test_stack.rb'))
      end
    end
  end
end
