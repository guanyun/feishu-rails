# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Feishu do
  let(:root_config) do
    OpenStruct.new(
      app_id: 'cli_beijing',
      app_secret: 'secret-beijing',
      uri: 'https://beijing.example/open-apis',
      redis_url: 'redis://localhost/1',
      jiangsu: {
        app_id: 'cli_jiangsu',
        app_secret: 'secret-jiangsu',
        uri: 'https://jiangsu.example/open-apis'
      }
    )
  end

  before do
    allow(Feishu::Config).to receive(:for).with(:feishu).and_return(root_config)
  end

  describe '.config' do
    it '默认使用北京应用' do
      expect(described_class.config.app_id).to eq('cli_beijing')
    end

    it '可通过 symbol 或 string 指定应用' do
      expect(described_class.config(:jiangsu).app_id).to eq('cli_jiangsu')
      expect(described_class.config('jiangsu').app_id).to eq('cli_jiangsu')
    end

    it '空 app 兼容为北京' do
      expect(described_class.config(nil).app_id).to eq('cli_beijing')
      expect(described_class.config('').app_id).to eq('cli_beijing')
    end

    it '未知 app 抛错' do
      expect { described_class.config(:unknown) }
        .to raise_error(ArgumentError, 'Unknown Feishu app: :unknown')
    end

    it '配置不完整时抛错' do
      root_config.jiangsu = { app_id: 'cli_jiangsu' }

      expect { described_class.config(:jiangsu) }
        .to raise_error(ArgumentError, /app_secret, uri/)
    end
  end
end
