# frozen_string_literal: true
module Tolk
  class Phrase < ActiveRecord::Base
    DOT = "."
    DEFAULT_CATEGORY = "General"

    self.table_name = "tolk_phrases"

    validates :key, uniqueness: true

    paginates_per 30

    has_many :translations, class_name: "Tolk::Translation", dependent: :destroy do
      def primary
        to_a.detect { |t| t.locale_id == Tolk::Locale.primary_locale.id }
      end

      def for(locale)
        to_a.detect { |t| t.locale_id == locale.id }
      end
    end

    attr_accessor :translation

    scope :containing_text, ->(q) { q.presence && where(Tolk::Phrase.arel_table[:key].matches("%#{q}%")) }
    scope :with_category, ->(cat) { where(category: cat) }

    def self.categories
      Tolk::Phrase.select(:category).order(:category).distinct.pluck(:category)
    end
  end
end
