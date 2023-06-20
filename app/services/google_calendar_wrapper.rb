# frozen_string_literal: true

require 'google/api_client/client_secrets'
# app >services > google_calendar_wrapper
class GoogleCalendarWrapper
  def initialize(current_user)
    configure_client(current_user)
  end

  def configure_client(current_user)
    @client = Google::Apis::CalendarV3::CalendarService.new
    return unless current_user.present? && current_user.access_token.present? && current_user.refresh_token.present?

    google_api_creds = Rails.application.credentials.google_api
    secrets = Google::APIClient::ClientSecrets.new({
                                                     'web' => {
                                                       'access_token' => current_user.access_token,
                                                       'refresh_token' => current_user.refresh_token,
                                                       'client_id' => google_api_creds.google_client_id,
                                                       'client_secret' => google_api_creds.google_client_secret
                                                     }
                                                   })
    begin
      @client.authorization = secrets.to_authorization
      @client.authorization.grant_type = 'refresh_token'
      unless current_user.present?
        @client.authorization.refresh!
        current_user.update_attributes(
          access_token: @client.authorization.access_token, refresh_token: @client.authorization.refresh_token,
          expires_at: @client.authorization.expires_at.to_i
        )
      end
    rescue StandardError
      'Your token has been expired. Please login again with google.'
    end
    @client
  end

  def current_users_events(page_token = nil)
    handle_google_api_errors do
      @client.list_events('primary', always_include_email: true, single_events: true, max_results: 9999, page_token: page_token)
    end
  end

  def show_event(event_id)
    handle_google_api_errors do
      @client.get_event('primary', event_id)
    end
  end

  def create_calendar_event(event, opts = {})
    return 'Pass Event Properly' unless event.is_a?(Hash) && (event.key?(:summary) || event.key?(:description) || event.key?(:start_date) || event.key?(:end_date) || event.key?(:attendees))

    event_object = set_event_object(event, opts)
    cal_event = Google::Apis::CalendarV3::Event.new(**event_object)
    handle_google_api_errors do
      @client.insert_event('primary', cal_event, send_updates: 'all', send_notifications: true,
                                                 conference_data_version: 1)
    end
  end

  def cancel_event(event_id)
    handle_google_api_errors do
      @client.delete_event('primary', event_id, send_notifications: true, send_updates: 'all')
    end
  end

  def handle_google_api_errors
    yield
  rescue Google::Apis::ServerError => e
    e.to_s
  rescue Google::Apis::ClientError => e
    e.to_s
  rescue Google::Apis::AuthorizationError => e
    e.to_s
  end

  private

  def set_event_object(event, options)
    event_obj = {
      summary: event[:summary], description: event[:description],
      start: Google::Apis::CalendarV3::EventDateTime.new(date_time: event[:start_date].rfc3339,
                                                         time_zone: 'Asia/Kolkata'),
      end: Google::Apis::CalendarV3::EventDateTime.new(date_time: event[:end_date].rfc3339,
                                                       time_zone: 'Asia/Kolkata') # change according to your requirements
    }
    event_obj = customize_event(event_obj, options) unless options.empty?
    return event_obj unless event[:attendees].present?

    create_attendees(event, event_obj)
    return event_obj unless options[:conference_data].present?

    create_conference_data(options[:conference_data], event_obj)
  end

  def customize_event(event, opts)
    remainders = opts.delete(:remainders) if opts[:remainders]
    event.merge!(opts)
    return event if remainders.nil?

    create_event_remainders(remainders, event)
  end

  def create_event_remainders(remainder_opts, opts)
    over_rides = []
    remainder_opts.each do |method, minutes|
      remainder = Google::Apis::CalendarV3::EventReminder.new(
        reminder_method: method,
        minutes: minutes.to_i
      )
      over_rides << remainder
    end
    remainder_hash = Google::Apis::CalendarV3::Event::Reminders.new(use_default: false, overrides: over_rides)
    opts.merge!(reminders: remainder_hash)
  end

  def create_attendees(event, event_obj)
    attendees_list = []
    event[:attendees].each do |attendee|
      attendees_list << Google::Apis::CalendarV3::EventAttendee.new(
        email: attendee
      )
    end
    event_obj.merge!(attendees: attendees_list)
  end

  def create_conference_data(conf_data, event_obj)
    meeting_data = Google::Apis::CalendarV3::ConferenceData.new(**conf_data)
    event_obj[:conference_data] = meeting_data
    event_obj
  end
end
