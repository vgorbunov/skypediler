require 'skype'
class DialController < ApplicationController
  def index
    number = normalize params[:number]
    Skype::Skype.instance.queue_phone_number(number)
  end
  def normalize number
    number = number.to_s
    raise "Empty phone number" if number.length == 0
    if number[0] != "+" && !number.start_with?("00") && /^\d*$/ === number
      number = '+' + number
    end
    number
  end
end
