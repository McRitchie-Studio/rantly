require "test_helper"
require "open3"

# THE TOKEN DATABASE (config/database.yml): an empty SQLite file that exists so
# the shared tooling finds the ActiveRecord app it expects. Desk bringup runs
# `bin/rails db:prepare`; the pre-flight's test-database guard boots the app at
# RAILS_ENV=test and reads the database it connects to, and admits a FILE only
# when it sits inside the desk. These tests pin each of those.
class TokenDatabaseTest < ActiveSupport::TestCase
  test "ActiveRecord connects to a SQLite file under the app root" do
    config = ActiveRecord::Base.connection_db_config

    assert_equal "sqlite3", config.adapter
    assert ActiveRecord::Base.connection.active?
    path = File.expand_path(config.database, Rails.root)
    assert path.start_with?(Rails.root.join("storage").to_s + File::SEPARATOR), "#{path} is not under storage/"
  end

  test "the schema loads and holds no tables of its own" do
    assert_equal 0, ActiveRecord::Base.connection_pool.migration_context.current_version
    own = ActiveRecord::Base.connection.tables - %w[ar_internal_metadata schema_migrations]
    assert_empty own, "the token database holds nothing; found #{own.inspect}"
    assert_match(/define\(version: 0\) do\s*end/, Rails.root.join("db/schema.rb").read)
  end

  # A desk exports DATABASE_URL at a Postgres database (bin/agent-worktree), and
  # the release gate sets one too. Rails merges DATABASE_URL over a `database:`
  # entry; an entry with its own `url:` is left alone. This boots the app with
  # the desk's kind of URL and reads back the database, the probe the
  # pre-flight's guard runs (mcritchie-studio bin/lib/desk_guard.rb, PROBE).
  test "a Postgres DATABASE_URL in the environment does not move the test database" do
    env = { "RAILS_ENV" => "test", "DATABASE_URL" => "postgresql://localhost/rantly_development_some_desk" }
    probe = 'print "DESKDB=#{ActiveRecord::Base.connection_db_config.database}\n"'
    out, err, status = Open3.capture3(env, "bin/rails", "runner", probe, chdir: Rails.root.to_s)

    assert status.success?, "exited #{status.exitstatus}: #{err}"
    assert_equal "storage/test.sqlite3", out[/DESKDB=(.*)$/, 1]
  end

  # Production eager loads. With ActiveRecord loaded the engine would eager
  # load its controllers, which skip a :require_authentication Rantly never
  # defines, and boot would raise (config/application.rb,
  # rantly.engine_footer_only_eager_load). Booted in its own process so the
  # check is production's eager load, whatever this suite's config is.
  test "the app eager loads in production, so the dyno boots" do
    env = { "RAILS_ENV" => "production", "SECRET_KEY_BASE_DUMMY" => "1", "RAILS_LOG_LEVEL" => "warn" }
    out, err, status = Open3.capture3(env, "bin/rails", "runner",
                                      'Rails.application.eager_load!; print "EAGER=#{Rails.application.config.eager_load}"',
                                      chdir: Rails.root.to_s)

    assert status.success?, "production boot failed: #{err.lines.grep(/Error/).first(3).join}"
    assert_includes out, "EAGER=true"
  end

  test "db:prepare succeeds on the empty schema" do
    env = { "RAILS_ENV" => "test" }
    _out, err, status = Open3.capture3(env, "bin/rails", "db:prepare", chdir: Rails.root.to_s)

    assert status.success?, "db:prepare exited #{status.exitstatus}: #{err}"
  end
end
