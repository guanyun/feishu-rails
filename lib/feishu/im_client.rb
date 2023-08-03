require 'feishu/api/im'

module Feishu
  class ImClient < Feishu::Client
    include Feishu::Api::Im
    
    def initialize
      super
      self.class.base_uri(Feishu.config.im_uri)
    end
  end
end