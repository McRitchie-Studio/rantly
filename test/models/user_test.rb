require "test_helper"

class UserTest < ActiveSupport::TestCase
  test "initials take the first letter of up to two words" do
    assert_equal "DO", User.find!("deb_from_accounts").initials
    assert_equal "RH", User.find!("rantly").initials
  end

  test "to_param is the handle, so user_path reads /@handle" do
    assert_equal "/@gatelice", Rails.application.routes.url_helpers.user_path(User.find!("gatelice"))
  end

  test "a user's rants are theirs alone, newest first" do
    rants = User.find!("gatelice").rants
    assert_equal 3, rants.size
    assert rants.all? { |rant| rant.author_handle == "gatelice" }
    assert_equal rants.map(&:posted_at).sort.reverse, rants.map(&:posted_at)
  end
end
