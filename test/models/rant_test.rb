require "test_helper"

class RantTest < ActiveSupport::TestCase
  def rant(body, title: "A title")
    Rant.new(id: "x", author_handle: "rantly", title: title, body: body, posted_at: Time.zone.parse("2026-09-20 10:00"))
  end

  test "paragraphs split on blank lines and drop empties" do
    assert_equal [ "One.", "Two." ], rant("One.\n\n\nTwo.\n\n").paragraphs
  end

  test "excerpt keeps a short first paragraph whole" do
    subject = rant("Short opening.\n\nSecond paragraph.")
    assert_equal "Short opening.", subject.excerpt
    assert_predicate subject, :truncated?
  end

  test "excerpt cuts a long first paragraph at a word boundary" do
    subject = rant(([ "word" ] * 100).join(" "))
    assert_operator subject.excerpt.length, :<=, Rant::EXCERPT_LENGTH
    assert subject.excerpt.end_with?("word…"), subject.excerpt
    assert_predicate subject, :truncated?
  end

  test "a single short paragraph is not truncated" do
    refute_predicate rant("x " * 80), :truncated?
  end

  test "tweets' worth counts 140-character tweets, rounding up" do
    assert_equal 1, rant("a" * 140).tweets_worth
    assert_equal 2, rant("a" * 141).tweets_worth
    assert_equal 5, rant("a" * 700).tweets_worth
  end

  test "reading time is at least a minute at 200 words a minute" do
    assert_equal 1, rant("word " * 30).reading_minutes
    assert_equal 2, rant("word " * 201).reading_minutes
  end

  test "to_param is the id, so rant_path reads /rants/<id>" do
    assert_equal "x", rant("a" * 140).to_param
  end
end
