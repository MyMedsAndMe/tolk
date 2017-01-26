require 'rails'

module Tolk
  class Engine < Rails::Engine
    isolate_namespace Tolk

    initializer :assets do |app|
      app.config.assets.precompile += ['tolk/libraries.js']
    end

    initializer :append_migrations do |app|
      unless app.root.to_s.match root.to_s
        config.paths["db/migrate"].expanded.each do |expanded_path|
          app.config.paths["db/migrate"] << expanded_path
        end
      end
    end

    # We need one of the two pagination engines loaded by this point.
    # We don't care which one, just one of them will do.
    begin
      require 'kaminari'
    rescue LoadError
      begin
        require 'will_paginate'
      rescue LoadError
       puts "Please add the kaminari or will_paginate gem to your application's Gemfile."
       puts "The Tolk engine needs either kaminari or will_paginate in order to paginate."
       exit
      end
    end
  end
end
