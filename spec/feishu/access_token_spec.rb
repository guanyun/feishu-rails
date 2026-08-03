# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Feishu::AccessToken do
  let(:redis) { instance_double(Redis) }

  before do
    allow(Feishu).to receive(:config) do |app = Feishu::DEFAULT_APP|
      OpenStruct.new(
        app_id: "cli_#{app}",
        app_secret: "secret_#{app}",
        uri: "https://#{app}.example/open-apis"
      )
    end
    allow(Feishu).to receive(:redis).and_return(redis)
  end

  it '按 app_id 隔离不同应用的 token 缓存键' do
    beijing = described_class.new
    jiangsu = described_class.new(app: :jiangsu)

    expect(beijing.send(:tenant_access_token_key))
      .to eq('feishu:cli_beijing:tenant_access_token')
    expect(jiangsu.send(:tenant_access_token_key))
      .to eq('feishu:cli_jiangsu:tenant_access_token')
  end

  it '默认加载北京配置，显式传入 :jiangsu 时加载江苏配置' do
    beijing = described_class.new
    jiangsu = described_class.new(app: :jiangsu)

    expect(beijing.config).to have_attributes(
      app_id: 'cli_beijing',
      app_secret: 'secret_beijing'
    )
    expect(jiangsu.config).to have_attributes(
      app_id: 'cli_jiangsu',
      app_secret: 'secret_jiangsu'
    )
  end

  it '只清理指定应用的 token 缓存' do
    allow(redis).to receive(:del)

    described_class.new(app: :jiangsu).clear_cache

    expect(redis).to have_received(:del).with('feishu:cli_jiangsu:tenant_access_token')
    expect(redis).to have_received(:del).with('feishu:cli_jiangsu:app_access_token')
    expect(redis).to have_received(:del).with('feishu:cli_jiangsu:jsapi_ticket')
  end
end
