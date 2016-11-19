source 'https://rubygems.org'
gem 'twitter', :git => 'git://github.com/aycabta/twitter.git', :branch => 'backport-video-support-from-v6'
gem 'sinatra'
gem 'thin'
gem 'dm-core'
gem 'dm-migrations'
gem 'slim'
gem 'omniauth'
gem 'omniauth-twitter'

group :development, :test do
  gem 'rspec'
  gem 'rack-test'
  gem 'dm-yaml-adapter'
end

group :production do
  gem 'dm-postgres-adapter'
end

ruby '2.3.2'

