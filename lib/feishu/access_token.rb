# frozen_string_literal: true

module Feishu
  class AccessToken
    include HTTParty

    headers 'Content-Type' => 'application/json'

    def initialize
      self.class.base_uri(Feishu.config.uri)
    end

    def tenant_access_token
      Feishu.redis.get(tenant_access_token_key) || _tenant_access_token
    end

    def app_access_token
      Feishu.redis.get(app_access_token_key) || _app_access_token
    end

    def jsapi_ticket
      Feishu.redis.get(jsapi_ticket_key) || _jsapi_ticket
    end

    def clear_cache
      Feishu.redis.del(tenant_access_token_key)
      Feishu.redis.del(app_access_token_key)
      Feishu.redis.del(jsapi_ticket_key)
    end

    def user_access_token(grant_type: 'authorization_code', code:)
      post(
        '/authen/v1/access_token',
        body: { grant_type: grant_type, code: code },
        headers: bearer_headers(AccessToken.new.app_access_token)
      )
    end

    def refresh_user_access_token(grant_type: 'refresh_token', refresh_token:)
      post(
        '/authen/v1/refresh_access_token',
        body: { grant_type: grant_type, refresh_token: refresh_token },
        headers: bearer_headers(AccessToken.new.app_access_token)
      )
    end

    private

    # 统一发 POST 并记日志。
    def post(path, body: nil, headers: nil)
      options = {}
      options[:body] = body.to_json unless body.nil?
      options[:headers] = headers if headers

      RequestLogger.track(
        client: self.class.name,
        method: :post,
        path: path,
        params: body.nil? ? nil : { body: body }
      ) do
        self.class.post(path, **options)
      end
    end

    def bearer_headers(token)
      {
        "Authorization": "Bearer #{token}",
        "Content-Type": 'application/json',
      }
    end

    def _tenant_access_token
      body = {
        app_id: Feishu.config.app_id,
        app_secret: Feishu.config.app_secret,
      }
      response = post('/auth/v3/tenant_access_token/internal/', body: body)
      Feishu.redis.setex(
        tenant_access_token_key,
        response['expire'] - 5,
        response['tenant_access_token'],
      )
      response['tenant_access_token']
    end

    def _app_access_token
      body = {
        app_id: Feishu.config.app_id,
        app_secret: Feishu.config.app_secret,
      }
      response = post('/auth/v3/app_access_token/internal/', body: body)
      Feishu.redis.setex(
        app_access_token_key,
        response['expire'] - 5,
        response['app_access_token'],
      )
      response['app_access_token']
    end

    def _jsapi_ticket
      response = post(
        '/jssdk/ticket/get',
        headers: bearer_headers(AccessToken.new.tenant_access_token)
      )
      Feishu.redis.setex(
        jsapi_ticket_key,
        response['data']['expire_in'] - 5,
        response['data']['ticket'],
      )
      response['data']['ticket']
    end

    [:app_access_token_key, :tenant_access_token_key, :jsapi_ticket_key].each do |method_name|
      define_method method_name do
        "#{Thread.current['company']}#{method_name}"
      end
    end
  end
end
