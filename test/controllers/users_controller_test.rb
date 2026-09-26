require "test_helper"

# Component tier: a profile, with who the user follows and who follows them.
class UsersControllerTest < ActionDispatch::IntegrationTest
  test "a profile shows the user, their rants, following and followers" do
    user = User.find!("deb_from_accounts")
    get user_path(user)
    assert_response :success
    assert_select "title", "Deborah Okafor (@deb_from_accounts) · Rantly"
    assert_select "h1#profile-name", "Deborah Okafor"
    assert_select ".profile__handle", "@deb_from_accounts"
    assert_select ".profile__facts", /Daily/
    assert_select ".profile__facts", /September 2014/
    assert_select ".profile__stats a[href='#rants']", "2 rants"
    assert_select ".profile__stats a[href='#following']", "3 following"
    assert_select ".profile__stats a[href='#followers']", "4 followers"

    assert_select ".feed article.rant-card", 2
    assert_select ".feed .byline__who", 0, "the author is the page; cards drop the byline"

    following = css_select("#following .person__handle").map { |node| node.text.strip }
    assert_equal user.following.map { |u| "@#{u.handle}" }, following
    followers = css_select("#followers .person__handle").map { |node| node.text.strip }
    assert_equal user.followers.map { |u| "@#{u.handle}" }, followers
  end

  test "each followed user links to their own profile" do
    get user_path("deb_from_accounts")
    assert_select "#following a.person[href='/@nullpointer']"
  end

  test "an unknown handle is a 404" do
    get "/@nobody_here"
    assert_response :not_found
  end

  test "a handle with characters no handle can have does not route" do
    get "/@Upper-Case"
    assert_response :not_found
  end
end
