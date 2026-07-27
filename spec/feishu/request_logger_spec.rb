# frozen_string_literal: true

require 'spec_helper'
require 'json'
require 'tmpdir'

RSpec.describe Feishu::RequestLogger do
  let(:log_dir) { Dir.mktmpdir }
  let(:log_path) { File.join(log_dir, 'feishu_api.log') }

  before do
    allow(described_class).to receive(:log_path).and_return(log_path)
    described_class.reset!
    allow(Feishu).to receive(:config).and_return(OpenStruct.new(app_id: 'cli_test'))
    Thread.current['company'] = 'jiangsu'
  end

  after do
    Thread.current['company'] = nil
    described_class.reset!
    FileUtils.remove_entry(log_dir) if Dir.exist?(log_dir)
  end

  # 按空行分块，再解析 key=value（首行可能带 [timestamp] 前缀）
  def parse_entries(content = File.read(log_path))
    content.split(/\n\n+/).reject(&:empty?).map do |block|
      block.each_line.each_with_object({}) do |line, memo|
        line = line.sub(/\A\[[^\]]+\]\s*/, '').strip
        next if line.empty?

        key, value = line.split('=', 2)
        memo[key] = value
      end
    end
  end

  def last_entry
    parse_entries.last
  end

  describe '.track' do
    it 'logs company, client, api and params as multiline text' do
      described_class.track(
        client: 'Feishu::UserClient',
        method: :get,
        path: '/contact/v3/users/1',
        params: { query: { user_id_type: 'open_id' } }
      ) { { 'ok' => true } }

      expect(last_entry).to include(
        'company' => 'jiangsu',
        'app_id' => 'cli_test',
        'client' => 'Feishu::UserClient',
        'api' => 'GET /contact/v3/users/1',
        'success' => 'true'
      )
      expect(JSON.parse(last_entry['params'])).to eq('query' => { 'user_id_type' => 'open_id' })
      expect(File.read(log_path)).to end_with("\n\n")
    end

    it 'logs failures with error details' do
      expect do
        described_class.track(client: 'Feishu::ApprovalClient', method: :post, path: '/approval/v4/instances') do
          raise Feishu::ResponseError.new(10_001, 'invalid param')
        end
      end.to raise_error(Feishu::ResponseError)

      expect(last_entry).to include(
        'success' => 'false',
        'error_class' => 'Feishu::ResponseError'
      )
      expect(last_entry['error']).to include('invalid param')
    end

    it 'defaults blank company to beijing' do
      Thread.current['company'] = nil

      described_class.track(client: 'Feishu::Client', method: :get, path: '/ping') { true }

      expect(last_entry['company']).to eq('beijing')
    end
  end
end
