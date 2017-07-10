module Seed
  class Cycle
    # @param hash, form of
    # {
    #     "end": "2017-12-31T08:00:00Z",
    #     "name": "Default 2016 Calendar Year",
    #     "start": "2016-01-01T08:00:00Z",
    #     "organization": 1,
    #     "id": 2
    # }
    def self.from_hash(hash)
      cycle = Cycle.new
      vars_to_parse = [:name, :start, :end, :id]

      hash.each do |name, value|
        if vars_to_parse.include? name
          cycle.instance_variable_set("@#{name}", value)
          cycle.class.__send__(:attr_accessor, name)
        end
      end

      # convert some attributes to ruby DateTime
      cycle.start = DateTime.parse(cycle.start) unless defined?(cycle.start).nil?
      cycle.end = DateTime.parse(cycle.end) unless defined?(cycle.end).nil?

      cycle
    end
  end
end
