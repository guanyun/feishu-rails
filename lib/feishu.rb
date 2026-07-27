require 'httparty'
require 'redis'
require 'json'
require 'feishu/version'
require 'feishu/config'

module Feishu
  class AccessTokenExpiredError < RuntimeError; end
  class UserTokenNeedRefresh < RuntimeError; end
  class UserTokenExpiredError < RuntimeError; end

  class ResultErrorException < RuntimeError; end
  class ThreadValueMissed < RuntimeError; end

  class ResponseError < StandardError
    attr_reader :error_code

    def initialize(errcode, errmsg = '')
      @error_code = errcode
      super("(#{error_code}) #{errmsg}")
    end
  end

  module_function

  def redis_url
    url = config.redis_url.presence || ENV['REDIS_URL'].presence
    return url if url

    raise ArgumentError, "Feishu redis_url is missing: set config.redis_url or ENV['REDIS_URL']"
  end

  def redis
    @redis ||= Redis.new(url: redis_url)
  end

  def config
    subco = Thread.current['company']
    feishu_config = Config.for(:feishu)
    selected_config = subco.blank? ? feishu_config : feishu_config[subco]
    OpenStruct.new(selected_config) # rubocop:disable Style/OpenStructUse
  end

  def cipher
    require 'feishu/cipher'
    Cipher.new(config.encrypt_key)
  end
end

require 'feishu/access_token'
require 'feishu/client'
require 'feishu/user_client'
require 'feishu/approval_client'
require 'feishu/message_client'
require 'feishu/mina_client'
require 'feishu/sheets_client'
require 'feishu/department_client'
require 'feishu/im_client'
