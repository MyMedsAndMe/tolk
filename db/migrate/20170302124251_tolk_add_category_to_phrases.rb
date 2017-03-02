# frozen_string_literal: true
class TolkAddCategoryToPhrases < ActiveRecord::Migration
  def change
    add_column :tolk_phrases, :category, :string, null: false
  end
end
