# Feishu

Guanyun 使用的飞书 Ruby API client。

## Installation

从 GitHub 安装：

```ruby
gem 'feishu', github: 'guanyun/feishu-rails'
```

And then execute:

    $ bundle install

## Usage

配置以北京应用为根节点，其他应用使用同名子节点：

```yaml
feishu:
  app_id: cli_beijing
  app_secret: beijing_secret
  uri: https://open.feishu.cn/open-apis
  approval_uri: https://www.feishu.cn/approval/openapi/v2
  message_uri: https://open.feishu.cn/open-apis/message/v4
  contact_uri: https://open.feishu.cn/open-apis/contact/v3
  im_uri: https://open.feishu.cn/open-apis/im/v1
  encrypt_key: beijing_encrypt_key
  redis_url: redis://localhost:6379/0
  jiangsu:
    app_id: cli_jiangsu
    app_secret: jiangsu_secret
    uri: https://open.feishu.cn/open-apis
    approval_uri: https://www.feishu.cn/approval/openapi/v2
    message_uri: https://open.feishu.cn/open-apis/message/v4
    contact_uri: https://open.feishu.cn/open-apis/contact/v3
    im_uri: https://open.feishu.cn/open-apis/im/v1
    encrypt_key: jiangsu_encrypt_key
```

无参数时兼容使用北京应用；其他应用必须用 `app:` 明确指定：

```ruby
Feishu::UserClient.new.get_user_info(open_id)
Feishu::UserClient.new(app: :jiangsu).get_user_info(open_id)
Feishu::AccessToken.new(app: :jiangsu).tenant_access_token
Feishu.parse_callback(encrypted, app: :jiangsu)
```

使用 user token 时，token 仍是第一个位置参数：

```ruby
Feishu::UserClient.new(user_access_token, app: :jiangsu)
```

每个 client 都固定持有自己的 app 配置和 token。不同 app 的并发请求不会共享
HTTParty header 或 base URI。token Redis key 使用 `app_id` 隔离。

Rails 下 API 日志写入 `log/feishu_api.log`，包含 app、app_id、API、耗时和错误。

## Development

```shell
bundle install
bundle exec rspec
```

## Contributing

Bug reports and pull requests are managed at https://github.com/guanyun/feishu-rails.

