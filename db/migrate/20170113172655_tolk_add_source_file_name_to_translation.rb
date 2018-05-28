# frozen_string_literal: true
class TolkAddSourceFileNameToTranslation < ActiveRecord::Migration[4.2]
  def change
    add_column :tolk_translations, :source, :string
  end
end
