# Add your own tasks in files placed in lib/tasks ending in .rake,
# for example lib/tasks/capistrano.rake, and they will automatically be available to Rake.

require_relative "config/application"

Rails.application.load_tasks

# Rails defines `studio_engine:install:migrations` for every engine in the
# bundle, but in an app with no ActiveRecord it dies ("Don't know how to build
# task 'app:railties:install:migrations'"). The hub's release sweep runs that
# task in every member that lists it, after each studio-engine publish
# (mcritchie-studio bin/release.rb, install_engine_migrations!), and aborts the
# release on a non-zero exit. Rantly has no database and installs none of the
# engine's migrations, so the task is replaced with one that says so and exits 0.
Rake::Task["studio_engine:install:migrations"].clear if Rake::Task.task_defined?("studio_engine:install:migrations")
namespace :studio_engine do
  namespace :install do
    desc "No-op: Rantly has no database, so it installs none of studio-engine's migrations"
    task :migrations do
      puts "rantly: no database, so no studio-engine migrations to install"
    end
  end
end
