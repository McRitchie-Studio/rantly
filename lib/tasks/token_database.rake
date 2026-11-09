# THE ENGINE'S MIGRATIONS STAY OUT OF THE TOKEN DATABASE.
#
# Rantly loads ActiveRecord only for its token database (config/database.yml),
# an empty SQLite file. With ActiveRecord loaded, studio-engine draws Rails'
# own `studio_engine:install:migrations`, which would copy every engine
# migration into db/migrate. The hub's release sweep runs that task in every
# member after each engine publish (mcritchie-studio bin/release.rb,
# install_engine_migrations!) and then migrates a throwaway copy to dump the
# schema. On SQLite that migrate fails (`t.jsonb` is Postgres-only, and the
# user-profile migrations expect a `users` table), so the sweep would abort.
#
# So the task is cleared and redefined as a no-op that exits 0 and writes
# nothing, which the sweep reads as "no new migrations". It keeps a
# description, so `bin/rails -T` still lists it. Taking the engine's database
# features means moving to Postgres and deleting this file:
# mcritchie-studio docs/agents/modules/token-database.md.
# test/integration/engine_migration_install_test.rb pins it.
task_name = "studio_engine:install:migrations"
Rake::Task[task_name].clear if Rake::Task.task_defined?(task_name)

namespace :studio_engine do
  namespace :install do
    desc "No-op: Rantly's token database takes none of studio-engine's migrations (lib/tasks/token_database.rake)"
    task :migrations do
      puts "studio-engine: Rantly's token database takes no engine migrations (lib/tasks/token_database.rake)"
    end
  end
end
