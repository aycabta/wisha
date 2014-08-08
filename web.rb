require 'bundler'
require 'sinatra'
require 'slim'
require './model'

configure :production do
  DataMapper.setup(:default, ENV["DATABASE_URL"])
  database_upgrade!
end

configure :test, :development do
  DataMapper.setup(:default, "yaml:///tmp/wisha")
  database_upgrade!
end

get '/' do
  @bots = Bot.all
  slim :index
end

get '/bot/:id' do
  @bot = Bot.get(params[:id])
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

set :root, File.dirname(__FILE__)
enable :run

