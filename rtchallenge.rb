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

get '/' do
  protected!
  haml :home
end

get '/update_sprint' do
  protected!
  update_current_iteration
  redirect to('/')
end

helpers do

  def protected!
    return if authorized?
    headers['WWW-Authenticate'] = 'Basic realm="Restricted Area"'
    halt 401, "Not authorized\n"
  end

  def authorized?
    @auth ||=  Rack::Auth::Basic::Request.new(request.env)
    @auth.provided? and @auth.basic? and @auth.credentials and @auth.credentials == [ENV['USER'], ENV['USER_PW']]
  end

  def generate_home
    release_tix_html
  end

  def release_tix_html
    colors = { "accepted" => '#9AFE2E',
               "delivered" => '#819FF7',
               "finished" =>'#BDBDBD',
               "started" => '#2E9AFE',
               "unscheduled" => '#F6CED8',
               "unstarted" =>'#F5A9A9'}
    stories = get_release_tickets
    code = " <h1>Sprint #{ENV['RELEASE_LABEL']}</h1>"

    stories.sort_by { |s| s["current_state"] }.each do |story|
      owners = ""
      story["owner_ids"].each do |o|
        owners += "#{Owner.find_by_poid(o).name} | "
      end
      unless owners.empty?
        owners
      else
        owners = '<b>***NO OWNER***</b>'
      end
      pts = story['estimate']
      code += "</br><a href='#{story["url"]}'>#{story["name"]}</a> - #{owners} - <b style='background-color:#{colors[story["current_state"]]};'>#{story["current_state"]}</b> #{'- ' + pts.to_s if pts}</br>"
    end
    code
  end

  def make_call_parsed(url, headers)
    response = RestClient.get url, headers
    JSON.parse(response)
  end

  def get_release_label
    label = ENV['RELEASE_LABEL'] || '2.2017.1'
    {"project_ids" => ENV['PT_PROJECTS'].split(", "), "name" => label }
  end

  def get_release_tickets
    stories = []
    label = get_release_label
    label["project_ids"].each do |id|
      response = make_call_parsed("#{pivotal_url}/projects/#{id}/search?query=label%3A#{label["name"]}+AND+includedone%3Atrue", pivotal_headers)["stories"]
      if response
        stories << response["stories"]
      end
    end
    @stories = stories.flatten
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

  def pivotal_headers
    { 'X-TrackerToken' => ENV['PT_TOKEN'] }
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
        add_label(project, story, ENV['RELEASE_LABEL'])
      end
    end
  end

  def add_label(project, story, label)
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

  def pivotal_url
    "https://www.pivotaltracker.com/services/v5"
  end
end
