# frozen_string_literal: true
class TolkAddCategoryToPhrases < ActiveRecord::Migration[4.2]
  def change
    add_column :tolk_phrases, :category, :string, null: false, default: "General"
  end
end
