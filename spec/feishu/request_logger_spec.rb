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
  end

  after do
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
    it '记录 app、client、api 和 params' do
      described_class.track(
        app: :jiangsu,
        app_id: 'cli_test',
        client: 'Feishu::UserClient',
        method: :get,
        path: '/contact/v3/users/1',
        params: { query: { user_id_type: 'open_id' } }
      ) { { 'ok' => true } }

      expect(last_entry).to include(
        'thread_id' => Thread.current.object_id.to_s,
        'company' => 'jiangsu',
        'app_id' => 'cli_test',
        'client' => 'Feishu::UserClient',
        'api' => 'GET /contact/v3/users/1',
        'success' => 'true'
      )
      expect(JSON.parse(last_entry['params'])).to eq('query' => { 'user_id_type' => 'open_id' })
      expect(File.read(log_path)).to end_with("\n\n")
    end

    it '失败时记录错误详情' do
      expect do
        described_class.track(
          app: :beijing,
          app_id: 'cli_test',
          client: 'Feishu::ApprovalClient',
          method: :post,
          path: '/approval/v4/instances'
        ) do
          raise Feishu::ResponseError.new(10_001, 'invalid param')
        end
      end.to raise_error(Feishu::ResponseError)

      expect(last_entry).to include(
        'success' => 'false',
        'error_class' => 'Feishu::ResponseError'
      )
      expect(last_entry['error']).to include('invalid param')
    end

    it 'app 为空时抛错' do
      [nil, ''].each do |app|
        expect do
          described_class.track(
            app: app,
            app_id: 'cli_test',
            client: 'Feishu::Client',
            method: :get,
            path: '/ping'
          ) { true }
        end.to raise_error(ArgumentError, 'Feishu app is required')
      end
    end
  end

  describe '日志时间戳' do
    it '使用 Rails 时区' do
      original_zone = Time.zone
      Time.zone = 'Beijing'
      formatter = described_class.send(:build_logger).formatter

      output = formatter.call(
        Logger::INFO,
        Time.utc(2026, 8, 3, 4, 30),
        nil,
        'message'
      )

      expect(output).to start_with('[2026-08-03 12:30:00] message')
    ensure
      Time.zone = original_zone
    end
  end
end
