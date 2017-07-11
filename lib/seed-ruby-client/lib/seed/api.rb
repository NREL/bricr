module Seed
  # API class to work with SEED Platform
  class API
    attr_reader :cycle_obj

    def initialize(host, version='v2')
      @host = "#{host}/api/#{version}"
      @api_header = nil

      # read the username and api key from env vars (if set)
      if ENV['BRICR_SEED_USERNAME'] && ENV['BRICR_SEED_API_KEY']
        api_key(ENV['BRICR_SEED_USERNAME'], ENV['BRICR_SEED_API_KEY'])
      end

      # query the API to get the user id
      @user_id = get_user_id
      unless @user_id
        raise Exception('Could not authenticate SEED API or find user ID')
      end

      @organization = nil
      @cycle_obj = nil
      @cache = {}
    end

    # Set the API key for server
    def api_key(username, key)
      # auth_string = base64.urlsafe_b64encode(
      #     '{}:{}'.format(username.lower(), api_key)
      # )
      # auth_string = 'Basic {}'.format(auth_string)
      # header = {
      #     'Authorization': auth_string,
      #     "Content-Type": "application/json"
      # }

      @api_header = "Basic #{Base64.strict_encode64("#{username}:#{key}")}"
    end

    def get_user_id
      response = RestClient.get("#{@host}/users/current_user_id/", authorization: @api_header)
      if response.code == 200
        return JSON.parse(response, symbolize_names: true)[:pk]
      elsif response.code == 500
        return "ERROR getting current_user_id"
      end
    end


    def awake?
      response = RestClient.get("#{@host}/version/", authorization: @api_header)
      if response.code == 200
        return true
      else
        return false
      end
    rescue Exception => e
      puts "Could not authenticate the user with message '#{e}'"
      return false
    end

    def get_or_create_organization(name)
      # check if the organization exists
      response = RestClient.get("#{@host}/organizations/", authorization: @api_header)
      if response.code == 200
        response = JSON.parse(response, symbolize_names: true)
      else
        return false
      end

      response[:organizations].each do |org|
        if org[:name] == name
          @organization = Organization.from_hash(org)
          return @organization
        end
      end

      # no organization found, create a new one
      body = {
        organization_name: name,
        user_id: @user_id
      }
      response = RestClient.post("#{@host}/organizations/", body, authorization: @api_header)
      if response.code == 200 # this should be a 201, seed needs fixed
        response = JSON.parse(response, symbolize_names: true)
        @organization = Organization.from_hash(response[:organization])
        return @organization
      else
        return false
      end
    end

    def cycles(bypass_cache=false)
      if @cache[:cycles] && !bypass_cache
        return @cache[:cycles]
      end

      @cache[:cycles] = []
      response = RestClient.get(
        "#{@host}/cycles/?organization_id=#{@organization.id}",
        authorization: @api_header
      )
      if response.code == 200
        cycles = []
        response = JSON.parse(response, symbolize_names: true)
        response[:cycles].each do |cycle|
          cycles << Cycle.from_hash(cycle)
        end
        @cache[:cycles] = cycles
      else
        return false
      end
    end

    # create a new cycle from name, start_time, and end_time
    # check if the cycle already exists and if so then return the existing cycle (only looks at name!)
    def create_cycle(name, start_time, end_time)
      # return if cycle already exists
      test_cycle = cycle(name)
      if test_cycle
        return test_cycle
      end

      body = {
        name: name,
        start: start_time.strftime('%Y-%m-%d %H:%MZ'),
        end: end_time.strftime('%Y-%m-%d %H:%MZ')
      }
      response = RestClient.post("#{@host}/cycles/?organization_id=#{@organization.id}",
                                 body,
                                 authorization: @api_header)
      if response.code == 201
        response = JSON.parse(response, symbolize_names: true)
        c = Cycle.from_hash(response[:cycles])
        return c
      else
        return false
      end
    end

    # set the cycle
    def cycle(name)
      if @cache[:cycles].nil? || @cache[:cycles].empty?
        cycles
      end

      @cycle_obj = nil
      @cache[:cycles].each do |cycle|
        if name == cycle.name
          @cycle_obj = cycle
          return cycle
        end
      end

      false
    end

    # upload a buildingsync file
    def upload_buildingsync(filename)
      if File.exist? filename
        payload = {
          organization_id: @organization.id,
          cycle_id: @cycle_obj.id,
          file_type: 1,
          multipart: true
        }
        response = RestClient.post("#{@host}/building_file/",
                                   payload.merge(file: File.new(filename, 'rb')),
                                   authorization: @api_header)

        if response.code == 200
          response = JSON.parse(response, symbolize_names: true)
          return response
        else
          return false
        end
      else
        return false
      end
    end
  end
end
