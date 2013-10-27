require 'capistrano/version'
require 'capistrano-unicorn/version'
if defined?(Capistrano::VERSION) &&
    Gem::Version.new(Capistrano::VERSION).release >= Gem::Version.new('3.0.0')
  load "capistrano-unicorn/tasks/capistrano_integration.rake"
else
  require 'capistrano-unicorn/capistrano_integration'
end
