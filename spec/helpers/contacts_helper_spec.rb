require 'spec_helper'

describe ContactsHelper do
  describe "#full_position" do
    it "returns the full job position of a person" do
      person = FactoryGirl.create(:contact)
      full_position(person).should eq "CEO, WorldCompany"
      person.company = nil
      full_position(person).should eq "CEO"
      person.company = Company.new(name: "Blah Inc.")
      person.job_position = ""
      full_position(person).should eq "Blah Inc."
    end

    it "returns a linkified version of the company" do
      person = FactoryGirl.create(:contact)
      full_position(person, true).should match %r(CEO, <a href=".*">WorldCompany</a>)
      person.company = nil
      full_position(person, true).should eq "CEO"
      person.company = Company.new(name: "Blah Inc.")
      person.job_position = ""
      full_position(person, true).should match %r(^<a href=".*">Blah Inc.</a>)
    end
  end
end
