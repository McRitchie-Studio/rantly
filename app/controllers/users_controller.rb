class UsersController < ApplicationController
  def show
    @user = User.find!(params[:handle])
    @rants = @user.rants
    @following = @user.following
    @followers = @user.followers
  end
end
