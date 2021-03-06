module RedmineChatTelegram
  class GroupChatCreator
    include TelegramCommon::Tdlib::DependencyProviders::CreateChat
    include TelegramCommon::Tdlib::DependencyProviders::GetChatLink

    attr_reader :issue, :user

    def initialize(issue, user)
      @issue = issue
      @user = user
    end

    def run
      subject  = "#{issue.project.name} #{issue.id}"

      bot_id = Setting.plugin_redmine_telegram_common['bot_id']

      result = create_chat.(subject, [bot_id])

      chat_id = result['id']

      result = get_chat_link.(chat_id)

      telegram_id = chat_id
      telegram_chat_url = result['invite_link']

      if issue.telegram_group.present?
        issue.telegram_group.update telegram_id: telegram_id,
                                    shared_url:  telegram_chat_url
      else
        issue.create_telegram_group telegram_id: telegram_id,
                                    shared_url:  telegram_chat_url
      end

      journal_text = I18n.t('redmine_chat_telegram.journal.chat_was_created',
                            telegram_chat_url: telegram_chat_url)

      begin
        issue.init_journal(user, journal_text)
        issue.save
      rescue ActiveRecord::StaleObjectError
        issue.reload
        retry
      end
    end
  end
end
