require 'test_helper'

class SolidErrors::LifecycleEventsTest < ActiveSupport::TestCase
  include ActionMailer::TestHelper

  def teardown
    SolidErrors.send_emails = false
    SolidErrors.email_to = nil
    SolidErrors.email_on_resolved = false
    SolidErrors.email_on_reopened = false
    ActionMailer::Base.deliveries.clear
  end

  test 'sends email when error is resolved if email_on_resolved is true' do
    SolidErrors.send_emails = true
    SolidErrors.email_to = 'test@example.com'
    SolidErrors.email_on_resolved = true

    error = create_error
    error.occurrences.create!

    assert_enqueued_emails 1 do
      error.update!(resolved_at: Time.current)
    end
  end

  test 'does not send email when error is resolved if email_on_resolved is false' do
    SolidErrors.send_emails = true
    SolidErrors.email_to = 'test@example.com'
    SolidErrors.email_on_resolved = false

    error = create_error
    error.occurrences.create!

    assert_no_enqueued_emails do
      error.update!(resolved_at: Time.current)
    end
  end

  test 'sends email when error is reopened if email_on_reopened is true' do
    SolidErrors.send_emails = true
    SolidErrors.email_to = 'test@example.com'
    SolidErrors.email_on_reopened = true

    error = create_error
    error.occurrences.create!
    error.update!(resolved_at: Time.current)

    assert_enqueued_emails 1 do
      error.update!(resolved_at: nil)
    end
  end

  test 'does not send email when error is reopened if email_on_reopened is false' do
    SolidErrors.send_emails = true
    SolidErrors.email_to = 'test@example.com'
    SolidErrors.email_on_reopened = false

    error = create_error
    error.occurrences.create!
    error.update!(resolved_at: Time.current)

    assert_no_enqueued_emails do
      error.update!(resolved_at: nil)
    end
  end

  private

  def create_error
    Rails.error.report(StandardError.new('test error'))
    SolidErrors::Error.last
  end
end
