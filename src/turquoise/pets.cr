require "json"
require "http/client"

module Turquoise
  module Pets
    abstract class Images
      macro endpoint(url)
        def self.request(path = nil, **kargs) : String
          params = URI::Params.encode(kargs)
          "{{url.id}}/v1/images#{path}?#{params}"
        end
      end

      def self.random_with_breed(**kargs)
        options = {has_breeds: "1"}.merge(kargs)
        image = random(**options)
        response = HTTP::Client.get request("/#{image.id}", **options)

        Image.from_json(response.body)
      end

      def self.random(**kargs)
        response = HTTP::Client.get request("/search", **kargs)

        Array(Image).from_json(response.body).first
      end

      def self.parse(string : String)
        puts {{@type.subclasses.map(&.id)}}
        {% begin %}
        case "turquoise::pets::#{string.camelcase.downcase}::images"
        {% for member in @type.subclasses %}
          when {{member.stringify.camelcase.downcase}}
            {{member}}
        {% end %}
        else
          raise ArgumentError.new("Unknown pet: #{string}")
        end
      {% end %}
      end

      struct Image
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

    class Cat::Images < Images
      endpoint "https://api.thecatapi.com"
    end

    class Dog::Images < Images
      endpoint "https://api.thedogapi.com"
    end
  end
end
