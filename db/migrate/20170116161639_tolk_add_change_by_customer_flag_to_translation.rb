# frozen_string_literal: true
class TolkAddChangeByCustomerFlagToTranslation < ActiveRecord::Migration[4.2]
  def change
    add_column :tolk_translations, :pristine, :boolean, null: false, default: true
  end
end
