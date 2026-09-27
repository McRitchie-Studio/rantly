require "yaml"

# Rantly has no database. Every user, rant, follow and comment lives in one
# checked-in YAML file (data/sample.yml), loaded once per process and frozen.
# The models (User, Rant, Comment) are plain value objects that ask this class
# for their relations.
class SampleData
  class NotFound < StandardError; end

  DEFAULT_PATH = Rails.root.join("data/sample.yml")
  MIN_RANT_LENGTH = 140
  MAX_TITLE_LENGTH = 50
  SORTS = %w[latest discussed].freeze

  class << self
    def current
      @current ||= load(DEFAULT_PATH)
    end

    def load(path)
      raw = YAML.safe_load_file(path, permitted_classes: [ Date, Time ])
      new(raw)
    end
  end

  attr_reader :users, :rants, :comments, :follows

  def initialize(raw)
    @users = Array(raw["users"]).map { |row| build_user(row) }.freeze
    @rants = Array(raw["rants"]).map { |row| build_rant(row) }.sort_by { |rant| [ -rant.posted_at.to_i, rant.id ] }.freeze
    @comments = Array(raw["comments"]).map { |row| build_comment(row) }.sort_by(&:posted_at).freeze
    @follows = Array(raw["follows"]).map { |row| [ row["follower"].to_s, row["followed"].to_s ] }.freeze

    @users_by_handle = @users.index_by(&:handle).freeze
    @rants_by_id = @rants.index_by(&:id).freeze
    @comments_by_rant = @comments.group_by(&:rant_id).transform_values(&:freeze).freeze
    freeze
  end

  def user!(handle)
    @users_by_handle.fetch(handle.to_s) { raise NotFound, "no user @#{handle}" }
  end

  def rant!(id)
    @rants_by_id.fetch(id.to_s) { raise NotFound, "no rant #{id}" }
  end

  # The feed: every rant, newest first ("latest"), or the ones with the most
  # comments first ("discussed", ties broken newest first).
  def feed(sort = "latest")
    case sort.to_s
    when "discussed" then rants.sort_by { |rant| [ -comments_for(rant.id).size, -rant.posted_at.to_i, rant.id ] }
    else rants
    end
  end

  def rants_by(handle)
    rants.select { |rant| rant.author_handle == handle }
  end

  def comments_for(rant_id)
    @comments_by_rant.fetch(rant_id, [])
  end

  def following(handle)
    follows.filter_map { |follower, followed| @users_by_handle[followed] if follower == handle }
  end

  def followers(handle)
    follows.filter_map { |follower, followed| @users_by_handle[follower] if followed == handle }
  end

  # Users ranked by followers, for the "Loudest ranters" sidebar.
  def loudest(limit = 5)
    users.sort_by { |user| [ -followers(user.handle).size, user.handle ] }.first(limit)
  end

  # Every house rule the file breaks, as sentences. Empty means the sample
  # world is consistent; SampleDataTest asserts that for data/sample.yml.
  def problems
    problems = []
    problems.concat(duplicates(users.map(&:handle), "user handle"))
    problems.concat(duplicates(rants.map(&:id), "rant id"))

    rants.each do |rant|
      problems << "rant #{rant.id} is by unknown user @#{rant.author_handle}" unless @users_by_handle.key?(rant.author_handle)
      problems << "rant #{rant.id} is #{rant.body.length} characters; the floor is #{MIN_RANT_LENGTH}" if rant.body.length < MIN_RANT_LENGTH
      problems << "rant #{rant.id} has no title" if rant.title.blank?
      problems << "rant #{rant.id} title is #{rant.title.length} characters; the ceiling is #{MAX_TITLE_LENGTH}" if rant.title.length > MAX_TITLE_LENGTH
    end

    comments.each do |comment|
      rant = @rants_by_id[comment.rant_id]
      problems << "a comment answers unknown rant #{comment.rant_id}" unless rant
      problems << "a comment on #{comment.rant_id} is by unknown user @#{comment.author_handle}" unless @users_by_handle.key?(comment.author_handle)
      problems << "a comment on #{comment.rant_id} is blank" if comment.body.blank?
      problems << "a comment on #{comment.rant_id} predates the rant" if rant && comment.posted_at < rant.posted_at
    end

    follows.each do |follower, followed|
      [ follower, followed ].each do |handle|
        problems << "a follow names unknown user @#{handle}" unless @users_by_handle.key?(handle)
      end
      problems << "@#{follower} follows themselves" if follower == followed
    end
    problems.concat(duplicates(follows.map { |pair| pair.join(" follows ") }, "follow"))

    problems
  end

  private

  def build_user(row)
    User.new(handle: row["handle"].to_s, name: row["name"].to_s, bio: row["bio"].to_s,
      rant_frequency: row["rant_frequency"].to_s, location: row["location"].to_s,
      joined_on: row["joined_on"], hue: row["hue"].to_i)
  end

  def build_rant(row)
    Rant.new(id: row["id"].to_s, author_handle: row["author"].to_s, title: row["title"].to_s,
      body: row["body"].to_s.strip, posted_at: row["posted_at"])
  end

  def build_comment(row)
    Comment.new(rant_id: row["rant"].to_s, author_handle: row["author"].to_s,
      body: row["body"].to_s.strip, posted_at: row["posted_at"])
  end

  def duplicates(values, label)
    values.tally.select { |_, count| count > 1 }.map { |value, count| "#{label} #{value} appears #{count} times" }
  end
end
