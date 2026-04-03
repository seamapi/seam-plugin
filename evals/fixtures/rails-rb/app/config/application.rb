require "rails"
require "action_controller/railtie"

module PmsApp
  class Application < Rails::Application
    config.load_defaults 7.1
    config.api_only = true
    config.eager_load = false
    config.secret_key_base = ENV.fetch("SECRET_KEY_BASE") { SecureRandom.hex(64) }
  end
end

require_relative "../app/models/store"
require_relative "../app/services/reservation_service"
require_relative "routes"
