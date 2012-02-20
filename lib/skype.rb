
require 'singleton'
require 'forwardable'
require 'delayed_job'
module Skype
  
class Skype
  extend Forwardable
  def_delegators :@api, :invoke, :on_notification, :notify, :thread, :attach, :attached?
  NAME = 'Dialer'
  TIMEOUT = 180
  include Singleton
  
  def initialize
      @api = Rype::Api.instance
      init_callbacks
      @api.attach NAME
      @mutex = Mutex.new
      log "Attached Skype #{NAME}"
      Thread.new do 
         while true
           if @current_call_time != nil && Time.now - current_call_time > TIMEOUT
             log "Force reset call #{current_call}"
             force_cleanup_call
           end
           sleep(0.5)
         end
      end
  end
  

  def queue_phone_number phone_number
      log  "Put #{phone_number} to queue"
      Delayed::Job.enqueue CallSkypeJob.new(phone_number)
  end
  
  def call phone_number
       return if !valid? phone_number
      @mutex.synchronize do
        raise "Multiple calls isn't allowed. Current call is #{current_call}" if current_call != nil
        @current_call_time = Time.now
        @current_call = phone_number 
        @can_redial = false
        @current_call_id = nil
        @api.invoke("CALL #{phone_number}")
      end
  end

  def hangup call_id = @current_call_id
    @api.invoke "SET CALL #{call_id} STATUS FINISHED" if call_id != nil
  end

  def force_cleanup_call
      hangup
      reset_call
  end
  def current_call
     @current_call
  end
  
  def calling?
    @current_call != nil
  end
  
  def connections &block 
    if block_given?
      @connectiins_block = block
      @api.invoke " GET APPLICATION #{NAME} CONNECTING"
    else
      log "No block found for 'connections' request" 
      @connections_block = nil
    end
  end

  def calling?
   current_call != nil
  end

  def reset_call
    @current_call = nil
    @current_call_time = nil
  end
  def wait_for_call timeout = 30
      while timeout > 0 && calling?
        sleep(0.2)
        timeout -= 0.2
     end
  end
 private
  
  def log message
    Rails::logger.info message
  end 
  
  def valid? phone_number
    /^\+\d{10,15}$|^00\d{10,15}$|^[a-zA-Z](\w|\.|-)*$/.match(phone_number) != nil  
  end
  
  def init_callbacks   
    @api.on_notification("CALL (.*) STATUS INPROGRESS") do |call_id|
      log "In progress #{call_id}"
      self.hangup call_id
    end
    
    @api.on_notification("CALL (.*) STATUS ROUTING") do |call_id|
      log "Routing #{call_id}"
      @current_call_id = call_id
    end
    
    @api.on_notification("CALL (.*) STATUS RINGING") do |call_id|
      log "Ringing #{call_id}"
      @current_call_id = call_id
    end
    
    @api.on_notification("CALL (.*) STATUS EARLYMEDIA") do |call_id|
      log "Early media #{call_id}"
      @current_call_id = call_id
    end
    
    @api.on_notification("CALL (.*) STATUS ONHOLD") do |call_id|
      log "On hold #{call_id}"
      self.hangup call_id
    end

    @api.on_notification("CALL (.*) STATUS BUSY") do |call_id|
      log "Busy #{call_id}"
      @can_redial = true
      self.hangup call_id
    end

     @api.on_notification("CALL (.*) STATUS REFUSED") do |call_id|
      log "Refused #{call_id}"
      self.reset_call
    end

     @api.on_notification("CALL (.*) STATUS CANCELED") do |call_id|
      log "Canceled #{call_id}"
      self.reset_call
    end

    @api.on_notification("CALL (.*) STATUS UNPLACED") do |call_id|
      log "Unplaced #{call_id}"
      self.reset_call
    end

    @api.on_notification("CALL (.*) STATUS MISSED") do |call_id|
      log "Missed #{call_id}"
      self.hangup reset_call
    end

    @api.on_notification("CALL (.*) STATUS FINISHED") do |call_id|
      log "Finished #{call_id}"
      self.reset_call
    end

    @api.on_notification("APPLICATION #{NAME} CONNECTING (\.*)") do |users|
      log "Connecting  #{users.to_s}"
       @connecting_block.call(users.split(" ")) if @connecting_block != nil && users != nil 
    end

    @api.on_notification("CALL (\.*) STATUS FAILED") do |call_id|
      log "Failed  #{call_id}"
       self.hangup
    end

    @api.on_notification("(\.*)") do |response|
      log "Last Skype incoming #{response}"
    end
   end
end

class CallSkypeJob < Struct.new(:phone_number)
  TIMEOUT = 60
  def perform
    Rails::logger.info "Perform call job for #{phone_number}"
    Skype.instance.call phone_number;
    if Skype.instance.wait_for_call TIMEOUT
       #TODO put this call into queue again 
    end 
    if Skype.instance.calling? 
      Rails.logger.info "Timeout. Force hangup #{phone_number}"
      Skype.instance.force_cleanup_call
      
    else
      Rails.logger.info "Call finished"
    end
  end
end
end
