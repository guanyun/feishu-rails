require 'feishu/api/user'

module Feishu
  class UserClient < Feishu::Client
    include Feishu::Api::User
    
    def initialize(authorization = nil)
      super(authorization)
      self.class.base_uri(Feishu.config.uri)
    end
  end
end