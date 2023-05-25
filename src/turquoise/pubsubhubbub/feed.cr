require "xml"

module PubSubHubbub
  class Feed
    struct Entry
      struct Author
        property name : String?
        property uri : String?
      end

      property id : String?
      property title : String?
      property link : String?
      property author = Author.new
      property published : Time?
      property updated : Time?
    end

    property title : String?
    property link = Hash(String, String).new
    property updated : Time?
    property entries = [] of Entry
    UPDATED_PATTERN   = "%FT%T.%9N%:z"
    PUBLISHED_PATTERN = "%FT%T%:z"

    private def self.parse_entry(node : XML::Node)
      entry = Entry.new

      node.children.select(&.element?).each do |child|
        case child.name
        when "yt:videoid"
          entry.id = child.content
        when "link"
          entry.link = child["href"]
        when "author"
          child.children.select(&.element?).each do |i|
            case i.name
            when "name"
              entry.author.name = i.content
            when "uri"
              entry.author.uri = i.content
            end
          end
        when "title"
          entry.title = child.content
        when "updated"
          entry.updated = Time.parse!(child.content, UPDATED_PATTERN)
        when "published"
          entry.published = Time.parse!(child.content, PUBLISHED_PATTERN)
        end
      end

      entry
    end

    # Parse full xml feed from YouTube PubSubHubbub
    #
    # ```
    # feed = Feed.parse(
    #   "<?xml version='1.0' encoding='UTF-8'?>
    #   <feed>
    #     <title>Feed Title</title>
    #     ...
    #   </feed>")
    #
    # puts feed.title # => Feed Title
    # ```
    def self.parse(xml : String)
      feed = Feed.new
      doc = XML.parse_html(xml)

      doc.xpath_node("//feed").try do |root|
        root.children.select(&.element?).each do |node|
          case node.name
          when "link"
            feed.link[node["rel"]] = node["href"]
          when "title"
            feed.title = node.content
          when "updated"
            feed.updated = Time.parse!(node.content, UPDATED_PATTERN)
          when "entry"
            feed.entries << parse_entry(node)
          end
        end
      end

      feed
    end

    # Parse only *<link rel="self" ... />* from feed to fast recognize the topic
    def self.parse_topic(xml : String)
      doc = XML.parse_html(xml)
      doc.xpath_node("//feed/link[@rel='self']").try &.["href"]
    end
  end
end
