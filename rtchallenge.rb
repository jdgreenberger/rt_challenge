# bundle exec irb -I. -r rtchallenge.rb
require 'dotenv/load'
require 'sinatra'
require 'json'
require 'rest-client'
require 'pry'
require 'rb-readline'
require 'sinatra/activerecord'
require './config/environments'
require './models/owner'
require './lib/pivotal_api'
require 'haml'
require 'stylus'
require 'stylus/tilt'

get '/css/*' do
  stylus :index
end

get '/' do
  haml :home
end

get '/filter/*' do
  haml :home
end

get '/update_sprint' do
  protected!
  update_users
  update_project_labels
  redirect to('/')
end

helpers do
  def valid_states
    ['Accepted', 'Delivered', 'Finished', 'Started', 'Unscheduled', 'Unstarted']
  end

  def pivotal_api
    @pivotal_api ||= PivotalApi.new(ENV['PT_TOKEN'], ENV['RELEASE_LABEL'] || '2.2017.1')
    @pivotal_api
  end

  def protected!
    return if authorized?
    headers['WWW-Authenticate'] = 'Basic realm="Restricted Area"'
    halt 401, "Not authorized\n"
  end

  def authorized?
    @auth ||=  Rack::Auth::Basic::Request.new(request.env)
    @auth.provided? and @auth.basic? and @auth.credentials and @auth.credentials == [ENV['USER'], ENV['USER_PW']]
  end

  def get_filter_val_from_params(params)
    return nil if not params["splat"] or params["splat"].empty? or not valid_states.include? params["splat"].first
    params["splat"].first.downcase
  end

  def get_story_owners(ids)
    owners = ids.map do |id|
      Owner.find_by_poid(id).name
    end.join(' and ')
    owners == '' ? 'No Owner' : owners
  end

  def get_project_ids
    ENV['PT_PROJECTS'].split(", ")
  end

  def get_release_tickets
    filter_val = get_filter_val_from_params(params)
    p filter_val
    stories = get_project_ids.map {|id| pivotal_api.get_project_stories(id) }.flatten
    if filter_val
      @stories = stories.select do |s|
        s["current_state"].downcase == filter_val
      end
    else
      @stories = stories.sort_by { |s| s["current_state"] }
    end
  end

  def update_users
    get_project_ids.each do |id|
      ownersDatum = pivotal_api.get_project_owners(id)
      ownersDatum.each do |ownerData|
        unless Owner.find_by_poid(ownerData["person"]["id"])
          Owner.create( poid: ownerData["person"]["id"],
                        initials: ownerData["person"]["initials"],
                        name: ownerData["person"]["name"])
        end
      end
    end
  end

  def update_project_labels
    get_project_ids.each do |id|
      pivotal_api.get_project_stories(id).each do |story|
        pivotal_api.add_label_to_project(id, story)
      end
    end
  end
end
