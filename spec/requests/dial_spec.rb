require 'spec_helper'
describe "dial page" do
  it "diplays put call in queue" do

    get "/dial/echo123"
    assert_select "h1", :text => "call is queued"
  end
end
