require 'spec_helper'
require 'delayed/worker'
require 'delayed_job'
describe "Test Call jobs" do
  before(:each) do
  end

  it "should be available initialized Skype" do
    skype = Skype.instance
    skype.should_not == nil
    skype.current_call.should == nil 
    skype.call "echo123"
    skype.current_call.should eq("echo123")
    while skype.current_call != nil
      puts "Pending..."
      sleep 0.2
    end   
  end
  it "should be possible invoke connections" do
    skype = Skype.instance
    skype.should_not == nil
    skype.current_call.should == nil
    skype.connections do |connections|
    end  
  end

  it "shouldn't allow multiple skype calls" do
    skype = Skype.instance
    skype.should_not == nil
    skype.current_call.should == nil
    skype.call "echo123"
    lambda {skype.call "echo1234" }.should raise_error
    skype.current_call.should eq("echo123")
    while skype.current_call != nil
      puts "Pending..."
      sleep 0.2
    end
  end

  it "should put job to queue" do
    skype = Skype.instance
    skype.should_not == nil
    skype.current_call.should == nil
    current = Delayed::Job.count
    skype.queue_phone_number "echo123"
    Delayed::Job.count.should eq(current + 1)
    skype.current_call.should == nil
  end
end
