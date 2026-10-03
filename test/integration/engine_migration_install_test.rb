require "test_helper"
require "open3"

# The hub's release sweep runs `bin/rails studio_engine:install:migrations` in
# every release member whose Gemfile names studio-engine, after each engine
# publish, and aborts the release if it exits non-zero (mcritchie-studio
# bin/release.rb, install_engine_migrations!). Rails' own version of the task
# dies in an app with no ActiveRecord, so the Rakefile replaces it.
class EngineMigrationInstallTest < ActiveSupport::TestCase
  test "the engine's migration installer exits 0 and installs nothing" do
    out, err, status = Open3.capture3("bin/rails", "studio_engine:install:migrations", chdir: Rails.root.to_s)
    assert status.success?, "exited #{status.exitstatus}: #{err}"
    assert_includes out, "no studio-engine migrations to install"
    refute Rails.root.join("db/migrate").exist?, "Rantly has no database; nothing belongs in db/migrate"
  end
end
