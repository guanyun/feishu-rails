# frozen_string_literal: true

module Feishu
  class Client
    include HTTParty

    format :json

    disable_rails_query_string_format

    MAX_TOKEN_RETRIES = 1
    BASE_URI_CONFIG_KEY = :uri
    TOKEN_TYPE = :tenant_access_token

    attr_reader :app, :config

    def initialize(authorization = nil, app: Feishu::DEFAULT_APP)
      @app = Feishu.normalize_app(app)
      @config = Feishu.config(@app)
      @base_uri = config.public_send(self.class::BASE_URI_CONFIG_KEY)
      if @base_uri.nil? || @base_uri == ''
        raise ArgumentError,
              "Feishu app #{app.inspect} is missing: #{self.class::BASE_URI_CONFIG_KEY}"
      end
      @user_authorized = !authorization.nil?
      @authorization = authorization || access_token.public_send(self.class::TOKEN_TYPE)
    end

    def get(path, query: {})
      request(:get, path, query: query)
    end

    def post(path, multipart: false, query: {}, body: {})
      request(:post, path, multipart: multipart, query: query, body: body)
    end

    def put(path, multipart: false, query: {}, body: {})
      request(:put, path, multipart: multipart, query: query, body: body)
    rescue Feishu::UserTokenNeedRefresh
      nil
    end

    def delete(path, query: {}, body: {})
      request(:delete, path, query: query, body: body)
    end

    def patch(path, query: {}, body: {})
      request(:patch, path, query: query, body: body)
    end

    def change_request_header(authentication)
      @authorization = authentication
    end

    private

    def request(http_method, path, multipart: false, query: {}, body: {})
      retries = 0
      params = request_params(multipart: multipart, query: query, body: body)

      begin
        RequestLogger.track(
          app: app,
          app_id: config.app_id,
          client: self.class.name,
          method: http_method,
          path: path,
          params: params
        ) do
          handle_response(
            send_http(http_method, path, multipart: multipart, query: query, body: body).parsed_response
          )
        end
      rescue Feishu::AccessTokenExpiredError
        raise if user_authorized? || retries >= MAX_TOKEN_RETRIES

        retries += 1
        access_token.clear_cache
        refresh_app_authorization!
        retry
      end
    end

    def send_http(http_method, path, multipart:, query:, body:)
      url = api_url(path)
      options = { headers: request_headers }

      case http_method
      when :get
        self.class.get(url, **options, query: query)
      when :delete
        self.class.delete(url, **options, query: query, body: body)
      when :post, :put
        self.class.public_send(
          http_method,
          url,
          **options,
          multipart: multipart,
          query: query,
          body: multipart ? body : body.to_json
        )
      when :patch
        self.class.patch(url, **options, query: query, body: body.to_json)
      else
        raise ArgumentError, "unsupported http method: #{http_method}"
      end
    end

    def request_params(multipart:, query:, body:)
      params = {}
      params[:query] = query unless query.nil? || query.empty?
      if multipart
        params[:multipart] = true
        params[:body_keys] = body.is_a?(Hash) ? body.keys : body.class.name
      elsif !body.nil? && body != {}
        params[:body] = body
      end
      params.empty? ? nil : params
    end

    def user_authorized?
      @user_authorized
    end

    def access_token
      @access_token ||= AccessToken.new(app: app)
    end

    def api_url(path)
      "#{@base_uri.to_s.sub(%r{/$}, '')}/#{path.to_s.sub(%r{\A/}, '')}"
    end

    def request_headers
      {
        "Authorization": "Bearer #{@authorization}",
        "Content-Type": 'application/json',
      }
    end

    # 重新拉取当前 app 对应的 token 并写回 Authorization。
    def refresh_app_authorization!
      change_request_header(access_token.public_send(self.class::TOKEN_TYPE))
    end

    def handle_response(response)
      case response['code']
      when 0
        response.fetch('data')
      when 99_991_663, 99_991_664, 99_991_661
        raise Feishu::AccessTokenExpiredError
      when 99_991_677
        raise Feishu::UserTokenNeedRefresh
      when 99_991_643, 999_91_668
        raise Feishu::UserTokenExpiredError
      else
        raise Feishu::ResponseError.new(response['code'], response['msg'])
      end
    end
  end
end
