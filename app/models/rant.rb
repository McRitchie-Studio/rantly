# A long-form post: at least 140 characters, the opposite of a tweet.
class Rant < Data.define(:id, :author_handle, :title, :body, :posted_at)
  WORDS_PER_MINUTE = 200
  TWEET_LENGTH = 140 # the 2014 limit Rantly was built to out-rant
  EXCERPT_LENGTH = 280

  def self.find!(id) = SampleData.current.rant!(id)
  def self.feed(sort = "latest") = SampleData.current.feed(sort)

  def to_param = id
  def author = SampleData.current.user!(author_handle)
  def comments = SampleData.current.comments_for(id)

  def paragraphs
    body.split(/\n{2,}/).map(&:strip).reject(&:empty?)
  end

  # The opening of the rant, cut at a word boundary, for the feed card.
  def excerpt(length = EXCERPT_LENGTH)
    first = paragraphs.first.to_s
    first.length <= length ? first : first.truncate(length, separator: " ", omission: "…")
  end

  def truncated?(length = EXCERPT_LENGTH)
    paragraphs.size > 1 || paragraphs.first.to_s.length > length
  end

  def word_count = body.split.size
  def reading_minutes = [ (word_count / WORDS_PER_MINUTE.to_f).ceil, 1 ].max

  # How many 2014 tweets it would take to say this.
  def tweets_worth = (body.length / TWEET_LENGTH.to_f).ceil
end
