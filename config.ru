require 'sass/plugin/rack'
require './rtchallenge'

Sass::Plugin.options[:style] = :compressed
use Sass::Plugin::Rack

run Sinatra::Application
