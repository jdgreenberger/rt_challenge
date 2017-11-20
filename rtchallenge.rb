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
require 'haml'
require 'stylus'
require './lib/pivotal_api'

get '/' do
  protected!
  Stylus.compile(File.new('public/css/index.styl'))
  haml :home
end

get '/update_sprint' do
  protected!
  update_current_iteration
  redirect to('/')
end

helpers do
  def pivotal_api
    @release_label = ENV['RELEASE_LABEL'] || '2.2017.1'
    @pivotal_api ||= PivotalApi.new(ENV['PT_TOKEN'], @release_label)
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

  def get_story_owners(ids)
    ids.map do |id|
      Owner.find_by_poid(id).name
    end.join(' | ') or 'NO OWNER'
  end

  def make_call_parsed(url, headers)
    response = RestClient.get url, headers
    JSON.parse(response)
  end

  def get_project_ids
    ENV['PT_PROJECTS'].split(", ")
  end

  def get_release_tickets
    @stories = get_project_ids
      .map {|id| pivotal_api.get_project_stories(id) }
      .flatten.sort_by { |s| s["current_state"] }
  end

  def update_users
    ENV['PT_PROJECTS'].split(", ").each do |id|
      ownersDatum = make_call_parsed("#{pivotal_url}/projects/#{id}/memberships", pivotal_headers)
      ownersDatum.each do |ownerData|
        unless Owner.find_by_poid(ownerData["person"]["id"])
          Owner.create( poid: ownerData["person"]["id"],
                        initials: ownerData["person"]["initials"],
                        name: ownerData["person"]["name"])
        end
      end
    end
  end

  def update_current_iteration
    update_users
    headers = pivotal_headers
    projects = ENV['PT_PROJECTS'].split(", ")
    projects.each do |project|
      url = "#{pivotal_url}/projects/#{project}/iterations?scope=current"
      response = make_call_parsed(url, headers)
      stories = response.last["stories"]
      stories.each do |story|
        add_label(project, story, @release_label)
      end
    end
  end

  def add_label(project, story, label)
    p project, story, label
    return if label_present?(project, story, label)
    headers = pivotal_headers
    url = "#{pivotal_url}/projects/#{project}/stories/#{story["id"]}/labels"
    body = {name: label}
    RestClient.post url, body, headers
  end

  def label_present?(project, story, label)
    headers = pivotal_headers
    url = "#{pivotal_url}/projects/#{project}/stories/#{story["id"]}/labels"
    labels = make_call_parsed(url, headers)
    labels.each do |l|
      if l["name"] == label
        return true
      end
    end
    false
  end
end
