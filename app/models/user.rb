# A sample ranter. Read-only: Rantly has no accounts, so users come from
# data/sample.yml through SampleData.
class User < Data.define(:handle, :name, :bio, :rant_frequency, :location, :joined_on, :hue)
  def self.find!(handle) = SampleData.current.user!(handle)
  def self.all = SampleData.current.users

  def to_param = handle
  def rants = SampleData.current.rants_by(handle)
  def following = SampleData.current.following(handle)
  def followers = SampleData.current.followers(handle)

  # Up to two letters for the avatar: "Deborah Okafor" -> "DO", "Rantly HQ" -> "RH".
  def initials
    name.split.first(2).map { |word| word[0] }.join.upcase
  end
end
