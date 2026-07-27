# frozen_string_literal: true

module Feishu
  class Client
    include HTTParty

    format :json

    disable_rails_query_string_format

    MAX_TOKEN_RETRIES = 1

    def initialize(authorization = nil)
      @user_authorized = !authorization.nil?

      if authorization
        change_request_header(authorization)
      else
        self.class.default_options.merge!(
          headers: {
            "Authorization": "Bearer #{AccessToken.new.tenant_access_token}",
            "Content-Type": 'application/json',
          },
        )
      end
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
      self.class.default_options.merge!(
        headers: {
          "Authorization": "Bearer #{authentication}",
          "Content-Type": 'application/json',
        },
      )
    end

    private

    def request(http_method, path, multipart: false, query: {}, body: {})
      with_token_retry do
        raw =
          case http_method
          when :get
            self.class.get(path, query: query)
          when :delete
            self.class.delete(path, query: query, body: body)
          when :post, :put
            self.class.public_send(
              http_method,
              path,
              multipart: multipart,
              query: query,
              body: multipart ? body : body.to_json
            )
          when :patch
            self.class.patch(path, query: query, body: body.to_json)
          else
            raise ArgumentError, "unsupported http method: #{http_method}"
          end
        handle_response(raw.parsed_response)
      end
    end

    # tenant token 过期时最多再试 1 次；user token 客户端不自动重试。
    def with_token_retry
      retries = 0
      begin
        yield
      rescue Feishu::AccessTokenExpiredError
        raise if user_authorized? || retries >= MAX_TOKEN_RETRIES

        retries += 1
        AccessToken.new.clear_cache
        refresh_tenant_authorization!
        retry
      end
    end

    def user_authorized?
      @user_authorized
    end

    # 重新拉取 tenant token 并写回 Authorization。
    def refresh_tenant_authorization!
      change_request_header(AccessToken.new.tenant_access_token)
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
