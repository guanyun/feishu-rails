require 'httparty'
require 'redis'
require 'json'
require 'ostruct'
require 'active_support/core_ext/object/blank'
require 'feishu/version'
require 'feishu/config'

module Feishu
  DEFAULT_APP = :beijing

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
    url = Config.for(:feishu)[:redis_url].presence || ENV['REDIS_URL'].presence
    return url if url

    raise ArgumentError, "Feishu redis_url is missing: set config.redis_url or ENV['REDIS_URL']"
  end

  def redis
    @redis ||= Redis.new(url: redis_url)
  end

  def config(app = DEFAULT_APP)
    app = normalize_app(app)
    root_config = Config.for(:feishu)
    selected_config =
      if app == DEFAULT_APP
        root_config
      else
        root_config[app] || root_config[app.to_s]
      end

    unless selected_config
      raise ArgumentError, "Unknown Feishu app: #{app.inspect}"
    end

    attributes =
      if selected_config.respond_to?(:to_h)
        selected_config.to_h
      else
        selected_config
      end
    application_config = OpenStruct.new(attributes) # rubocop:disable Style/OpenStructUse

    missing = %i[app_id app_secret uri].select do |key|
      value = application_config.public_send(key)
      value.nil? || value == ''
    end
    unless missing.empty?
      raise ArgumentError, "Feishu app #{app.inspect} is missing: #{missing.join(', ')}"
    end

    application_config
  end

  def normalize_app(app)
    value = app.nil? || app.to_s.empty? ? DEFAULT_APP : app.to_sym
    value
  end

  def cipher(app: DEFAULT_APP)
    require 'feishu/cipher'
    Cipher.new(config(app).encrypt_key)
  end

  def parse_callback(encrypted, app:)
    app = normalize_app(app)
    app_config = config(app)
    callback = cipher(app: app).decrypt(encrypted)

    RequestLogger.track(
      app: app,
      app_id: app_config.app_id,
      client: 'Feishu::Callback',
      method: :callback,
      path: '/callbacks',
      params: { callback: callback }
    ) { callback }
  end
end

require 'feishu/request_logger'
require 'feishu/access_token'
require 'feishu/client'
require 'feishu/user_client'
require 'feishu/approval_client'
require 'feishu/message_client'
require 'feishu/mina_client'
require 'feishu/sheets_client'
require 'feishu/department_client'
require 'feishu/im_client'
