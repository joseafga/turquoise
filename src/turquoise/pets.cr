require "json"
require "uri/params"

module Turquoise
  enum Pets
    Cat
    Dog

    # Get API URL for each pet
    def api_url(path = nil, **kargs) : String
      params = URI::Params.encode(kargs)

      case self
      when .cat?
        "https://api.thecatapi.com/v1#{path}?#{params}"
      when .dog?
        "https://api.thedogapi.com/v1#{path}?#{params}"
      else
        raise "Unknown pet `#{self}`"
      end
    end

    def random_with_breed(**kargs)
      options = {has_breeds: "1"}.merge(kargs)
      image = random(**options)
      response = HTTP::Client.get api_url("/images/#{image.id}", **options)

      Pet.from_json(response.body)
    end

    def random(**kargs)
      response = HTTP::Client.get api_url("/images/search", **kargs)

      Array(Pet).from_json(response.body).first
    end
  end

  struct Pet
    include JSON::Serializable

    property id : String
    property url : String
    property breeds : Array(NamedTuple(name: String))?

    def breeds_to_list
      breeds.try &.join(", ") do |breed|
        breed[:name]
      end
    end
  end
end
