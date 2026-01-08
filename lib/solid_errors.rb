# frozen_string_literal: true

require_relative "solid_errors/version"
require_relative "solid_errors/sanitizer"
require_relative "solid_errors/subscriber"
require_relative "solid_errors/engine"

module SolidErrors
  mattr_accessor :connects_to
  mattr_accessor :base_controller_class, default: "::ActionController::Base"
  mattr_writer :username
  mattr_writer :password
  mattr_accessor :send_emails, default: false
  mattr_accessor :email_from, default: "solid_errors@noreply.com"
  mattr_accessor :email_to
  mattr_accessor :email_subject_prefix
  mattr_accessor :destroy_after
  mattr_writer :url_helper_name, :url_options

  class << self
    # use method instead of attr_accessor to ensure
    # this works if ENV variable set after SolidErrors is loaded
    def username
      @username ||= ENV["SOLIDERRORS_USERNAME"] || @@username
    end

    # use method instead of attr_accessor to ensure
    # this works if ENV variable set after SolidErrors is loaded
    def password
      @password ||= ENV["SOLIDERRORS_PASSWORD"] || @@password
    end

    def send_emails?
      send_emails && email_to.present?
    end

    def url_helper_name
      @url_helper_name ||= detect_url_helper_name
    end

    def url_options
      @url_options ||= detect_url_options
    end

    private

    def find_solid_errors_route
      @solid_errors_route ||= Rails.application.routes.routes.find do |r|
        r.name&.to_s&.end_with?("solid_errors")
      end
    end

    def detect_url_helper_name
      find_solid_errors_route&.name&.to_sym || :solid_errors
    end

    def detect_url_options
      subdomain = find_solid_errors_route&.constraints&.dig(:subdomain)
      subdomain.is_a?(String) ? { subdomain: subdomain } : {}
    end
  end
end
