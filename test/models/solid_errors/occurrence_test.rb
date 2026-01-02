require 'test_helper'

class SolidErrors::OccurrenceTest < ActiveSupport::TestCase
  def teardown
    SolidErrors.destroy_after = nil
    SolidErrors.email_milestone_counts = nil
    SolidErrors.email_rate_threshold_count = nil
    SolidErrors.email_rate_threshold_window = nil
    SolidErrors.email_on_resolved = false
    SolidErrors.email_on_reopened = false
  end

  test 'do not destroy if destroy_after is not set' do
    SolidErrors.destroy_after = nil
    simulate_99_old_exceptions(:resolved)

    assert_difference -> { SolidErrors::Error.count }, +1 do
      assert_difference -> { SolidErrors::Occurrence.count }, +1 do
        Rails.error.report(StandardError.new('oof'))
      end
    end
  end

  test 'destroy old occurrences every 100 insertions if destroy_after is set' do
    SolidErrors.destroy_after = 1.day
    simulate_99_old_exceptions(:resolved)

    assert_difference -> { SolidErrors::Error.count }, 0 do
      assert_difference -> { SolidErrors::Occurrence.count }, 0 do
        Rails.error.report(StandardError.new('oof'))
      end
    end
  end

  test 'not destroy if errors are unresolved' do
    SolidErrors.destroy_after = 1.day
    simulate_99_old_exceptions(:unresolved)

    assert_difference -> { SolidErrors::Error.count }, +1 do
      assert_difference -> { SolidErrors::Occurrence.count }, +1 do
        assert_empty SolidErrors::Error.resolved
        Rails.error.report(StandardError.new('oof'))
      end
    end
  end

  # Email notification configuration tests

  test 'should send email for all occurrences by default (nil milestone_counts)' do
    SolidErrors.email_milestone_counts = nil
    error = create_error

    assert error.occurrences.last.send(:should_send_email?)

    # Create more occurrences and verify each should send email
    2.times { create_occurrence(error) }
    assert error.occurrences.last.send(:should_send_email?)
  end

  test 'should not send email when milestone_counts is empty array' do
    SolidErrors.email_milestone_counts = []
    error = create_error

    assert_not error.occurrences.last.send(:should_send_email?)
  end

  test 'should send email only at milestone counts' do
    SolidErrors.email_milestone_counts = [1, 10, 100]
    error = create_error

    # First occurrence should send
    assert error.occurrences.last.send(:milestone_reached?)
    assert error.occurrences.last.send(:should_send_email?)

    # 2nd-9th occurrences should not send
    8.times do
      occurrence = create_occurrence(error)
      assert_not occurrence.send(:milestone_reached?)
      assert_not occurrence.send(:should_send_email?)
    end

    # 10th occurrence should send
    tenth_occurrence = create_occurrence(error)
    assert tenth_occurrence.send(:milestone_reached?)
    assert tenth_occurrence.send(:should_send_email?)
  end

  test 'should send email when rate threshold is exceeded' do
    SolidErrors.email_milestone_counts = [] # Disable milestone emails
    SolidErrors.email_rate_threshold_count = 5
    SolidErrors.email_rate_threshold_window = 300 # 5 minutes

    error = create_error
    # Create 4 more occurrences within the window (total 5)
    4.times { create_occurrence(error) }

    # The 5th occurrence should trigger rate threshold
    fifth_occurrence = error.occurrences.last
    assert_equal 5, error.occurrences.where(created_at: 300.seconds.ago...).count
    assert fifth_occurrence.send(:rate_threshold_exceeded?)
    assert fifth_occurrence.send(:should_send_email?)

    # 6th occurrence should not trigger (we've already hit the threshold)
    sixth_occurrence = create_occurrence(error)
    assert_not sixth_occurrence.send(:rate_threshold_exceeded?)
  end

  test 'should not trigger rate threshold when occurrences are spread out' do
    SolidErrors.email_milestone_counts = [] # Disable milestone emails
    SolidErrors.email_rate_threshold_count = 3
    SolidErrors.email_rate_threshold_window = 300 # 5 minutes

    error = create_error
    # Move the initial occurrence outside the window
    error.occurrences.last.update!(created_at: 10.minutes.ago)

    # Create 1 more occurrence outside the window
    occurrence = create_occurrence(error)
    occurrence.update!(created_at: 10.minutes.ago)

    # New occurrence should not trigger rate threshold (only 1 in window)
    new_occurrence = create_occurrence(error)
    assert_equal 1, error.occurrences.where(created_at: 300.seconds.ago...).count
    assert_not new_occurrence.send(:rate_threshold_exceeded?)
  end

  test 'should work with both milestone and rate threshold configured' do
    SolidErrors.email_milestone_counts = [1, 10]
    SolidErrors.email_rate_threshold_count = 5
    SolidErrors.email_rate_threshold_window = 300

    error = create_error

    # First occurrence triggers milestone
    assert error.occurrences.last.send(:should_send_email?)

    # 5th occurrence triggers rate threshold even though not a milestone
    4.times { create_occurrence(error) }
    fifth_occurrence = error.occurrences.last
    assert fifth_occurrence.send(:should_send_email?)
  end

  private

  def simulate_99_old_exceptions(status)
    Rails.error.report(StandardError.new('argh'))
    SolidErrors::Error.update_all(resolved_at: Time.current) if status == :resolved
    SolidErrors::Occurrence.last.update!(id: 99, created_at: 1.day.ago)
  end

  def create_error
    Rails.error.report(StandardError.new('test error'))
    SolidErrors::Error.last
  end

  def create_occurrence(error)
    error.occurrences.create!
  end
end
