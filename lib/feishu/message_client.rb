require 'feishu/api/message'

module Feishu
  class MessageClient < Feishu::Client
    BASE_URI_CONFIG_KEY = :message_uri

    include Feishu::Api::Message
  end
end