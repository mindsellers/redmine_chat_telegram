require 'timeout'
module RedmineChatTelegram
  def self.table_name_prefix
    'redmine_chat_telegram_'
  end

  def self.bot_token
    Setting.plugin_redmine_chat_telegram['bot_token']
  end

  def self.set_locale
    I18n.locale = Setting['default_language']
  end

  def self.issue_url(issue_id)
    url = Addressable::URI.parse("#{Setting['protocol']}://#{Setting['host_name']}/issues/#{issue_id}")
    url.to_s
  end

  def self.bot_initialize
    extend TelegramCommon::Tdlib::DependencyProviders::GetMe
    extend TelegramCommon::Tdlib::DependencyProviders::AddBot
  
    token = Setting.plugin_redmine_chat_telegram['bot_token']
    self_info = get_me.call

    unless self_info['@type'] == 'user'
      fail 'Please, set correct settings for plugin TelegramCommon'
    end

    robot_id = self_info['id']

    bot      = Telegram::Bot::Client.new(token)
    bot_info = bot.api.get_me['result']
    bot_name = bot_info['username']

    until bot_name.present?
      sleep 60

      bot      = Telegram::Bot::Client.new(token)
      bot_info = bot.api.get_me['result']
      bot_name = bot_info['username']
    end

    add_bot.(bot_info['id'])

    plugin_settings = Setting.find_by(name: 'plugin_redmine_chat_telegram')

    plugin_settings_hash             = plugin_settings.value
    plugin_settings_hash['bot_name'] = bot_name
    plugin_settings_hash['bot_id']   = bot_info['id']
    plugin_settings_hash['robot_id'] = robot_id
    plugin_settings.value            = plugin_settings_hash

    plugin_settings.save

    bot
  end

  def self.handle_message(message)
    RedmineChatTelegram::Bot.new(message).call if message.is_a?(Telegram::Bot::Types::Message)

    group = RedmineChatTelegram::TelegramGroup.find_by(telegram_id: message.chat.id)

    if group.present?
      telegram_message = TelegramMessage.find_or_initialize_by(telegram_id: message.message_id)

      sent_at = Time.at message.date
      from = message.from
      from_id = from.id
      from_first_name = from.first_name
      from_last_name = from.last_name
      from_username = from.username
      message_text =
        if message.text
          message.text
        elsif message.new_chat_members
          'joined'
        elsif message.left_chat_member
          'left_chat'
        elsif message.group_chat_created
          'chat_was_created'
        else
          'Unknown action'
        end

      telegram_message.issue_id = group.issue.id
      telegram_message.sent_at = sent_at
      telegram_message.from_id = from_id
      telegram_message.from_first_name = from_first_name
      telegram_message.from_last_name = from_last_name
      telegram_message.from_username = from_username
      telegram_message.message = message_text

      telegram_message.save!
    end
  end
end
