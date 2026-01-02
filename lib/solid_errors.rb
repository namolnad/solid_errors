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
  # Email notification configuration
  # email_milestone_counts: nil (default, emails all occurrences), [] (no count-based emails), [1,10,100] (email at these counts)
  # email_rate_threshold_count: number of occurrences within time window to trigger email
  # email_rate_threshold_window: time window in seconds for rate threshold
  mattr_accessor :email_milestone_counts, default: nil
  mattr_accessor :email_rate_threshold_count, default: nil
  mattr_accessor :email_rate_threshold_window, default: nil
  # Lifecycle event email configuration
  # email_on_resolved: send email when error is marked as resolved
  # email_on_reopened: send email when resolved error is reopened
  mattr_accessor :email_on_resolved, default: false
  mattr_accessor :email_on_reopened, default: false

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
  end
end
