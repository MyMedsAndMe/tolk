# frozen_string_literal: true
module Tolk
  module Sync
    def self.included(base)
      base.send :extend, ClassMethods
    end

    module ClassMethods
      def sync!
        Tolk::Phrase.update_all(obsolete: true)
        locales = collect_locales
        collect_translation_files(locales)
        # NOTE: Have to use fresh file listing
        reload_translations(Dir[Rails.root.join("config", "locales", "**", "*.{rb,yml}")])
      end

      def collect_locales
        self.primary_locale
        reload_translations(translation_files)
        locales = I18n.backend.send(:translations).keys.map { |name| Tolk::Locale.find_or_create_by(name: name) }
        locales.delete(primary_locale)
        [primary_locale] + locales
      end

      def collect_translation_files(locales)
        locales.each do |locale|
          print "Loading #{locale.name} locale..."
          translation_files.each do |filename|
            category = category_name(File.basename(filename))
            reload_translations(filename)
            translations = flat_hash(I18n.backend.send(:translations)[locale.name.to_sym])
            sync_phrases(locale, translations, category)
          end
          puts "done."
        end
      end

      def translation_files
        @translation_files ||= Dir[Rails.root.join("config", "locales", "**", "*.{rb,yml}")]
      end

      def reload_translations(paths)
        I18n.backend.reload! if I18n.backend.initialized?
        I18n.backend.instance_variable_set(:@initialized, true)
        I18n.backend.load_translations(Array(paths))
      end

      private

      def category_name(filename)
        parts = filename.downcase.split(".")
        if parts.size == 3
          # supported name like "category.en.yml"
          parts.first.tr("_", " ").split(" ").map(&:capitalize).join(" ")
        else
          # all other file patterns, like "en.yml" or unsupported names like "one.two.three.en.yml"
          Tolk::Phrase::DEFAULT_CATEGORY
        end
      end

      def flat_hash(data, prefix = "", result = {})
        return {} if data.nil?

        data.each do |key, value|
          current_prefix = prefix.present? ? "#{prefix}.#{key}" : key

          if !value.is_a?(Hash) || Tolk::Locale.pluralization_data?(value)
            result[current_prefix] = value.respond_to?(:stringify_keys) ? value.stringify_keys : value
          else
            flat_hash(value, current_prefix, result)
          end
        end

        result.stringify_keys
      end

      def sync_phrases(locale, translations = {}, category = Tolk::Phrase::DEFAULT_CATEGORY)
        # HACK: support old-style call
        translations, locale = locale, Tolk::Locale.primary_locale if locale.is_a? Hash

        return if translations.empty?
        translations.each do |key, text|
          next unless store?(text)

          phrase = Tolk::Phrase.find_or_create_by(key: key) do |m|
            m.category = category
          end
          phrase.update_column(:obsolete, false)

          translation = Tolk::Translation.find_or_initialize_by(locale: locale, phrase: phrase)

          translation.sync_in_progress = true
          translation.text = text.presence if translation.pristine?
          translation.save!
        end
      end

      def store?(value)
        value.present? && !marked_for_translation?(value)
      end

      def marked_for_translation?(value)
        case value
        when Array
          value.any? { |v| v.to_s.start_with?(Tolk::Translation::TOBE_TRANSLATED_MARKER) }
        when String
          value.to_s.start_with?(Tolk::Translation::TOBE_TRANSLATED_MARKER)
        end
      end
    end
  end
end
