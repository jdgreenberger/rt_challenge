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

  def post(url, body, headers)
    RestClient.post url, body, headers
  end

  def get_project_stories(project_id)
    response = fetch_and_parse(
      "#{pivotal_url}/projects/#{project_id}/search?query=label%3A#{@label}+AND+includedone%3Atrue",
      pivotal_headers
    )["stories"]
    response ? response["stories"] : nil
  end

  def get_project_owners(project_id)
    fetch_and_parse("#{pivotal_url}/projects/#{project_id}/memberships", pivotal_headers)
  end

  def get_current_stories(project_id)
    response = fetch_and_parse("#{pivotal_url}/projects/#{project_id}/iterations?scope=current", pivotal_headers)
    response.last["stories"]
  end

  def add_label_to_project(project_id, story)
    return if label_present?(project_id, story)
    post("#{pivotal_url}/projects/#{project_id}/stories/#{story["id"]}/labels", {name: @label}, pivotal_headers)
  end

  def label_present?(project_id, story)
    labels = fetch_and_parse("#{pivotal_url}/projects/#{project_id}/stories/#{story["id"]}/labels", pivotal_headers)
    not labels.none? {|l| l["name"] == @label}
  end

  def pivotal_headers
    { 'X-TrackerToken' => @token }
  end

  def pivotal_url
    "https://www.pivotaltracker.com/services/v5"
  end
end
