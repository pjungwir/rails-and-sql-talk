ENV['RAILS_ENV'] ||= 'test'

require File.expand_path("../../config/environment", __FILE__)
require 'rspec/rails'
Dir[File.expand_path("../support/**/*.rb", __FILE__)].each {|f| require f}

RSpec.configure do |config|
  config.order = 'random'
  config.fixture_path = "#{::Rails.root}/spec/fixtures"
  config.use_transactional_fixtures = true
  # config.infer_spec_type_from_file_location!
end
