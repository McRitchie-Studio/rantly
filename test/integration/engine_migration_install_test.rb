require "test_helper"
require "open3"

# The hub's release sweep runs `bin/rails studio_engine:install:migrations` in
# every release member whose Gemfile names studio-engine, after each engine
# publish, and aborts the release if it exits non-zero (mcritchie-studio
# bin/release.rb, install_engine_migrations!). Rails' own version of the task
# dies in an app with no ActiveRecord; studio-engine >= 0.86 replaces it there
# with a no-op. Rantly carries no task of its own, so what is pinned here is
# the behaviour the sweep depends on, not anybody's wording.
class EngineMigrationInstallTest < ActiveSupport::TestCase
  TASK = "studio_engine:install:migrations".freeze

  test "the engine's migration installer exits 0 and creates no migrations" do
    _out, err, status = Open3.capture3("bin/rails", TASK, chdir: Rails.root.to_s)

    assert status.success?, "exited #{status.exitstatus}: #{err}"
    assert_empty Dir[Rails.root.join("db/migrate/*").to_s], "Rantly has no database; nothing belongs in db/migrate"
    refute Rails.root.join("db").exist?, "Rantly has no database; the installer should create no db directory"
  end

  # `rails -W <task>` prints the file that defines the task. An override in
  # Rantly's Rakefile or lib/tasks would answer from there and could hide an
  # engine whose own installer had started failing again.
  test "the installer that runs is the engine's own, not one Rantly defines" do
    out, err, status = Open3.capture3("bin/rails", "-W", TASK, chdir: Rails.root.to_s)

    assert status.success?, "exited #{status.exitstatus}: #{err}"
    definitions = out.lines.grep(/#{Regexp.escape(TASK)}\s/)
    assert_equal 1, definitions.size, "expected one definition of #{TASK}, got: #{out}"
    assert_includes definitions.first, Studio::Engine.root.join("lib/studio/engine.rb").to_s
  end
end
