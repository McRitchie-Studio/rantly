class ApplicationController < ActionController::Base
  # No allow_browser gate: a public showcase should render for any visitor, and
  # a browser without import maps simply gets the page without the demo
  # composer's counter.

  # Changes to the importmap will invalidate the etag for HTML responses
  stale_when_importmap_changes

  # A handle or rant that is not in the sample file raises SampleData::NotFound.
  # Nothing here rescues it: config/application.rb maps it to 404, so it reaches
  # the same not-found page as an unknown address.
end
