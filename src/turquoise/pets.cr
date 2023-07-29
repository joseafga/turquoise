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
        "https://api.thecatapi.com/v1/images/#{path}?#{params}"
      when .dog?
        "https://api.thedogapi.com/v1/images/#{path}?#{params}"
      else
        raise "Unknown pet `#{self}`"
      end
    end

    def random_with_breed(**kargs)
      options = {has_breeds: "1"}.merge(kargs)
      image = random(**options)
      response = HTTP::Client.get api_url(image[:id], **options)

      NamedTuple(id: String, url: String, breeds: Array(NamedTuple(name: String))).from_json(response.body)
    end

    def random(**kargs)
      response = HTTP::Client.get api_url("search", **kargs)

      Array(NamedTuple(id: String, url: String)).from_json(response.body).first
    end
  end
end
