module Feishu
  class Client
    include HTTParty

    format :json

    disable_rails_query_string_format

    MAX_TOKEN_RETRIES = 3

    def initialize(authorization = nil)

      return self.class.default_options.merge!(
        headers: {
          "Authorization": "Bearer #{AccessToken.new.tenant_access_token}",
          "Content-Type": 'application/json',
        },
      ) unless authorization
      change_request_header(authorization)
    end

    def get(path, query: {})
      request_with_token_retry { self.class.get(path, query: query) }
    end

    def post(path, multipart: false, query:{}, body: {})
      request_with_token_retry do
        self.class.post(
          path,
          multipart: multipart,
          query: query,
          body: multipart ? body : body.to_json,
        )
      end
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

    def request_with_token_retry
      retries = 0
      loop do
        response = yield
        return handle_response(response.parsed_response)
      rescue Feishu::AccessTokenExpiredError
        retries += 1
        raise Feishu::AccessTokenRetryExceededError if retries > MAX_TOKEN_RETRIES

        AccessToken.new.clear_cache
      end
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
