require 'capybara'
require 'capybara/dsl'
require 'mail'

module Plugins
  class MailerPostBuildStep < Jenkins::PostBuildStep

    register 'Mailer', 'E-mail Notification'

    def recipients(recipients)
      control('recipients').set recipients
    rescue Capybara::ElementNotFound
      control('mailer_recipients').set recipients
    end
  end

  class Mailer
    include Jenkins::PageArea

    SERVER = 'mailtrap.io'
    MAILBOX = '19251ad93afaab19b'
    INBOX_ID = "23170"
    PASSWORD = 'c9039d1f090624'
    PORT = '2525'
    TOKEN = '2c04434bd66dfc37c130171f9d061af2'
    MESSAGES_API_URL = 'https://mailtrap.io/api/v1/inboxes/%s/messages?page=1&api_token=%s'
    MESSAGE_API_URL = 'https://mailtrap.io/api/v1/inboxes/%s/messages/%s/body.raw?api_token=%s'

    def initialize(global_config, prefix)
      super(global_config, prefix)
      @global = global_config
      @fingerprint = "%s@%s.com" % [Jenkins::PageObject.random_name, MAILBOX]
    end

    def setup_defaults
      @global.configure do
        find(:path, path('smtpServer')).set SERVER
        find(:path, path('advanced-button')).click
        find(:path, path('useSMTPAuth')).check
        find(:path, path('useSMTPAuth/smtpAuthUserName')).set MAILBOX
        find(:path, path('useSMTPAuth/smtpAuthPassword')).set PASSWORD
        find(:path, path('smtpPort')).set PORT

        # Fingerprint to identify message sent from this test run
        find(:path, path('replyToAddress')).set @fingerprint
        # Set for email-ext plugin as well if available
        begin
          path = '/hudson-plugins-emailext-ExtendedEmailPublisher/ext_mailer_default_replyto'
          find(:path, path).set @fingerprint
        rescue
          # noop
        end
      end
    end

    def send_test_mail(recipient)
      @global.open
      find(:path, path('')).check
      find(:path, path('/sendTestMailTo')).set recipient
      find(:path, path('/validate-button')).click
    end

    def mail(subject)
      messages = []
      fetch_messages.each do |msg|
        if msg['subject'].match subject

          message = Mail.new fetch_message(msg['id'])
          if is_ours? message
            messages << message
          end
        end
      end

      raise "More than one matching message" if messages.count > 1

      return messages[0]
    end

    def all_mails

      mids = []
      fetch_messages.each do |msg|
        mids << msg['message']['id']
      end

      messages = []
      mids.each do |mid|

        msg = Mail.new(fetch_message mid)
        if is_ours? msg
          messages << msg
        end
      end

      return messages
    end

    private
    # Use only messages with matching fingerprint
    def is_ours?(message)
      return false if message.reply_to.nil?
      message.reply_to.include? @fingerprint
    end

    def fetch_messages
      JSON.parse fetch(MESSAGES_API_URL % [INBOX_ID, TOKEN])
    end

    def fetch_message(message_id)
      fetch(MESSAGE_API_URL % [INBOX_ID, message_id, TOKEN])
    end

    def fetch(url)
      return Net::HTTP.get_response(URI.parse(url)).body
    end
  end
end
