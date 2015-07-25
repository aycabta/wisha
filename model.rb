require 'bundler'
require 'dm-core'
require 'dm-migrations'
require 'twitter'
require 'tempfile'
require 'net/http'

class Bot
  include DataMapper::Resource
  property :id, Serial
  property :user_id, Decimal, :required => true
  property :full_name, String, :length => 256, :required => true
  property :screen_name, String, :length => 256, :required => true
  property :token, String, :length => 256, :required => true
  property :secret, String, :length => 256, :required => true
  property :interval_minutes, Integer, :default => 0, :required => true
  property :last_tweeted_at, DateTime
  has n, :managements, :child_key => [ :slave_id ]
  has n, :masters, self, :through => :managements, :via => :master
  has n, :tweets

  def init_client
    if @client.nil?
      @client = Twitter::REST::Client.new do |config|
        config.consumer_key        = ENV["API_KEY"]
        config.consumer_secret     = ENV["API_SECRET"]
        config.access_token        = self.token
        config.access_token_secret = self.secret
      end
    end
  end

  def get_io_from_url(url)
    begin
      response = Net::HTTP.get_response(URI(url))
      if response.code == "200"
        temp = Tempfile.new('No')
        temp.write(response.body)
        temp.seek(0)
        temp.to_io
      else
        nil
      end
    rescue StandardError => e
      nil
    end
  end

  def tweet_random
    begin
      if not self.tweets.empty?
        tweet = self.tweets.sample
        if tweet.text =~ %r{(https?://.+\.(?:gif|png|jpg|jpeg))$}i
          media = get_io_from_url($1)
          if not media.nil?
            @client.update_with_media(tweet.text.sub(%r{ *https?://.+\.(?:gif|png|jpg|jpeg)$}i, ''), media)
          else
            @client.update(tweet.text)
          end
        else
          @client.update(tweet.text)
        end
        true
      else
        nil
      end
    rescue StandardError => e
      puts e.message
      e.backtrace.each do |b|
        puts b
      end
      nil
    end
  end

  def self.tweet_random_all
    now = DateTime.now
    self.all.each do |bot|
      if bot.interval_minutes != 0
        if bot.last_tweeted_at.nil?
          bot.init_client
          if !bot.tweet_random.nil?
            bot.last_tweeted_at = now
            bot.save
          end
        else
          next_time = (bot.last_tweeted_at.to_time + bot.interval_minutes * 60).to_datetime
          if now > next_time
            bot.init_client
            if !bot.tweet_random.nil?
              bot.last_tweeted_at = now
              bot.save
            end
          end
        end
      end
    end
  end
end

class Management
  include DataMapper::Resource
  belongs_to :master, 'Bot', :key => true
  belongs_to :slave, 'Bot', :key => true
end

class Tweet
  include DataMapper::Resource
  property :id, Serial
  property :text, String, :length => 2048, :required => true
  belongs_to :bot
end

DataMapper.finalize

def database_upgrade!
  Bot.auto_upgrade!
  Tweet.auto_upgrade!
  Management.auto_upgrade!
end

