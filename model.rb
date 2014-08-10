require 'bundler'
require 'dm-core'
require 'dm-migrations'
require 'twitter'

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

  def tweet_random
    if not self.tweets.empty?
      tweet = self.tweets.sample
      @client.update(tweet.text)
    end
  end

  def self.tweet_random_all
    now = DateTime.now
    self.all.each do |bot|
      if bot.interval_minutes != 0
        if bot.last_tweeted_at.nil?
          bot.init_client
          bot.tweet_random
          bot.last_tweeted_at = now
          bot.save
        else now > (bot.last_tweeted_at.to_time + bot.interval_minutes * 60).to_datetime
          bot.init_client
          bot.tweet_random
          bot.last_tweeted_at = now
          bot.save
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

