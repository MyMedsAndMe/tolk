# frozen_string_literal: true
class TolkAddSourceFileNameToTranslation < ActiveRecord::Migration
  def change
    add_column :tolk_translations, :source, :string
  end
end
