module ApplicationHelper
  # "Sep 25" this year, "Sep 25, 2025" otherwise; the full timestamp rides in
  # the <time> element's datetime and title.
  def posted_on(time, now: Time.zone.now)
    local = time.in_time_zone
    format = local.year == now.year ? "%b %-d" : "%b %-d, %Y"
    tag.time(local.strftime(format), datetime: local.iso8601, title: local.strftime("%B %-d, %Y at %-l:%M %p %Z"))
  end

  def avatar(user, size: :md)
    tag.span(user.initials, class: "avatar avatar--#{size}", style: "--hue: #{user.hue.to_i}", aria: { hidden: true })
  end

  def rant_paragraphs(rant)
    safe_join(rant.paragraphs.map { |paragraph| tag.p(paragraph) })
  end

  def count_label(count, singular, plural = singular.pluralize)
    "#{number_with_delimiter(count)} #{count == 1 ? singular : plural}"
  end
end
