require 'singleton'
require 'forwardable'
require 'delayed_job'

class Skype
  extend Forwardable
  def_delegators :@api, :invoke, :on_notification, :notify, :thread, :attach, :attached?
  NAME = 'Dialer'
  include Singleton
  
  def initialize
      @api = Rype::Api.instance
      init_callbacks
      @api.attach NAME   
      log "Attached Skype #{NAME}"
  end
  

  def queue_phone_number phone_number
#    if  Delayed::Worker.count > 0
      log  "Put #{phone_number} to queue"
      Delayed::Job.enqueue CallJob.new(phone_number)
#    else
#      log "Synchronous call #{phone_number}"
#    end

  end
  
  def call phone_number
      raise "Multiple calls isn't allowed. Current call is #{current_call}" if current_call != nil
      @current_call = phone_number 
      @api.invoke("CALL #{phone_number}")
  end

  def hangup call_id
    @api.invoke "SET CALL #{call_id} STATUS FINISHED"
    @current_call = nil
  end

  def current_call
     @current_call
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
   @current_call != nil
  end

 private
  def log message
    if Delayed::Worker.logger != nil
      Delayed::Worker.logger.info message
    else
      puts message 
    end
  end

  def init_callbacks   
    @api.on_notification("CALL (.*) STATUS INPROGRESS") do |call_id|
      log "In progress #{call_id}"
      self.hangup call_id
    end
    @api.on_notification("CALL (.*) STATUS ONHOLD") do |call_id|
      log "In progress #{call_id}"
      self.hangup call_id
    end
    @api.on_notification("APPLICATION #{NAME} CONNECTING (\.*)") do |users|
      log "Connecting  #{users.to_s}"
       @connecting_block.call(users.split(" ")) if @connecting_block != nil && users != nil 
    end
    @api.on_notification("CALL (\.*) STATUS FAILED") do |call_id|
      log "Failed  #{call_id}"
       self.hangup call_id
    end

    #CALL 3604 STATUS FAILED
   end
  
end

class CallJob < Struct.new(:phone_number)
  def perform 
   Skype.instance.call phone_number;
  end
end

