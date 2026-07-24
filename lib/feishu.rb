require 'httparty'
require 'redis'
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
      super "(#{error_code}) #{errmsg}"
    end
  end

  # Align with eagle ReadCache default when REDIS_URL is unset.
  DEFAULT_REDIS_URL = 'redis://127.0.0.1:6379/3'

  module_function

  def redis_url
    configured = config.redis_url if config.respond_to?(:redis_url)
    configured.presence || ENV['REDIS_URL'].presence || DEFAULT_REDIS_URL
  end

  def redis
    @redis ||= Redis.new(url: redis_url)
  end

  def config
    begin
      subco = Thread.current['company']
      feishu_config = Config.for(:feishu)

      selected_config = subco.blank? ?  feishu_config : feishu_config[subco]
      OpenStruct.new(selected_config)
    end
  end

  def cipher
    require 'feishu/cipher'
    begin
      Cipher.new(config.encrypt_key)
    end
  end
end

require 'feishu/access_token'
require 'feishu/client.rb'
require 'feishu/user_client'
require 'feishu/approval_client'
require 'feishu/message_client'
require 'feishu/mina_client'
require 'feishu/sheets_client'
require 'feishu/department_client'
require 'feishu/im_client'
