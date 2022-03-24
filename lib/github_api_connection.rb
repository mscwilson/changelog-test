require "octokit"
require "json"

class GithubApiConnection

  def initialize
    @client = Octokit::Client.new(access_token: ENV["ACCESS_TOKEN"])
  end

  def pr_opened?(client = @client)
    events = client.repository_events(ENV["GITHUB_REPOSITORY"])
    parsed_events = JSON.parse(events)
    return nil if parsed_events[0]["type"] != "PullRequestEvent"
    return nil if parsed_events[0]["payload"]["action"] != "opened"

    head_ref = parsed_events[0]["payload"]["pull_request"]["head"]["ref"]
    base_ref = parsed_events[0]["payload"]["pull_request"]["base"]["ref"]
    { head_ref: head_ref, base_ref: base_ref }
  end

end

# client = Octokit::Client.new(access_token: ENV["ACCESS_TOKEN"])

# events = client.repository_events(ENV["GITHUB_REPOSITORY"])

# List events for a repo
# #repository_events(repo, options = {})

# if a PR was just created, most recent event has the details??

# probably one of these methods to add the file
# #create_commit(repo, message, tree, parents = nil, options = {})
# #update_contents(repo, path, message, sha, content = nil, options = {})

