module PubSubHubbub
  class_getter config = Configuration.new

  # Customize default settings using block.
  #
  # ```
  # PubSubHubbub.configure do |config|
  #   config.host = "https://example.com"
  #   config.path = "/some/path"
  # end
  # ```
  def self.configure(&block) : Nil
    yield config
  end

  class Configuration
    property endpoint : String
    property host : String
    property path : String

    def initialize
      @endpoint = "https://pubsubhubbub.appspot.com/subscribe"
      @host = "https://127.0.0.1"
      @path = "/"
    end

    # Hub callback URL.
    def callback
      File.join(@host, @path)
    end
  end
end
