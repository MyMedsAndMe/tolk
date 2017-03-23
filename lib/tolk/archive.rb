# frozen_string_literal: true
require "rubygems"
require "rubygems/package"
require "zlib"
require "fileutils"

module Tolk
  module Archive
    module_function

    # Creates a tar file in memory recursively
    # from the given path.
    #
    # Returns a StringIO whose underlying String
    # is the contents of the tar file.
    def tar(path)
      tarfile = StringIO.new
      Gem::Package::TarWriter.new(tarfile) do |tar|
        Dir[File.join(path, "**/*")].each do |file|
          mode = File.stat(file).mode
          relative_file = file.sub(%r{^#{Regexp.escape path.to_s}\/?}, "")

          if File.directory?(file)
            tar.mkdir relative_file, mode
          else
            tar.add_file relative_file, mode do |tf|
              File.open(file, "rb") { |f| tf.write f.read }
            end
          end
        end
      end

      tarfile.rewind
      tarfile
    end

    # gzips the underlying string in the given StringIO,
    # returning a new StringIO representing the
    # compressed file.
    def gzip(tarfile)
      gz = StringIO.new
      # HACK: As we have ApplicationModule included into Object - I need to remove #path from StringIO instance
      gz.class.instance_eval { undef_method :path } if gz.respond_to? :path
      begin
        z = Zlib::GzipWriter.new(gz)
        z.write tarfile.string
      ensure
        z && z.close # this is necessary!
      end

      # z was closed to write the gzip footer, so
      # now we need a new StringIO
      StringIO.new gz.string
    end

    # un-gzips the given IO, returning the
    # decompressed version as a StringIO
    def ungzip(tarfile)
      z = Zlib::GzipReader.new(tarfile)
      unzipped = StringIO.new(z.read)
      z.close
      unzipped
    end

    # untars the given IO into the specified
    # directory
    def untar(io, destination)
      Gem::Package::TarReader.new io do |tar|
        tar.each do |tarfile|
          destination_file = File.join destination, tarfile.full_name

          if tarfile.directory?
            FileUtils.mkdir_p destination_file
          else
            destination_directory = File.dirname(destination_file)
            FileUtils.mkdir_p destination_directory unless File.directory?(destination_directory)
            File.open destination_file, "wb" do |f|
              f.write tarfile.read
            end
          end
        end
      end
    end
  end
end
