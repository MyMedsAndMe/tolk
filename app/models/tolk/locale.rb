require "tolk/config"
require "tolk/pagination"

module Tolk
  class Locale < ActiveRecord::Base
    include Tolk::Pagination::Methods

    CUSTOMER_PREFIX = "customer".freeze
    DEFAULT_EXPORT_PATH = "tolk_export".freeze
    DEFAULT_PATH_TEMPLATE = "#{DEFAULT_EXPORT_PATH}/%{name}.yml".freeze

    self.table_name = "tolk_locales"

    def self._dump_path
      # Necessary to acces rails.root at runtime !
      @dump_path ||= Tolk.config.dump_path.is_a?(Proc) ? instance_eval(&Tolk.config.dump_path) : Tolk.config.dump_path
    end

    has_many :translations, class_name: "Tolk::Translation", dependent: :destroy
    has_many :phrases, through: :translations, class_name: "Tolk::Phrase"

    accepts_nested_attributes_for :translations, reject_if: proc { |attributes| attributes["text"].blank? }
    before_validation :remove_invalid_translations_from_target, on: :update

    cattr_accessor :locales_config_path
    self.locales_config_path = self._dump_path

    cattr_accessor :primary_locale_name
    self.primary_locale_name = Tolk.config.primary_locale_name || I18n.default_locale.to_s

    include Tolk::Sync

    validates_uniqueness_of :name
    validates_presence_of :name

    cattr_accessor :special_prefixes
    self.special_prefixes = ["activerecord.attributes"]

    cattr_accessor :special_keys
    self.special_keys = ["activerecord.models"]

    class << self
      def primary_locale(reload = false)
        @_primary_locale = nil if reload
        @_primary_locale ||= begin
          raise "Primary locale is not set. Please set Locale.primary_locale_name in your application's config file" unless self.primary_locale_name
          where(name: self.primary_locale_name).first_or_create
        end
      end

      def primary_language_name
        primary_locale.language_name
      end

      def secondary_locales
        all - [primary_locale]
      end

      def dump_all(*args)
        ActiveRecord::Base.transaction do
          m3_translation = I18n::Backend::ActiveRecord::Translation
          m3_translation.delete_all

          query = self.includes(:translations, :phrases)

          query.each do |locale|
            locale.translations.each do |t|
              m3_translation.create!(locale: locale.name, key: t.phrase.key, value: locale.safe_value(t.value))
            end
          end
        end
      end

      def dump_all_to_yaml(*args)
        # HACK: We allow to edit primary locale. Need to dump it.
        all.each { |locale| locale.dump(*args) }
      end

      def dump_yaml(name, *args)
        where(name: name).first.dump(*args)
      end

      def special_key_or_prefix?(prefix, key)
        self.special_prefixes.include?(prefix) || self.special_keys.include?(key)
      end

      # http://cldr.unicode.org/index/cldr-spec/plural-rules - TODO: usage of 'none' isn't standard-conform
      PLURALIZATION_KEYS = ["none", "zero", "one", "two", "few", "many", "other"].freeze
      def pluralization_data?(data)
        keys = data.keys.map(&:to_s)
        keys.all? {|k| PLURALIZATION_KEYS.include?(k) }
      end

      def rename(old_name, new_name)
        if old_name.blank? || new_name.blank?
          "You need to provide both names, aborting."
        else
          if locale = where(name: old_name).first
            locale.name = new_name
            locale.save
            "Locale ' #{old_name}' was renamed '#{new_name}'"
          else
            "Locale with name '#{old_name}' not found."
          end
        end
      end
    end

    def dump(to = self.locales_config_path, exporter = Tolk::Export)
      query = translations.includes(:phrase).references(:phrases).order(Tolk::Phrase.arel_table[:key])

      query.group_by { |r| r.phrase.category }.each do |category, translations|
        data = { name => hash_from_records(translations) }
        filename = if Tolk::Phrase::DEFAULT_CATEGORY == category
                     name
                   else
                     "#{category.tr(' ', '_').downcase}.#{name}"
                   end
        path = Rails.root.join(format(DEFAULT_PATH_TEMPLATE, name: filename))
        exporter.dump(name: name, data: data, destination: path)
      end
    end

    def has_updated_translations?
      translations.where("tolk_translations.primary_updated" => true).count > 0
    end

    def phrases_with_updated_translation(page = nil)
      find_phrases_with_translations(page, :"tolk_translations.primary_updated" => true)
    end

    def count_phrases_with_updated_translation(page = nil)
      find_phrases_with_translations(page, :"tolk_translations.primary_updated" => true).count
    end

    def phrases_with_translation(page = nil)
      find_phrases_with_translations(page, :"tolk_translations.primary_updated" => false)
    end

    def phrases_without_translation(page = nil)
      phrases = Tolk::Phrase.all.order("tolk_phrases.key ASC")

      existing_ids = self.translations.select("tolk_translations.phrase_id").map(&:phrase_id).uniq
      phrases = phrases.where("tolk_phrases.id NOT IN (?)", existing_ids) if existing_ids.present?

      result = phrases.public_send(pagination_method, page)
      if Rails.version =~ /^4\.0/
        ActiveRecord::Associations::Preloader.new result, :translations
      else
        ActiveRecord::Associations::Preloader.new().preload(result, :translations)
      end

      result
    end

    def count_phrases_without_translation(category = nil)
      ph = Tolk::Phrase.arel_table
      tr = Tolk::Translation.arel_table

      query = ph.project(ph[:id].count)
        .join(tr, Arel::Nodes::OuterJoin)
        .on(tr[:phrase_id].eq(ph[:id]).and(tr[:locale_id].in([nil, id])))
        .where(tr[:locale_id].eq(nil))

      query = query.where(ph[:category].eq(category)) if category

      result = ActiveRecord::Base.connection.exec_query(query.to_sql)
      result.rows.first.first.to_i
    end

    def count_all_phrases(category = nil)
      Tolk::Phrase.with_category(category).count
    end

    def count_phrases_with_translation(category = nil)
      Tolk::Translation.joins(:phrase).references(:phrase).where(locale: self).merge(Tolk::Phrase.with_category(category)).count
    end

    def translation_percent
      coef = 1 - count_phrases_without_translation.to_f / Tolk::Phrase.count.to_f
      (coef * 100).round(2)
    end

    def search_phrases(query, scope, key_query, page = nil, category = nil)
      return [] unless [query, key_query, category].any?(&:present?)

      translations = case scope
                     when :origin
                       Tolk::Locale.primary_locale.translations.containing_text(query)
                     else # :target
                       self.translations.containing_text(query)
                     end

      phrases = Tolk::Phrase.all.order("tolk_phrases.key ASC")
      phrases = phrases.containing_text(key_query).with_category(category)

      phrases = phrases.where(id: translations.select(:phrase_id))
      phrases.public_send(pagination_method, page)
    end

    def search_phrases_without_translation(query, page = nil)
      return phrases_without_translation(page) unless query.present?

      phrases = Tolk::Phrase.all.order("tolk_phrases.key ASC")

      found_translations_ids = Tolk::Locale.primary_locale.translations.where(["tolk_translations.text LIKE ?", "%#{query}%"]).to_a.map(&:phrase_id).uniq
      existing_ids = self.translations.select("tolk_translations.phrase_id").to_a.map(&:phrase_id).uniq
      phrases = phrases.where(["tolk_phrases.id NOT IN (?) AND tolk_phrases.id IN(?)", existing_ids, found_translations_ids]) if existing_ids.present?
      result = phrases.public_send(pagination_method, page)
      if Rails.version =~ /^4\.0/
        ActiveRecord::Associations::Preloader.new result, :translations
      else
        ActiveRecord::Associations::Preloader.new().preload(result, :translations)
      end

      result
    end

    def to_hash
      data = hash_from_records(translations.includes(:phrase).references(:phrases).order(phrases.arel_table[:key]))
      { name => data }
    end

    def to_param
      name.parameterize
    end

    def primary?
      name == self.class.primary_locale_name
    end

    def language_name
      Tolk.config.mapping[self.name] || self.name
    end

    def get(key)
      if phrase = Tolk::Phrase.where(key: key).first
        t = self.translations.where(phrase_id: phrase.id).first
        t.text if t
      end
    end

    def translations_with_html
      translations = self.translations.all(conditions: "tolk_translations.text LIKE '%>%' AND
        tolk_translations.text LIKE '%<%' AND tolk_phrases.key NOT LIKE '%_html'", joins: :phrase)
      if Rails.version =~ /^4\.0/
        ActiveRecord::Associations::Preloader.new translations, :phrase
      else
        ActiveRecord::Associations::Preloader.new().preload(translations, :phrase)
      end
      translations
    end

    def safe_value(value)
      return " " if value.blank? || Tolk::Translation::NIL_TEXT == value

      object = Tolk::YAML.load(value.presence)
      object.is_a?(Array) ? object : value.presence
    end

    private

    def hash_from_records(records)
      records.each_with_object({}) do |translation, locale|
        if translation.phrase.key.include?(".")
          locale.deep_merge!(unsquish(translation.phrase.key, safe_value(translation.value)))
        else
          locale[translation.phrase.key] = safe_value(translation.value)
        end
      end
    end

    def remove_invalid_translations_from_target
      self.translations.target.dup.each do |t|
        unless t.valid?
          self.translations.target.delete(t)
        else
          t.updated_at_will_change!
        end
      end

      true
    end

    def find_phrases_with_translations(page, conditions = {})
      result = Tolk::Phrase.where({ :"tolk_translations.locale_id" => id }.merge(conditions))
        .joins(:translations)
        .order("tolk_phrases.key ASC")
        .public_send(pagination_method, page)

      result.each do |phrase|
        phrase.translation = phrase.translations.for(self)
      end

      if Rails.version =~ /^4\.0/
        ActiveRecord::Associations::Preloader.new result, :translations
      else
        ActiveRecord::Associations::Preloader.new().preload(result, :translations)
      end

      result
    end

    def unsquish(string, value)
      if string.is_a?(String)
        unsquish(string.split("."), value)
      elsif string.size == 1
        { string.first => value }
      else
        key  = string[0]
        rest = string[1..-1]
        { key => unsquish(rest, value) }
      end
    end
  end
end
