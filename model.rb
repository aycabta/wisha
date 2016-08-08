require 'bundler'
require 'dm-core'
require 'dm-migrations'
require 'twitter'
require 'tempfile'
require 'net/http'

class Bot
  include DataMapper::Resource
  property :id, Serial
  property :user_id, Decimal, :precision => 20, :required => true
  property :full_name, String, :length => 256, :required => true
  property :screen_name, String, :length => 256, :required => true
  property :is_valid, Boolean, :default => true, :required => true
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
    if self.is_valid and not self.tweets.empty?
      tweet = self.tweets.sample
      if tweet.text =~ %r{(https?://.+\.(?:gif|png|jpg|jpeg|mp4))$}i
        media = get_io_from_url($1)
        if not media.nil?
          @client.update_with_media(tweet.text.sub(%r{ *https?://.+\.(?:gif|png|jpg|jpeg|mp4)$}i, ''), media)
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
  rescue Twitter::Error::Unauthorized => e
    self.is_valid = false
    self.save
    nil
  rescue StandardError => e
    # Codes are here:
    # https://dev.twitter.com/overview/api/response-codes
    # http://www.rubydoc.info/gems/twitter/Twitter/Error/Code
    case e.code
    when Twitter::Error::Code::SUSPENDED_ACCOUNT
      self.is_valid = false
      self.save
    when Twitter::Error::Code::INVALID_OR_EXPIRED_TOKEN
      self.is_valid = false
      self.save
    else
      puts "ERROR!: #{user_id} #{screen_name} #{tweet.nil? ? '' : tweet.text}"
      puts e.message
      e.backtrace.each do |b|
        puts b
      end
    end
    nil
  end

  def self.tweet_random_all
    now = DateTime.now
    self.all(:conditions => [ '(SELECT COUNT(id) FROM tweets WHERE bot_id = bots.id) > 0' ]).each do |bot|
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
              bot.last_tweeted_at = next_time
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

