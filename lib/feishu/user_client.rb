require 'feishu/api/user'

module Feishu
  class UserClient < Feishu::Client
    include Feishu::Api::User
  end
end