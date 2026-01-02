module SolidErrors
  # adapted from: https://github.com/codergeek121/email_error_reporter/blob/main/lib/email_error_reporter/error_mailer.rb
  class ErrorMailer < (defined?(ActionMailer::Base) ? ActionMailer::Base : Object)
    def error_occurred(occurrence, trigger: nil)
      unless defined?(ActionMailer::Base)
        raise "ActionMailer is not available. Make sure that you require \"action_mailer/railtie\" in application.rb"
      end
      @occurrence = occurrence
      @error = occurrence.error
      @trigger = trigger

      # Customize subject based on trigger (lifecycle event)
      subject = case trigger
      when :resolved
        "✅ RESOLVED: #{@error.exception_class}"
      when :reopened
        "🔄 REOPENED: #{@error.exception_class}"
      when :milestone
        occurrence_count = @error.occurrences.count
        "#{@error.severity_emoji} #{@error.exception_class} (#{occurrence_count.ordinalize} occurrence)"
      else
        "#{@error.severity_emoji} #{@error.exception_class}"
      end

      if SolidErrors.email_subject_prefix.present?
        subject = [SolidErrors.email_subject_prefix, subject].join(" ").squish!
      end
      mail(
        subject: subject,
        from: SolidErrors.email_from,
        to: SolidErrors.email_to
      )
    end
  end
end
