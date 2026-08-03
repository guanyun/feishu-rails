require 'feishu/api/im'

module Feishu
  class ImClient < Feishu::Client
    BASE_URI_CONFIG_KEY = :im_uri

    include Feishu::Api::Im
  end
end