# frozen_string_literal: true
module Tolk
  class ExportController < Tolk::ApplicationController
    ARCHIVE_NAME_PATTERN = "localisation-data-%s.tar.gz"

    def show
      Tolk::Locale.dump_all_to_yaml
      datum = Tolk::Archive.gzip(Tolk::Archive.tar(Rails.root.join(Tolk::Locale::DEFAULT_EXPORT_PATH)))
      send_data datum.string,
                filename: format(ARCHIVE_NAME_PATTERN, Time.zone.now.iso8601.tr(":", "-")),
                type: "application/octet-stream"
    end
  end
end
