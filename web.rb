require 'bundler'
require 'sinatra'
require 'slim'
require 'omniauth'
require 'omniauth-twitter'
require 'uri'
require './model'

configure :production do
  DataMapper.setup(:default, ENV['DATABASE_URL'])
  database_upgrade!
end

configure :test, :development do
  DataMapper.setup(:default, 'yaml:///tmp/wisha')
  database_upgrade!
end

configure do
  set :root, File.dirname(__FILE__)
  set :static, true
  set :public_folder, "#{File.dirname(__FILE__)}/public"
  enable :run
  enable :sessions
  set :session_secret, ENV['SESSION_SECRET']
  use Rack::Session::Cookie,
    :key => 'rack.session',
    :path => '/',
    :expire_after => 60 * 60 * 24 * 90,
    :secret => ENV['SESSION_SECRET']
  use OmniAuth::Builder do
    provider :twitter, ENV['API_KEY'], ENV['API_SECRET']
  end
end

def redirect_to_top
  redirect '/', 302
end

def redirect_to_bot(bot)
  redirect "/bot/#{bot.id}", 302
end

get '/' do
  if session[:logged_in]
    @me = Bot.first(:user_id => session[:user_id])
    @bots = []
    Management.all(:master => @me).each do |m|
      @bots << m.slave
    end
  else
    @bots = []
  end
  slim :index
end

post '/logout' do
  session.clear
  redirect_to_top
end

get '/bot/:id' do
  @bot = Bot.get(params[:id])
  @title = "#{@bot.full_name} (@#{@bot.screen_name})"
  slim :bot
end

post '/bot/:id/tweet' do
  bot = Bot.get(params[:id])
  bot.init_client
  bot.tweet_random
  redirect_to_bot(bot)
end

post '/bot/:id/del_tweet' do
  bot = Bot.get(params[:id])
  tweet = Tweet.first(:bot => bot, :id => params[:tweet_id])
  tweet.destroy
  redirect_to_bot(bot)
end

post '/bot/:id/add_tweet' do
  bot = Bot.get(params[:id])
  Tweet.create(:bot => bot, :text => params[:text])
  redirect_to_bot(bot)
end

post '/bot/:id/add_master' do
  bot = Bot.get(params[:id])
  master = Bot.first(:screen_name => params[:screen_name])
  bot.masters << master
  bot.save
  redirect_to_bot(bot)
end

post '/bot/:id/del_master' do
  bot = Bot.get(params[:id])
  master = Bot.get(params[:master_id])
  bot.masters.delete(master)
  bot.save
  redirect_to_bot(bot)
end

get '/auth/:provider/callback' do
  auth = request.env['omniauth.auth']
  bot = Bot.first(:user_id => auth[:uid].to_i)
  if not bot.nil?
    bot.update(
      :full_name => auth[:info][:name],
      :screen_name => auth[:info][:nickname],
      :token => auth[:credentials][:token],
      :secret => auth[:credentials][:secret],
      :is_valid => true)
  else
    bot = Bot.create(
      :user_id => auth[:uid].to_i,
      :full_name => auth[:info][:name],
      :screen_name => auth[:info][:nickname],
      :token => auth[:credentials][:token],
      :secret => auth[:credentials][:secret])
  end
  session[:user_id] = bot.user_id
  session[:logged_in] = true
  redirect_to_top
end

post '/bot/:id/set_interval' do
  if params[:minutes] =~ /^\d+$/
    bot = Bot.get(params[:id])
    bot.interval_minutes = params[:minutes]
    bot.save
  end
  redirect_to_bot(bot)
end

get '/goose' do
  Bot.tweet_random_all
end

before do
  uri = URI(request.url)
  if uri.path =~ /^\/bot\/(\d+)/
    bot_id = $1.to_i
    if session[:logged_in]
      bot = Bot.get(bot_id)
      me = Bot.first(:user_id => session[:user_id])
      if bot.id != me.id and Management.first(:master => me, :slave => bot).nil?
        redirect_to_top
      end
    else
      redirect_to_top
    end
  end
end
