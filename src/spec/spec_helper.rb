ENV['RAILS_ENV'] ||= 'test'

Dir[File.expand_path("../support/**/*.rb", __FILE__)].each {|f| require f}
require File.expand_path("../../config/environment", __FILE__)

RSpec.configure do |config|
  # config.infer_spec_type_from_file_location!
end
