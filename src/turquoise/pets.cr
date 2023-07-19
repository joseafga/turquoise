require "uri/params"

module Turquoise
  module Pets
    abstract class Pet
      # Returns pet image url. Requires `API_URL` constant defined
      def self.random(**kargs) : String
        options = {format: "src"}.merge(kargs) # `src` will redirect straight to the image
        params = URI::Params.encode(options)

        {% begin %}
        "#{{{ @type }}::API_URL}?#{params}"
        {% end %}
      end
    end

    class Cat < Pet
      API_URL = "https://api.thecatapi.com/v1/images/search"
    end

    class Dog < Pet
      API_URL = "https://api.thedogapi.com/v1/images/search"
    end
  end
end
