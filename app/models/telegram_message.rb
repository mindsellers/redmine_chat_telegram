class TelegramMessage < ActiveRecord::Base
  unloadable

  include Redmine::I18n

  COLORS_NUMBER = 8

  def self.as_text
    all.map(&:as_text).join("\n\n")
  end

  def as_text(with_time: true)
    if with_time
      format_time(sent_at) + ' ' + author_name + ': ' + message
    else
      author_name + ': ' + message
    end
  end

  def author_name
    full_name = [from_first_name, from_last_name].join(' ')
    full_name.present? ? full_name : from_username
  end

  def author_initials
    if from_first_name && from_last_name
      [from_first_name.first, from_last_name.first].join
    else
      from_username[0..1]
    end
  end

  def user_id
    from_id
  end

end
