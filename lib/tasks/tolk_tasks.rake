# frozen_string_literal: true
namespace :tolk do
  desc "Update locale"
  task :update_locale, [:old_name, :new_name] => :environment do |_t, args|
    old_name, new_name = args[:old_name], args[:new_name]
    puts Tolk::Locale.rename(old_name, new_name)
  end

  desc "Add database tables, copy over the assets, and import existing translations"
  task setup: :environment do
    Rake::Task["db:migrate"].invoke
    Rake::Task["tolk:sync"].invoke
  end

  desc "Sync Tolk with the default locale's yml file"
  task sync: :environment do
    Tolk::Locale.sync!
    Rake::Task["tolk:dump_all"].invoke
  end

  desc "Generate yml files for all the locales defined in Tolk"
  task dump_all: :environment do
    Tolk::Locale.dump_all_to_yaml
  end

  desc "Generate a single yml file for a specific locale"
  task :dump_yaml, [:locale] => :environment do |_t, args|
    locale = args[:locale]
    Tolk::Locale.dump_yaml(locale)
  end

  desc "[DEPRECATED] Please use tolk:sync. Imports data all non default locale yml files to Tolk"
  task import: :environment do
    Rake::Task["tolk:sync"].invoke
  end

  desc "Show all the keys potentially containing HTML values and no _html postfix"
  task html_keys: :environment do
    bad_translations = Tolk::Locale.primary_locale.translations_with_html
    bad_translations.each do |bt|
      puts "#{bt.phrase.key} - #{bt.text}"
    end
  end

  desc "[WARNING] Cleans up Tolk tables."
  task clean: :environment do
    Tolk::Translation.delete_all
    Tolk::Phrase.delete_all
    Tolk::Locale.delete_all
    puts "Tolk data was removed."
  end
end
