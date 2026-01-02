module SolidErrors
  class Occurrence < Record
    belongs_to :error, class_name: "SolidErrors::Error"

    after_create_commit :send_email, if: -> { SolidErrors.send_emails? && SolidErrors.email_to.present? }
    after_create_commit :clear_resolved_errors, if: :should_clear_resolved_errors?

    # The parsed exception backtrace. Lines in this backtrace that are from installed gems
    # have the base path for gem installs replaced by "[GEM_ROOT]", while those in the project
    # have "[PROJECT_ROOT]".
    # @return [Array<{:number, :file, :method => String}>]
    def parsed_backtrace
      return @parsed_backtrace if defined? @parsed_backtrace

      @parsed_backtrace = parse_backtrace(backtrace.split("\n"))
    end

    private

    def parse_backtrace(backtrace)
      Backtrace.parse(backtrace)
    end

    def send_email
      return unless should_send_email?

      trigger = email_trigger
      ErrorMailer.error_occurred(self, trigger: trigger).deliver_later
    end

    def should_send_email?
      # Check if we've hit a milestone count (if configured)
      return true if milestone_reached?

      # Check if we've exceeded the rate threshold (if configured)
      return true if rate_threshold_exceeded?

      false
    end

    def email_trigger
      return :milestone if milestone_reached?
      nil
    end

    def milestone_reached?
      # If email_milestone_counts is nil, email all occurrences (default behavior)
      return true if SolidErrors.email_milestone_counts.nil?

      # If email_milestone_counts is empty array, don't email based on counts
      return false if SolidErrors.email_milestone_counts.empty?

      # Otherwise, only email if we're at a milestone
      occurrence_count = error.occurrences.count
      SolidErrors.email_milestone_counts.include?(occurrence_count)
    end

    def rate_threshold_exceeded?
      # Only check rate threshold if both count and window are configured
      return false unless SolidErrors.email_rate_threshold_count && SolidErrors.email_rate_threshold_window

      window_start = SolidErrors.email_rate_threshold_window.seconds.ago
      recent_count = error.occurrences.where(created_at: window_start...).count

      # Only send email if we've just crossed the threshold (not on every subsequent occurrence)
      recent_count == SolidErrors.email_rate_threshold_count
    end

    def clear_resolved_errors
      transaction do
        SolidErrors::Occurrence
          .where(error: SolidErrors::Error.resolved)
          .where(created_at: ...SolidErrors.destroy_after.ago)
          .delete_all
        SolidErrors::Error.resolved
          .where
          .missing(:occurrences)
          .delete_all
      end
    end

    def should_clear_resolved_errors?
      return false unless SolidErrors.destroy_after
      return false unless SolidErrors.destroy_after.respond_to?(:ago)
      return false unless (id % 100).zero?

      true
    end
  end
end
