require "test_helper"
require "open3"

# The hub's release sweep runs `bin/rails studio_engine:install:migrations` in
# every release member whose Gemfile names studio-engine, after each engine
# publish, and aborts the release if it exits non-zero or if the migrations it
# copies will not migrate (mcritchie-studio bin/release.rb,
# install_engine_migrations!). Rantly loads ActiveRecord for its token database
# only (config/database.yml), so the engine would draw Rails' own installer and
# copy its Postgres-only migrations in. lib/tasks/token_database.rake replaces
# that installer with a no-op; these tests pin what the sweep depends on.
class EngineMigrationInstallTest < ActiveSupport::TestCase
  TASK = "studio_engine:install:migrations".freeze

  test "the engine's migration installer exits 0 and creates no migrations" do
    _out, err, status = Open3.capture3("bin/rails", TASK, chdir: Rails.root.to_s)

    assert status.success?, "exited #{status.exitstatus}: #{err}"
    assert_empty Dir[Rails.root.join("db/migrate/*").to_s], "the token database takes no engine migrations; nothing belongs in db/migrate"
  end

  # The sweep asks `bin/rails -T <task>` first and runs the task only when it is
  # listed. Listed or not, it must not copy anything, but an installer that
  # vanished from -T would hide the day the override stopped loading.
  test "the installer is listed, and its description is the token database's no-op" do
    out, err, status = Open3.capture3("bin/rails", "-T", TASK, chdir: Rails.root.to_s)

    assert status.success?, "exited #{status.exitstatus}: #{err}"
    assert_match(/#{Regexp.escape(TASK)}\s+# No-op: Rantly's token database/, out)
  end

  # `rails -W <task>` prints every file that defines the task. Rails' engine
  # still declares it, and Rantly's rake file clears its actions and adds the
  # no-op. If the rake file is ever deleted while ActiveRecord stays loaded,
  # the last definition is Rails' again and this goes red before a release
  # sweep copies Postgres migrations into a SQLite app.
  test "the definition that runs is Rantly's token-database no-op" do
    out, err, status = Open3.capture3("bin/rails", "-W", TASK, chdir: Rails.root.to_s)

    assert status.success?, "exited #{status.exitstatus}: #{err}"
    definitions = out.lines.grep(/#{Regexp.escape(TASK)}\s/)
    assert_includes definitions.last, Rails.root.join("lib/tasks/token_database.rake").to_s
  end
end
