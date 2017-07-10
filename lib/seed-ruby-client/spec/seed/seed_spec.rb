require 'spec_helper'
require 'securerandom'
require 'date'

RSpec.describe Seed do
  describe 'version' do
    it 'has a version number' do
      expect(Seed::VERSION).not_to be nil
    end
  end

  describe 'API Status' do
    before :example do
      # @r = Seed::API.new("https://seed-platform.org")
      @r = Seed::API.new('http://localhost:8000')
    end

    # it "should get a status response" do
    #   expect(@r.awake?).to be true
    # end
    #
    # it "should not work when unauthenticated" do
    #   @r.api_key('no.user@nowhere.com', 'bad_key')
    #   expect(@r.awake?).to be false
    # end
    #
    # it "should get or create organization" do
    #   new_org_name = "Ruby Client Test Organization #{SecureRandom.uuid}"
    #   org = @r.get_or_create_organization(new_org_name)
    #   puts org.class
    #   expect(org).to be_a Seed::Organization
    #
    #   org = @r.get_or_create_organization(new_org_name)
    #   expect(org).to be_kind_of Seed::Organization
    #   expect(org.name).to eq new_org_name
    #   expect(org.id).to_not be nil
    # end
    #
    # it "should get a list of cycles" do
    #   @r.get_or_create_organization("Cycle Test #{SecureRandom.uuid}")
    #   @r.cycles
    #   cycles = @r.cycles
    #   expect(cycles.size).to eq 1
    #   expect(cycles.first.name).to eq "Default 2016 Calendar Year"
    #   expect(cycles.first.start).to eq DateTime.parse("2016-01-01T08:00:00Z")
    #   expect(cycles.first.end).to eq DateTime.parse("2017-12-31T08:00:00Z")
    # end
    #
    #
    # it "should create a new cycle" do
    #   @r.get_or_create_organization('Cycle Test')
    #   cycle_name = "Ruby Client Test Cycle #{SecureRandom.uuid}"
    #   cycle_start = DateTime.parse('01-01-2010 01:00:00Z')
    #   cycle_end = DateTime.parse('2010-12-31 23:00:00Z')
    #   cycle = @r.create_cycle(cycle_name, cycle_start, cycle_end)
    #   expect(cycle.name).to eq cycle_name
    #   expect(cycle.start).to eq cycle_start
    #   expect(cycle.end).to eq cycle_end
    # end
    #
    # it "should return existing cycle" do
    #   @r.get_or_create_organization('Cycle Test')
    #   cycle = @r.cycle("Default 2016 Calendar Year")
    #   expect(cycle.name).to eq "Default 2016 Calendar Year"
    # end

    it 'should not find buildingsync file' do
      @r.get_or_create_organization('Cycle Test')
      @r.create_cycle('models 01', DateTime.parse('2010-01-01'), DateTime.parse('2010-12-31'))
      filename = File.expand_path('../files/not_a_real_file.xml', File.dirname(__FILE__))
      file = @r.upload_buildingsync(filename)
      expect(file).to eq false
    end

    it 'should upload a buildingsync file' do
      @r.get_or_create_organization('Cycle Test')
      @r.create_cycle('models 01', DateTime.parse('2010-01-01'), DateTime.parse('2010-12-31'))

      expect(@r.cycle_obj.name).to eq 'models 01'

      filename = File.expand_path('../files/buildingsync_ex01.xml', File.dirname(__FILE__))
      file = @r.upload_buildingsync(filename)
      puts file
    end
  end
end
