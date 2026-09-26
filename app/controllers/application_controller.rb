class ApplicationController < ActionController::Base
  # No allow_browser gate: a public showcase should render for any visitor, and
  # a browser without import maps simply gets the page without the demo
  # composer's counter.

  # Changes to the importmap will invalidate the etag for HTML responses
  stale_when_importmap_changes

  # A handle or rant that is not in the sample file is a plain 404, logged with
  # what was asked for so a broken link leaves a trail.
  rescue_from SampleData::NotFound do |error|
    Rails.logger.info("[rantly] 404 #{request.path}: #{error.message}")
    render file: Rails.public_path.join("404.html"), status: :not_found, layout: false, content_type: "text/html"
  end
end
