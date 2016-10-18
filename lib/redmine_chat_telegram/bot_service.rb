module RedmineChatTelegram
  class BotService

    attr_reader :bot, :logger, :command, :issue, :message

    def initialize(command, bot = nil)
      @bot     = bot.present? ? bot : Telegrammer::Bot.new(RedmineChatTelegram.bot_token)
      @logger  = Logger.new(STDOUT)
      @command = command
      @issue   = find_issue

      if Rails.env.production?
        @logger = Logger.new(Rails.root.join('log/redmine_chat_telegram', 'bot.log'))
      else
        @logger = Logger.new(STDOUT)
      end
    end

    def call
      return unless can_execute_command?

      RedmineChatTelegram.set_locale
      @message = init_message

      execute_command
    end

    def group_chat_created
      issue_url = RedmineChatTelegram.issue_url(issue.id)
      bot.send_message(
        chat_id: command.chat.id,
        text: I18n.t('redmine_chat_telegram.messages.hello', issue_url: issue_url),
        disable_web_page_preview: true)

      message.message = 'chat_was_created'
      message.save!
    end

    def new_chat_participant
      new_chat_participant = command.new_chat_participant

      if command.from.id == new_chat_participant.id
        message.message = 'joined'
      else
       message.message     = 'invited'
       message.system_data = chat_user_full_name(new_chat_participant)
      end

      message.save!
    end

    def left_chat_participant
      left_chat_participant = command.left_chat_participant

      if command.from.id == left_chat_participant.id
        message.message = 'left_group'
      else
        message.message_text = 'kicked'
        message.system_data  = chat_user_full_name(left_chat_participant)
      end

      message.save!
    end

    def send_issue_link
      issue_url = RedmineChatTelegram.issue_url(issue.id)
      command_text   = command.text
      issue_url_text = "#{issue.subject}\n#{issue_url}"
      bot.send_message(
        chat_id: command.chat.id,
        text: issue_url_text,
        disable_web_page_preview: true)
    end

    def log_message
      message.message = command.text.gsub('/log', '')
      message.bot_message = false
      message.is_system = false

      journal_text = message.as_text(with_time: false)
      issue.init_journal(
        User.anonymous,
        "_#{ I18n.t('redmine_chat_telegram.journal.from_telegram') }:_ \n\n#{journal_text}")

      issue.save!
      message.save!
    end

    def save_message
      message.message = command.text
      message.bot_message = false
      message.is_system = false
      message.save!
    end

    private

    def execute_command
      begin
        if command.group_chat_created
          group_chat_created
        elsif command.new_chat_participant.present?
          new_chat_participant
        elsif command.left_chat_participant.present?
          left_chat_participant
        elsif command.text =~ /\/task|\/link|\/url/ && command.chat.type == 'group'
          send_issue_link
        elsif command.text =~ /\/log/ && command.chat.type == 'group'
          log_message
        elsif command.text.present? && command.chat.type == 'group'
          save_message
        end
      rescue ActiveRecord::RecordNotFound
      # ignore
      rescue Exception => e
        logger.error "UPDATE #{e.class}: #{e.message} \n#{e.backtrace.join("\n")}"
        print e.backtrace.join("\n")
      end
    end

    def can_execute_command?
      command.is_a?(Telegrammer::DataTypes::Message) && issue.present?
    end

    def chat_user_full_name(telegram_user)
      [telegram_user.first_name, telegram_user.last_name].compact.join
    end

    def init_message
      telegram_message = TelegramMessage.new(
        issue_id:        issue.id,
        telegram_id:     command.message_id,
        sent_at:         command.date,
        from_id:         command.from.id,
        from_first_name: command.from.first_name,
        from_last_name:  command.from.last_name,
        from_username:   command.from.username,
        is_system:       true,
        bot_message:     true)
    end

    def find_issue
      chat_id = command.chat.id

      begin
        Issue.joins(:telegram_group)
          .find_by!(redmine_chat_telegram_telegram_groups: { telegram_id: chat_id.abs })
      rescue ActiveRecord::RecordNotFound => e
        nil
      rescue Exception => e
        logger.error "#{e.class}: #{e.message}\n#{e.backtrace.join("\n")}"
        nil
      end
    end
  end
end
