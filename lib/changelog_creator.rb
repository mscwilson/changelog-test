require "json"
require "date"
require "net/http"
require "uri"

require_relative "github_api_connection"

class ChangelogCreator
  COMMIT_MESSAGE_PATTERN = /\A([\w\s.,'"-:`@]+) \((?:close|closes|fixes|fix) \#(\d+)\)$/
  RELEASE_BRANCH_PATTERN = %r{release/(\d*\.*\d*\.*\d*\.*)}
  RELEASE_COMMIT_PATTERN = /Prepare for v*\d*\.*\d*\.*\d*\.*\ *release/
  MERGE_COMMIT_PATTERN = /Merge (pull request|branch)/
  EMAIL_PATTERN = /\w+@snowplowanalytics\.com/

  attr_reader :octokit

  def initialize(access_token: ENV["ACCESS_TOKEN"],
                 client: Octokit::Client,
                 repo_name: ENV["GITHUB_REPOSITORY"],
                 api_connection: GithubApiConnection)
    @octokit = api_connection.new(client: client.new(access_token:), repo_name:)
  end

  def prepare_for_release_commit?(message:)
    RELEASE_COMMIT_PATTERN.match?(message)
  end

  def merge_commit?(message:)
    MERGE_COMMIT_PATTERN.match?(message)
  end

  def version_number(branch_name:)
    match = RELEASE_BRANCH_PATTERN.match(branch_name)
    return nil unless match

    version = match[1]
    version.count(".") == 1 ? "#{version}.0" : version
  end

  def relevant_commits(commits:, version:)
    allowed_message = "Prepare for #{version} release"
    commits.take_while do |commit|
      message = commit[:commit][:message]
      message.start_with?(allowed_message) || !prepare_for_release_commit?(message:)
    end
  end

  def useful_commit_data(commits:)
    commits.map { |commit| process_single_commit(commit) }.compact
  end

  def simple_changelog_block(commit_data:, version:)
    title = "#{version} (#{Date.today.strftime('%Y-%m-%d')})"

    commit_data.map! do |commit|
      if commit[:snowplower]
        "#{commit[:message]} (##{commit[:issue]})"
      else
        "#{commit[:message]} (##{commit[:issue]}) - thanks @#{commit[:author]}!"
      end
    end
    "Version #{title}\n-----------------------\n#{commit_data.join("\n")}\n"
  end

  def fancy_changelog(commit_data:)
    commits_by_type = sort_commits_by_type(commit_data)

    features = commits_by_type[:feature].empty? ? "" : "**New features**\n#{commits_by_type[:feature].join("\n")}\n\n"
    bugs = commits_by_type[:bug].empty? ? "" : "**Bug fixes**\n#{commits_by_type[:bug].join("\n")}\n\n"
    admin = commits_by_type[:admin].empty? ? "" : "**Under the hood**\n#{commits_by_type[:admin].join("\n")}\n\n"
    unlabelled = commits_by_type[:misc].empty? ? "" : "**Changes**\n#{commits_by_type[:misc].join("\n")}\n"

    "#{features}#{bugs}#{admin}#{unlabelled}"
  end

  def sort_commits_by_type(commit_data)
    commits_by_type = commit_data.each_with_object(Hash.new([].freeze)) do |i, dict|
      case i[:type]
      when nil
        dict[:misc] += [i]
      when "feature"
        dict[:feature] += [i]
      when "bug"
        dict[:bug] += [i]
      when "admin"
        dict[:admin] += [i]
      end
    end

    commits_by_type.each do |k, _v|
      commits_by_type[k].map! do |commit|
        fancy_log_single_line(commit_data: commit)
      end
    end
  end

  def fancy_log_single_line(commit_data:)
    breaking_change = commit_data[:breaking_change] ? " **BREAKING CHANGE**" : ""
    thanks = commit_data[:snowplower] ? "" : " - thanks @#{commit_data[:author]}!"
    "#{commit_data[:message]} (##{commit_data[:issue]})#{thanks}#{breaking_change}"
  end

  private # ------------------------------

  def process_single_commit(commit)
    message_match = commit[:commit][:message].match(COMMIT_MESSAGE_PATTERN)
    return nil if message_match.nil?

    labels = @octokit.issue_labels(issue: message_match[2])
    label_data = parse_labels(labels:)

    { message: message_match[1],
      issue: message_match[2],
      author: commit[:author][:login],
      snowplower: @octokit.snowplower?(commit[:author][:login]),
      breaking_change: label_data[:breaking_change],
      type: label_data[:type] }
  end

  def parse_labels(labels:)
    result = { type: nil, breaking_change: false }
    if labels.include?("type:enhancement")
      result[:type] = "feature"
    elsif labels.include?("type:defect")
      result[:type] = "bug"
    elsif labels.include?("type:admin")
      result[:type] = "admin"
    end
    result[:breaking_change] = true if labels.include?("category:breaking_change")
    result
  end
end
