module Seed
  class Organization
    # @param hash, form of
    #   {
    #     "is_parent": true,
    #     "user_role": "owner",
    #     "sub_orgs": [],
    #     "number_of_users": 1,
    #     "id": 6,
    #     "owners": [
    #       {
    #         "first_name": "",
    #         "last_name": "",
    #         "email": "nicholas.long@nrel.gov",
    #         "id": 1
    #       }
    #     ],
    #     "name": "test_organization",
    #     "created": "2017-07-05",
    #     "org_id": 6,
    #     "user_is_owner": true,
    #     "parent_id": 6,
    #     "cycles": [
    #       {
    #         "num_taxlots": 0,
    #         "cycle_id": 7,
    #         "num_properties": 0,
    #         "name": "Default 2016 Calendar Year"
    #       }
    #     ]
    #   }
    #
    def self.from_hash(hash)
      org = Organization.new
      vars_to_parse = [:id, :name, :user_is_owner, :cycles]

      hash.each do |name, value|
        if vars_to_parse.include? name
          if name == :cycles
            # parse the cycles as objects too someday
            org.instance_variable_set("@#{name}", value)
            org.class.__send__(:attr_accessor, name)
          else
            org.instance_variable_set("@#{name}", value)
            org.class.__send__(:attr_accessor, name)
          end
        end
      end

      org
    end
  end
end
