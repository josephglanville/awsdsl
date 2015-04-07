require 'pry'
require 'awsdsl'
require 'awsdsl/cfn_helpers'

ROOT = File.join(File.dirname(__FILE__), '..')
FIXTURES = File.join(File.dirname(__FILE__), 'fixtures')

def fixture_path(*path)
  File.join(FIXTURES, path)
end

def fixture(*path)
  File.open(fixture_path(path)) { |f| f.read }
end

def json_fixture(*path)
  last = path.pop
  JSON.parse(fixture(path << last + '.json'))
end

def yaml_fixture(*path)
  last = path.pop
  YAML.parse(fixture(path << last + '.yml'))
end

AWS.stub!

RSpec.configure do |config|
  config.filter_run_excluding type: 'integration' unless ENV['INTEGRATION']
end
