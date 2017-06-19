# frozen_string_literal: true
module Tolk
  class Translation < ActiveRecord::Base
    NIL_TEXT = "~"
    YAML_ALIAS_MARKER = "*"
    YAML_COMMENT_MARKER = "#"
    TOBE_TRANSLATED_MARKER = "#TR"

    self.table_name = "tolk_translations"

    belongs_to :phrase, class_name: "Tolk::Phrase"
    belongs_to :locale, class_name: "Tolk::Locale"

    serialize :text
    serialize :previous_text

    validate :validate_text_not_nil, if: proc { |r| r.primary.blank? && !r.explicit_nil && !r.boolean? }
    validate :check_matching_variables, if: proc { |tr| tr.primary_translation.present? }
    validates_uniqueness_of :phrase_id, scope: :locale_id
    validates_presence_of :locale_id

    before_save :set_primary_updated
    before_save :set_previous_text

    scope :containing_text, ->(q) { q.presence && where(Tolk::Translation.arel_table[:text].matches("%#{q}%")) }

    attr_accessor :primary
    before_validation :fix_text_type, unless: proc { |r| r.primary }

    attr_accessor :explicit_nil
    before_validation :set_explicit_nil

    attr_accessor :sync_in_progress

    def boolean?
      text.is_a?(TrueClass) || text.is_a?(FalseClass) || ['t', 'true', 'f', 'false'].member?(text)
    end

    def up_to_date?
      not out_of_date?
    end

    def out_of_date?
      primary_updated?
    end

    def primary_translation
      @_primary_translation ||= begin
        if locale && !locale.primary?
          phrase.translations.primary
        end
      end
    end

    def text=(value)
      value = case
              when value.kind_of?(Fixnum)
                value.to_s
              when primary_translation && primary_translation.boolean?
                value = value.to_s.downcase.strip
                value.present? ? %w[true t].member?(value) : NIL_TEXT
              when value.is_a?(String)
                value = value.strip if Tolk.config.strip_texts
                value.presence || NIL_TEXT
              else
                value
              end

      super value
    end

    def value
      if text.is_a?(String) && /^\d+$/.match(text)
        text.to_i
      elsif boolean?
        %w[true t].member?(text.to_s.downcase.strip)
      else
        text
      end
    end

    def self.detect_variables(search_in)
      variables = case search_in
                  when String
                    Set.new(search_in.scan(/\{\{(\w+)\}\}/).flatten + search_in.scan(/\%\{(\w+)\}/).flatten)
                  when Array
                    search_in.inject(Set.new) { |carry, item| carry + detect_variables(item) }
                  when Hash
                    search_in.values.inject(Set.new) { |carry, item| carry + detect_variables(item) }
                  else
                    Set.new
                  end

      # delete special i18n variable used for pluralization itself (might not be used in all values of
      # the pluralization keys, but is essential to use pluralization at all)
      if search_in.is_a?(Hash)
        variables.delete_if {|v| v == 'count' }
      else
        variables
      end
    end

    def variables
      self.class.detect_variables(text)
    end

    def variables_match?
      self.variables == primary_translation.variables
    end

    private

    def set_explicit_nil
      if self.text == NIL_TEXT
        self.text = nil
        self.explicit_nil = true
      end
    end

    def yaml_load_safe?
      ![YAML_COMMENT_MARKER, YAML_ALIAS_MARKER].any? { |m| text.strip.start_with? m }
    end

    # NOTE: Text type conversion leads to converting "Yes" -> true.
    #       This will brake yes_no: keys.
    def fix_text_type
      true
    end

    def set_primary_updated
      self.primary_updated = false
      true
    end

    def set_previous_text
      return true unless text_changed?
      self.previous_text = self.text_was
      self.pristine = false unless sync_in_progress
      true
    end

    def check_matching_variables
      return true unless Tolk.config.check_variable

      unless variables_match?
        if primary_translation.variables.empty?
          self.errors.add(:variables, "The primary translation does not contain substitutions, so this should neither.")
        else
          self.errors.add(:variables, "The translation should contain the substitutions of the primary translation: (#{primary_translation.variables.to_a.join(', ')}), found (#{self.variables.to_a.join(', ')}).")
        end
      end
    end

    def validate_text_not_nil
      return unless text.nil?
      errors.add :text, :blank
    end
  end
end
