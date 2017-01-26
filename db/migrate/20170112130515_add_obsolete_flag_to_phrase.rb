class AddObsoleteFlagToPhrase < ActiveRecord::Migration
  def change
    add_column :tolk_phrases, :obsolete, :boolean, null: false, default: false
  end
end
