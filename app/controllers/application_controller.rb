# frozen_string_literal

# app > controllers > application_controller
class ApplicationController < ActionController::Base
  before_action :authenticate_user!
end
