class AddSourceFileNameToTranslation < ActiveRecord::Migration
  def change
    add_column :tolk_translations, :source, :string
  end
end
