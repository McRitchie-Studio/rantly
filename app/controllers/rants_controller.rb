class RantsController < ApplicationController
  def index
    @sort = SampleData::SORTS.include?(params[:sort]) ? params[:sort] : "latest"
    @rants = Rant.feed(@sort)
    @loudest = SampleData.current.loudest
  end

  def show
    @rant = Rant.find!(params[:id])
    @author = @rant.author
    @comments = @rant.comments
    @more_from_author = @author.rants.reject { |rant| rant.id == @rant.id }.first(3)
  end
end
