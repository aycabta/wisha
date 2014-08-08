require 'bundler'
require 'sinatra'
require 'slim'
require 'omniauth'
require 'omniauth-twitter'
require './model'

configure :production do
  DataMapper.setup(:default, ENV["DATABASE_URL"])
  database_upgrade!
end

configure :test, :development do
  DataMapper.setup(:default, "yaml:///tmp/wisha")
  database_upgrade!
end

configure do
  set :root, File.dirname(__FILE__)
  enable :run
  enable :sessions
  use OmniAuth::Builder do
    provider :twitter, ENV["API_KEY"], ENV["API_SECRET"]
  end
end

get '/' do
  @bots = Bot.all
  slim :index
end

get '/bot/:id' do
  @bot = Bot.get(params[:id])
  @masters = @bot.masters
  logger.info @masters
  slim :bot
end

get '/bot/:id/tweet' do
  bot = Bot.get(params[:id])
  bot.init_client
  bot.tweet_random
  redirect "/bot/#{bot.id}", 302
end

post '/bot/:id/del_tweet' do
  bot = Bot.get(params[:id])
  tweet = Tweet.first(:bot => bot, :id => params[:tweet_id])
  tweet.destroy
  redirect "/bot/#{bot.id}", 302
end

post '/bot/:id/add_tweet' do
  bot = Bot.get(params[:id])
  Tweet.create(:bot => bot, :text => params[:text])
  redirect "/bot/#{bot.id}", 302
end

post '/bot/:id/add_master' do
  bot = Bot.get(params[:id])
  master = Bot.first(:screen_name => params[:screen_name])
  bot.masters << master
  logger.info bot.masters
  bot.save
  redirect "/bot/#{bot.id}", 302
end

get "/auth/:provider/callback" do
  auth = request.env["omniauth.auth"]
  bot = Bot.create(
    :user_id => auth[:uid].to_i,
    :full_name => auth[:info][:name],
    :screen_name => auth[:info][:nickname],
    :token => auth[:credentials][:token],
    :secret => auth[:credentials][:secret])
  redirect "/bot/#{bot.id}", 302
end

