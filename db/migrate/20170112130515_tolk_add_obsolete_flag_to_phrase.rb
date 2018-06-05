# frozen_string_literal: true
class TolkAddObsoleteFlagToPhrase < ActiveRecord::Migration[4.2]
  def change
    add_column :tolk_phrases, :obsolete, :boolean, null: false, default: false
  end
end
