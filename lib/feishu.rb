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

  module_function

  def config
    puts "feishu config ============================================ start"
    puts "Thread.current['company'] => #{Thread.current['company']}, time => #{Time.now}"
    begin
      subco = Thread.current['company']
      feishu_config = Config.for(:feishu)

      selected_config = subco.blank? ?  feishu_config : feishu_config[subco]
      puts "feishu selected_config ============================================ end", selected_config
      puts "=================================================="

      OpenStruct.new(selected_config)
    end
  end

  def cipher
    puts "feishu cipher ============================================ start"
    puts "Thread.current['company'] => ", Thread.current['company'], "time => ", Time.now
    puts "feishu cipher ============================================ end"
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
