require 'spec_helper'

describe Server do
  it "should be valid with just a name" do
    Server.new.should_not be_valid
    Server.new(name: "my-server").should be_valid
  end

  describe "#ipaddresses" do
    let(:server) { Factory(:server) }

    it "should update with an address as a string" do
      server.ipaddresses = [ Ipaddress.new(address: "192.168.99.99", main: true) ]
      server.save
      server.reload
      server.read_attribute(:ipaddress).should eq 3232260963
      server.ipaddress.should eq "192.168.99.99"
    end

    it "should update with an address as a number between 1 and 32" do
      server.ipaddresses = [ Ipaddress.new(address: "24", main: true) ]
      server.save
      server.reload.should have(1).ipaddresses
      server.ipaddresses.first.address.should eq "255.255.255.0"
      server.read_attribute(:ipaddress).should eq 4294967040
      server.ipaddress.should eq "255.255.255.0"
    end

    it "should leave ip empty if no main ipaddress" do
      server.ipaddresses = [ Ipaddress.new(address: "24", main: true) ]
      server.save
      server.reload.ipaddress.should_not be_nil
      server.ipaddresses = [ Ipaddress.new(address: "24") ]
      server.save
      server.reload.ipaddress.should be_nil
      server.ipaddresses = [ ]
      server.save
      server.reload.ipaddress.should be_nil
    end
  end

  describe "#ci_identifier" do
    it "should automatically generate an ci_identifier" do
      m = MongoServer.create(name: "blah")
      m.ci_identifier.should eq "blah"
      m = MongoServer.create(name: "( bizarr# n@me )")
      m.ci_identifier.should eq "bizarr-n-me"
    end

    it "should prevent from having 2 servers with the same identifier" do
      m1 = MongoServer.create(name: "srv1")
      m2 = MongoServer.new(name: "(srv1)")
      m2.should_not be_valid
      m2.ci_identifier.should eq m1.ci_identifier
      m2.errors.keys.should include(:ci_identifier)
    end
  end

  describe "#find" do
    let(:server) { Factory(:mongo_server) }

    it "should work normally with ids" do
      MongoServer.find(server.id).should eq server
      MongoServer.find(server.id.to_s).should eq server
    end

    it "should work with identifiers too" do
      MongoServer.find(server.ci_identifier).should eq server
    end

    it "should raise an exception if no existing record with this identifier" do
      lambda { MongoServer.find(0) }.should raise_error Mongoid::Errors::DocumentNotFound
      lambda { MongoServer.find("non-existent") }.should raise_error BSON::InvalidObjectId
    end
  end

  describe "scopes" do
    let!(:site1) { Site.create!(name: "eu-west") }
    let!(:site2) { Site.create!(name: "us-east") }
    let!(:rack1) { PhysicalRack.create!(name: "rack-1-eu", site_id: site1.id.to_s) }
    let!(:rack2) { PhysicalRack.create!(name: "rack-2-us", site_id: site2.id.to_s) }
    let!(:maint) { Company.create!(name: "Computer shop", is_maintainer: true) }
    let!(:os)    { OperatingSystem.create!(name: "Linux") }
    let!(:s1)    { MongoServer.create!(name: "srv-app-01", physical_rack_id: rack1.id.to_s,
                                       maintainer_id: maint.id.to_s,
                                       operating_system_id: os.id.to_s) }
    let!(:s2)    { MongoServer.create!(name: "srv-app-02", physical_rack_id: rack2.id.to_s,
                                       virtual: true) }
    let!(:s3)    { MongoServer.create!(name: "srv-db-01", physical_rack_id: rack1.id.to_s,
                                       puppetversion: "0.24.5") }

    it "should filter servers by rack" do
      MongoServer.count.should eq 3
      MongoServer.by_rack(rack1.id.to_s).count.should eq 2
      MongoServer.by_rack(rack2.id.to_s).count.should eq 1
    end

    it "should filter servers by site" do
      MongoServer.count.should eq 3
      MongoServer.by_site(site1.id.to_s).count.should eq 2
      MongoServer.by_site(site2.id.to_s).count.should eq 1
    end

    it "should filter servers by location" do
      MongoServer.by_location("site-#{site1.id}").should eq MongoServer.by_site(site1.id.to_s)
      MongoServer.by_location("site-0").should eq []
      MongoServer.by_location("rack-#{rack1.id}").should eq MongoServer.by_rack(rack1.id.to_s)
      MongoServer.by_location("rack-0").should eq []
    end

    it "should ignore the filter by location if the parameter is invalid" do
      invalid_result = MongoServer.by_location("invalid location")
      invalid_result.should eq MongoServer.scoped
      invalid_result.count.should eq 3
    end

    it "should filter servers by maintainer" do
      MongoServer.by_maintainer(maint.id.to_s).should eq [s1]
    end

    it "should filter servers by system" do
      MongoServer.by_system(os.id.to_s).to_a.should eq [s1]
    end

    it "should filter servers by virtual" do
      MongoServer.by_virtual(1).to_a.should eq [s2]
    end

    it "should return server with puppet installed" do
      MongoServer.by_puppet(1).to_a.should eq [s3]
    end

    describe "#find_or_generate" do
      let!(:server) { MongoServer.create(name: "rake-server") }

      it "should find server by name in priority" do
        srv = MongoServer.find_or_generate("rake-server")
        srv.should eq server
        srv.just_created.should be_false
      end

      it "should find server by ci_identifier if no name corresponds" do
        server.update_attribute(:name, "rake.server")
        server.name.should eq "rake.server"
        server.ci_identifier.should eq "rake-server"
        server = MongoServer.find_or_generate("rake-server")
        server.should eq server
        server.just_created.should be_false
      end

      it "should generate a new server if no match with name and identifier" do
        server = MongoServer.where(name: "rake-server3").first
        server.should be_nil
        lambda { server = MongoServer.find_or_generate("rake-server3") }.should change(MongoServer, :count).by(+1)
        server.should be_persisted
        server.just_created.should be_true
      end
    end
  end

  describe "#stock?" do
    it "should be truthy only if it's in a rack that is marked as stock" do
      server = Factory(:mongo_server)
      rack = Factory(:rack1)
      server.stock?.should be_false
      server.physical_rack = rack
      rack.stock?.should be_false
      server.stock?.should be_false
      rack.status = PhysicalRack::STATUS_STOCK
      rack.stock?.should be_true
      server.stock?.should be_true
    end
  end

  pending ".not_backuped" do
    let!(:server) { Factory(:server) }
    let!(:vm)     { Factory(:virtual) }

    it "should include everything by default" do
      Server.not_backuped.should include(server)
      Server.not_backuped.should include(vm)
    end

    it "should not include active servers which have an associated backup job" do
      Server.not_backuped.should include(server)
      server.backup_jobs << BackupJob.create(hierarchy: "/")
      Server.not_backuped.should_not include(server)
    end

    pending "should not include servers which have a backup_exception" do
      Server.not_backuped.should include(server)
      BackupException.create!(reason: "backuped an other way", servers: [server])
      Server.not_backuped.should_not include(server)
    end

    it "should not include net devices" do
      Server.not_backuped.should include(server)
      server.update_attribute(:network_device, true)
      Server.not_backuped.should_not include(server)
    end

    it "should not include stock servers" do
      Server.not_backuped.should include(server)
      rack = PhysicalRack.create!(name: "rack-1", site_id: Factory(:room).id.to_s, status: PhysicalRack::STATUS_STOCK)
      server.physical_rack = rack
      server.save
      Server.not_backuped.should_not include(server)
    end
  end

  describe "#can_be_managed_with_puppet?" do
    it "should require having an compatible os defined" do
      srv = Factory(:mongo_server)
      srv.operating_system.should be_blank
      srv.can_be_managed_with_puppet?.should be_false
      sys = OperatingSystem.create(name: "Ubuntu 11.10")
      srv.update_attribute(:operating_system_id, sys.id.to_s)
      srv.reload.can_be_managed_with_puppet?.should be_false
      sys.update_attribute(:managed_with_puppet, true)
      srv.reload.can_be_managed_with_puppet?.should be_true
    end
  end

  describe "#application_instances" do
    it "can have many application instance ids" do
      srv = FactoryGirl.create(:mongo_server)
      srv.application_instance_ids.should eq []
      srv.application_instances.should eq []
    end
  end
end
