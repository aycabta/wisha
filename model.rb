require 'bundler'
require 'dm-core'
require 'dm-migrations'
require 'twitter'

class Bot
  include DataMapper::Resource
  property :id, Serial
  property :full_name, String, :length => 256, :required => true
  property :screen_name, String, :length => 256, :required => true
  property :token, String, :length => 256, :required => true
  property :secret, String, :length => 256, :required => true
  has n, :tweets

  def init_client
    @client = Twitter::REST::Client.new do |config|
      config.consumer_key        = ENV["API_KEY"]
      config.consumer_secret     = ENV["API_SECRET"]
      config.access_token        = self.token
      config.access_token_secret = self.secret
    end
  end

  def tweet_random
    tweet = self.tweets.sample
    @client.update(tweet.text)
  end
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
end

