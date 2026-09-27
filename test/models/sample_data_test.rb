require "test_helper"
require "tempfile"

# Unit tier: the sample world in data/sample.yml, and the rules it must keep.
class SampleDataTest < ActiveSupport::TestCase
  def data = SampleData.current

  test "the checked-in sample world breaks none of the house rules" do
    assert_equal [], data.problems
  end

  test "it has enough people, rants and conversation to browse" do
    assert_operator data.users.size, :>=, 6
    assert_operator data.rants.size, :>=, 10
    assert_operator data.comments.size, :>=, 20
    assert_operator data.follows.size, :>=, 15
    assert data.rants.any? { |rant| rant.comments.empty? }, "keep one quiet rant so the empty state is exercised"
  end

  test "every rant clears the 140-character floor and the 50-character title ceiling" do
    data.rants.each do |rant|
      assert_operator rant.body.length, :>=, SampleData::MIN_RANT_LENGTH, rant.id
      assert_operator rant.title.length, :<=, SampleData::MAX_TITLE_LENGTH, rant.id
    end
  end

  test "the feed is newest first, and discussed puts the most comments first" do
    latest = data.feed("latest")
    assert_equal latest.map(&:posted_at).sort.reverse, latest.map(&:posted_at)

    discussed = data.feed("discussed")
    counts = discussed.map { |rant| rant.comments.size }
    assert_equal counts.sort.reverse, counts
    assert_equal latest.map(&:id).sort, discussed.map(&:id).sort
  end

  test "an unknown sort falls back to latest" do
    assert_equal data.feed("latest"), data.feed("hottest")
  end

  test "comments on a rant come oldest first" do
    comments = Rant.find!("reply-all-is-not-a-personality").comments
    assert_equal 4, comments.size
    assert_equal comments.map(&:posted_at).sort, comments.map(&:posted_at)
    assert_equal "nullpointer", comments.first.author_handle
  end

  test "following and followers read the same edges from both ends" do
    data.users.each do |user|
      user.following.each { |followed| assert_includes followed.followers, user }
    end
    assert_equal %w[rantly nullpointer quietcarriage], User.find!("deb_from_accounts").following.map(&:handle)
    assert_equal %w[soup_season quietcarriage nullpointer rantly], User.find!("deb_from_accounts").followers.map(&:handle)
  end

  test "loudest ranks by follower count" do
    counts = data.loudest.map { |user| user.followers.size }
    assert_equal counts.sort.reverse, counts
    assert_equal "rantly", data.loudest.first.handle
  end

  test "unknown handles and rant ids raise NotFound" do
    assert_raises(SampleData::NotFound) { User.find!("nobody") }
    assert_raises(SampleData::NotFound) { Rant.find!("no-such-rant") }
  end

  test "the loaded world is frozen, so a request cannot change it for the next one" do
    assert_predicate data, :frozen?
    assert_predicate data.rants, :frozen?
    assert_raises(FrozenError) { data.users << data.users.first }
  end

  test "problems names every broken rule in a bad file" do
    bad = SampleData.load(write_yaml(<<~YAML))
      users:
        - { handle: amy, name: Amy A, joined_on: 2020-01-01 }
        - { handle: amy, name: Amy Again, joined_on: 2020-01-01 }
      follows:
        - { follower: amy, followed: amy }
        - { follower: amy, followed: ghost }
      rants:
        - id: short
          author: amy
          title: "#{"x" * 51}"
          posted_at: 2026-09-20T10:00:00-06:00
          body: Too short to be a rant.
        - id: orphan
          author: ghost
          title: Fine
          posted_at: 2026-09-20T10:00:00-06:00
          body: "#{"y" * 140}"
      comments:
        - { rant: short, author: amy, posted_at: 2026-09-19T10:00:00-06:00, body: Early }
        - { rant: missing, author: ghost, posted_at: 2026-09-21T10:00:00-06:00, body: Lost }
    YAML

    problems = bad.problems
    assert_includes problems, "user handle amy appears 2 times"
    assert_includes problems, "rant short is 23 characters; the floor is 140"
    assert_includes problems, "rant short title is 51 characters; the ceiling is 50"
    assert_includes problems, "rant orphan is by unknown user @ghost"
    assert_includes problems, "a comment on short predates the rant"
    assert_includes problems, "a comment answers unknown rant missing"
    assert_includes problems, "a comment on missing is by unknown user @ghost"
    assert_includes problems, "@amy follows themselves"
    assert_includes problems, "a follow names unknown user @ghost"
    assert_equal 9, problems.size, problems.inspect
  end

  private

  def write_yaml(text)
    file = Tempfile.new([ "sample", ".yml" ])
    file.write(text)
    file.close
    file.path
  end
end
