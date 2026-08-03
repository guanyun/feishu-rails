require 'feishu/api/mina'

module Feishu
  class MinaClient < Feishu::Client
    TOKEN_TYPE = :app_access_token

    include Feishu::Api::Mina
  end
end
