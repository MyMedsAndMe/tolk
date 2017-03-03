# frozen_string_literal: true
require_relative "20170113172655_tolk_add_source_file_name_to_translation"

class TolkRemoveSourceFromTranslations < ActiveRecord::Migration
  def change
    revert TolkAddSourceFileNameToTranslation
  end
end
