module Tolk
  class ApplicationController < ActionController::Base
    include Tolk::Pagination::Methods

    helper :all
    protect_from_forgery

    cattr_accessor :authenticator
    before_action :authenticate

    def authenticate
#      self.authenticator.bind(self).call if self.authenticator && self.authenticator.respond_to?(:call)
      instance_exec(nil, &self.authenticator) if self.authenticator && self.authenticator.respond_to?(:instance_exec)
    end

    def ensure_no_primary_locale
      # HACK: would like to allow to edit primary locale
      # redirect_to tolk.locales_path if @locale.primary?
    end
  end
end
