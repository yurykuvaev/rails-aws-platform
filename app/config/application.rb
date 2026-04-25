require_relative "boot"

require "rails"
require "active_model/railtie"
require "active_record/railtie"
require "action_controller/railtie"
require "action_view/railtie"
require "rails/test_unit/railtie"

Bundler.require(*Rails.groups)

module PokemonBattle
  class Application < Rails::Application
    config.load_defaults 7.1

    config.api_only = true

    # Eager-load app/services and any future top-level lib dir
    config.autoload_lib(ignore: %w[assets tasks]) if config.respond_to?(:autoload_lib)

    config.time_zone = "UTC"
  end
end
