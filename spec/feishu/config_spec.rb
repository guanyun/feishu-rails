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
    it 'uses beijing by default' do
      expect(described_class.config.app_id).to eq('cli_beijing')
    end

    it 'selects an app explicitly by symbol or string' do
      expect(described_class.config(:jiangsu).app_id).to eq('cli_jiangsu')
      expect(described_class.config('jiangsu').app_id).to eq('cli_jiangsu')
    end

    it 'treats a blank app as beijing for compatibility' do
      expect(described_class.config(nil).app_id).to eq('cli_beijing')
      expect(described_class.config('').app_id).to eq('cli_beijing')
    end

    it 'rejects an unknown app' do
      expect { described_class.config(:unknown) }
        .to raise_error(ArgumentError, 'Unknown Feishu app: :unknown')
    end

    it 'rejects an incomplete app config' do
      root_config.jiangsu = { app_id: 'cli_jiangsu' }

      expect { described_class.config(:jiangsu) }
        .to raise_error(ArgumentError, /app_secret, uri/)
    end
  end
end
