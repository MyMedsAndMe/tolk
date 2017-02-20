# frozen_string_literal: true
class TolkAddChangeByCustomerFlagToTranslation < ActiveRecord::Migration
  def change
    add_column :tolk_translations, :pristine, :boolean, null: false, default: true
  end
end
