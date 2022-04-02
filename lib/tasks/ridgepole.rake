namespace :ridgepole do
  desc 'Dry run applying database schema'
  task dry_run: :environment do
    ridgepole('--apply', "-E #{Rails.env}", "--file #{schema_file}", '--dry-run')
  end

  desc 'Apply database schema'
  task apply: :environment do
    ridgepole('--apply', "-E #{Rails.env}", "--file #{schema_file}")
    Rake::Task['annotate_models'].invoke if Rails.env.development?
  end

  desc 'Export database schema'
  task export: :environment do
    ridgepole('--export', "-E #{Rails.env}", '--split', "--output #{schema_file}")
  end

  private def schema_file
    Rails.root.join('db/Schemafile')
  end

  private def config_file
    Rails.root.join('config/database.yml')
  end

  private def ridgepole(*options)
    command = ['bundle exec ridgepole', "--config #{config_file}", "-s primary"]
    system [command + options].join(' ')
  end
end