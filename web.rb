require 'bundler'
require 'sinatra'
require 'slim'
require 'omniauth'
require 'omniauth-twitter'
require 'uri'
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
  use Rack::Session::Cookie,
    :key => 'rack.session',
    :path => '/',
    :expire_after => 2592000,
    :secret => ENV["SESSION_SECRET"]
  use OmniAuth::Builder do
    provider :twitter, ENV["API_KEY"], ENV["API_SECRET"]
  end
end

get '/' do
  if session[:logged_in]
    me = Bot.first(:user_id => session[:user_id])
    @bots = [me]
    Management.all(:master => me).each do |m|
      @bots << m.slave
    end
  else
    @bots = []
  end
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

post '/bot/:id/add_master' do
  bot = Bot.get(params[:id])
  master = Bot.first(:screen_name => params[:screen_name])
  bot.masters << master
  bot.save
  redirect "/bot/#{bot.id}", 302
end

post '/bot/:id/del_master' do
  bot = Bot.get(params[:id])
  master = Bot.get(params[:master_id])
  bot.masters.delete(master)
  bot.save
  redirect "/bot/#{bot.id}", 302
end

get "/auth/:provider/callback" do
  auth = request.env["omniauth.auth"]
  bot = Bot.first(:user_id => auth[:uid].to_i)
  if bot.nil?
    bot = Bot.create(
      :user_id => auth[:uid].to_i,
      :full_name => auth[:info][:name],
      :screen_name => auth[:info][:nickname],
      :token => auth[:credentials][:token],
      :secret => auth[:credentials][:secret])
  end
  session[:user_id] = bot.user_id
  session[:logged_in] = true
  redirect "/bot/#{bot.id}", 302
end

before do
  uri = URI(request.url)
  if uri.path =~ /^\/bot\/(\d+)/
    bot_id = $1.to_i
    if session[:logged_in]
      bot = Bot.get(bot_id)
      me = Bot.first(:user_id => session[:user_id])
      if bot.id != me.id and Management.first(:master => me, :slave => bot).nil?
        redirect "/", 302
      end
    else
      redirect "/", 302
    end
  end
end

