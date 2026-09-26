# A reply to exactly one rant. Comments have no 140-character floor.
class Comment < Data.define(:rant_id, :author_handle, :body, :posted_at)
  def author = SampleData.current.user!(author_handle)
end
