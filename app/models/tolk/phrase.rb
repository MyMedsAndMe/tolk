module Tolk
  class Phrase < ActiveRecord::Base
    DOT = ".".freeze
    CATEGORY_FIELD = "category".freeze

    self.table_name = "tolk_phrases"

    validates :key, uniqueness: true

    paginates_per 30

    has_many :translations, class_name: "Tolk::Translation", dependent: :destroy do
      def primary
        to_a.detect {|t| t.locale_id == Tolk::Locale.primary_locale.id}
      end

      def for(locale)
        to_a.detect {|t| t.locale_id == locale.id}
      end
    end

    attr_accessor :translation

    scope :containing_text, ->(q) { q.presence && where(Tolk::Phrase.arel_table[:key].matches("%#{q}%")) }
    scope :with_category, ->(cat) { cat.presence && where(category_field.eq(cat)) }

    def self.category_field
      dot = Arel::Nodes::Quoted.new(DOT)
      Arel::Nodes::NamedFunction.new("SPLIT_PART", [Tolk::Phrase.arel_table[:key], dot, 2])
    end

    def self.categories
      Tolk::Phrase.group(CATEGORY_FIELD).order(CATEGORY_FIELD).pluck(category_field.as(CATEGORY_FIELD).to_sql)
    end

    def category
      key.to_s.split(DOT).second
    end
  end
end
