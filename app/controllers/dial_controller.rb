require 'skype'
class DialController < ApplicationController
  def index
    Skype.instance.queue_phone_number(params[:number])
  end
end
