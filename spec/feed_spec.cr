require "./spec_helper"

describe Feed do
  xml = <<-XML
  <?xml version='1.0' encoding='UTF-8'?>
  <feed xmlns:yt="http://www.youtube.com/xml/schemas/2015" xmlns="http://www.w3.org/2005/Atom">
  <link rel="hub" href="https://pubsubhubbub.appspot.com"/>
  <link rel="self" href="https://www.youtube.com/xml/feeds/videos.xml?channel_id=SomeChannelId"/>
  <title>YouTube video feed</title>
  <updated>2023-04-25T12:00:12.345678912+00:00</updated>
  <entry>
    <id>yt:video:VideoId1234</id>
    <yt:videoId>VideoId1234</yt:videoId>
    <yt:channelId>SomeChannelId</yt:channelId>
    <title>My video title</title>
    <link rel="alternate" href="https://www.youtube.com/watch?v=VideoId1234"/>
    <author>
      <name>Channel</name>
      <uri>https://www.youtube.com/channel/SomeChannelId</uri>
    </author>
    <published>2023-04-25T12:00:00+00:00</published>
    <updated>2023-04-25T12:00:12.345678912+00:00</updated>
  </entry>
  </feed>
  XML

  it "parse entries of a feed notification" do
    feed = Feed.parse(xml)
    feed.title.should eq "YouTube video feed"
    feed.link["hub"].should eq "https://pubsubhubbub.appspot.com"
    feed.link["self"].should eq "https://www.youtube.com/xml/feeds/videos.xml?channel_id=SomeChannelId"
    feed.updated.should eq (Time.utc 2023, 4, 25, 12, 0, 12, nanosecond: 345678912)

    entry = feed.entries.first
    entry.id.should eq "VideoId1234"
    entry.title.should eq "My video title"
    entry.link.should eq "https://www.youtube.com/watch?v=VideoId1234"
    entry.published.should eq (Time.utc 2023, 4, 25, 12, 0, 0)
    entry.updated.should eq (Time.utc 2023, 4, 25, 12, 0, 12, nanosecond: 345678912)
  end

  it "parse only topic of a feed notification" do
    Feed.parse_topic(xml).should eq "https://www.youtube.com/xml/feeds/videos.xml?channel_id=SomeChannelId"
  end
end
