require_relative "boot"

require "rails"
# Pick the frameworks you want:
require "active_model/railtie"
# require "active_job/railtie"
# require "active_record/railtie"
# require "active_storage/engine"
require "action_controller/railtie"
# require "action_mailer/railtie"
# require "action_mailbox/engine"
# require "action_text/engine"
require "action_view/railtie"
# require "action_cable/engine"
require "rails/test_unit/railtie"

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

module Rantly
  class Application < Rails::Application
    # Initialize configuration defaults for originally generated Rails version.
    config.load_defaults 8.1

    # Please, add to the `ignore` list any other `lib` subdirectories that do
    # not contain `.rb` files, or that should not be reloaded or eager loaded.
    # Common ones are `templates`, `generators`, or `middleware`, for example.
    config.autoload_lib(ignore: %w[assets tasks])

    # Configuration for the application, engines, and railties goes here.
    #
    # These settings can be overridden in specific environments using the files
    # in config/environments, which are processed later.
    #
    config.time_zone = "Mountain Time (US & Canada)"
    # config.eager_load_paths << Rails.root.join("extras")

    # A public, read-only site with no accounts and no forms has nothing to keep
    # in a session, so it sets no cookie at all.
    config.session_store :disabled

    # THE FRIENDLY NOT-FOUND PAGE (studio-engine docs/NOT_FOUND_PAGE.md, task
    # rantly-adopts-not-found-page). A lost visitor, on an unknown address or a
    # handle or rant that is not in the sample file, gets Rantly's name, mark and
    # a button home inside the site's own layout, with status 404. JSON keeps
    # Rails' 404 JSON. If the page cannot render, the branded public/404.html
    # answers instead. Guarded so an engine without it (before 0.135.0) keeps
    # Rails' own exceptions app and public/404.html.
    config.exceptions_app = Studio::ExceptionsApp.new if defined?(Studio::ExceptionsApp)

    # A handle or rant that is not in data/sample.yml is a 404, the same as an
    # unknown address: the controller lets SampleData::NotFound go, Rails maps it
    # to 404 here and hands it to the exceptions app above, so one page serves
    # both. Rails logs the error's message ("no user @nobody") with the request.
    config.action_dispatch.rescue_responses["SampleData::NotFound"] = :not_found
  end
end
