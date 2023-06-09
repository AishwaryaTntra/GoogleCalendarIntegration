# frozen_stribg_literal: true

# app > controllers > events_controller
class EventsController < ApplicationController
  def index
    result = GoogleCalendarWrapper.new(current_user).current_users_events
    handle_authentication_error(result)
    if result.is_a?(String)
      flash.now[:alert] = "Please try again. There seems to be a #{result} error."
    else
      @events = result.to_h[:items]
      @events.uniq! { |event| event[:summary] }
    end
  end

  def show
    selected_event = GoogleCalendarWrapper.new(current_user).show_event(params[:id])
    handle_authentication_error(selected_event)
    if selected_event.is_a?(String)
      redirect_to events_path
      flash.now[:alert] = "Please try again. There seems to be a #{selected_event} error."
    else
      @event = selected_event.to_h
    end
  end

  def new
    @event = Event.new
  end

  def edit; end

  def create
    options = {
      "location": 'Tntra Vadodara',
      "remainders": {
        "email": '20',
        "popup": '10'
      },
      "guests_can_modify": false,
      "guests_can_invite_others": false,
      "guests_can_see_other_guests": false,
      "recurrence": [
        'RRULE:FREQ=DAILY;INTERVAL=1;COUNT=1'
      ],
      "visibility": 'default',
      "send_updates": "all",
      "send_notifications": true,
      "conference_data": {
        "create_request": {
          "conference_solution_key": {
            "type": "hangoutsMeet"
          },
          "request_id": SecureRandom.alphanumeric
          # "request_id": ""
        }
      }
    }
    event = { summary: event_params[:title],
              description: event_params[:description],
              start_date: event_start_date,
              end_date: event_end_date,
              attendees: event_params[:members].split(',').map(&:strip) }
    response = GoogleCalendarWrapper.new(current_user).create_calendar_event(event, options)
    handle_authentication_error(response)
    respond_to do |format|
      if response.instance_of?(::Google::Apis::CalendarV3::Event)
        format.html { redirect_to event_url(response.to_h[:id]), notice: 'Event was successfully created.' }
        format.json { render :show, status: :created, location: @event }
      elsif response == '"Pass Event Properly"'
        format.html do
          render :new, status: :unprocessable_entity 
          flash.now[:alert] = 'Please pass necessary details for creating an event'
        end
      else
        format.html do
          render :new, status: :unprocessable_entity 
          flash.now[:alert] = "Please try again. There seems to be a #{result} error."
        end
        format.json { render json: @event.errors, status: :unprocessable_entity }
      end
    end
  end

  def update
    respond_to do |format|
      if @event.update(event_params)
        format.html { redirect_to event_url(@event), notice: 'Event was successfully updated.' }
        format.json { render :show, status: :ok, location: @event }
      else
        format.html { render :edit, status: :unprocessable_entity }
        format.json { render json: @event.errors, status: :unprocessable_entity }
      end
    end
  end

  def destroy
    response = GoogleCalendarWrapper.new(current_user).cancel_event(params[:id])
    handle_authentication_error(response)
    if response == ''
      respond_to do |format|
        format.html { redirect_to events_url, notice: 'Event was successfully destroyed.' }
        format.json { head :no_content }
      end
    else
      respond_to do |format|
        format.html do
          redirect_to events_url, status: :unprocessable_entity
          flash.now[:alert] = "Please try again. There seems to be a #{result} error."
        end
        return
      end
    end
  end

  private

  def event_params
    params.fetch(:event, {})
  end

  def event_start_date
    Time.new(event_params['start_date(1i)'].to_i, event_params['start_date(2i)'].to_i,
             event_params['start_date(3i)'].to_i, event_params['start_date(4i)'].to_i,
             event_params['start_date(5i)'].to_i, '00'.to_i, '+05:30')
  end

  def event_end_date
    Time.new(event_params['end_date(1i)'].to_i, event_params['end_date(2i)'].to_i,
             event_params['end_date(3i)'].to_i, event_params['end_date(4i)'].to_i,
             event_params['end_date(5i)'].to_i, '00'.to_i, '+05:30')
  end

  def handle_authentication_error(result)
    return unless result == 'Unauthorized'

    sign_out(current_user)
    authenticate_user!
  end
end
