require_relative 'boot'

require 'rails/all'

Bundler.require(*Rails.groups)
require 'scim_rails'

module Dummy
  class Application < Rails::Application
  end
end
