require 'json'
require 'rest-client'

class PivotalApi

  attr_reader :token, :label

  def initialize(token, label)
    @token = token
    @label = label
  end

  def fetch_and_parse(url, headers)
    response = RestClient.get url, headers
    JSON.parse(response)
  end

  def get_project_stories(project_id)
    response = self.fetch_and_parse(
      "#{pivotal_url}/projects/#{project_id}/search?query=label%3A#{@label}+AND+includedone%3Atrue",
      pivotal_headers
    )["stories"]
    response ? response["stories"] : nil
  end

  def pivotal_headers
    { 'X-TrackerToken' => @token }
  end

  def pivotal_url
    "https://www.pivotaltracker.com/services/v5"
  end

  def update_users
    ENV['PT_PROJECTS'].split(", ").each do |id|
      ownersDatum = fetch_and_parse("#{pivotal_url}/projects/#{id}/memberships", pivotal_headers)
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
      response = fetch_and_parse(url, headers)
      stories = response.last["stories"]
      stories.each do |story|
        add_label(project, story, get_release_label)
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
    labels = fetch_and_parse(url, headers)
    labels.each do |l|
      if l["name"] == label
        return true
      end
    end
    false
  end
end
