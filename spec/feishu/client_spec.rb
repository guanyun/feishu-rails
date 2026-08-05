# frozen_string_literal: true

require 'spec_helper'
require 'json'
require 'tmpdir'

RSpec.describe Feishu::Client do
  let(:access_token) { instance_double(Feishu::AccessToken) }
  let(:log_dir) { Dir.mktmpdir }

  before do
    allow(Feishu::RequestLogger).to receive(:log_path).and_return(File.join(log_dir, 'feishu_api.log'))
    Feishu::RequestLogger.reset!
    allow(Feishu::Config).to receive(:for).with(:feishu).and_return({})
    allow(Feishu).to receive(:config) do |app = Feishu::DEFAULT_APP|
      OpenStruct.new(
        app_id: "cli_#{app}",
        app_secret: "secret_#{app}",
        uri: "https://#{app}.example/open-apis"
      )
    end
    allow(Feishu::AccessToken).to receive(:new).and_return(access_token)
    allow(access_token).to receive(:tenant_access_token).and_return('tenant-token-1', 'tenant-token-2')
    allow(access_token).to receive(:clear_cache)
  end

  after do
    Feishu::RequestLogger.reset!
    FileUtils.remove_entry(log_dir) if Dir.exist?(log_dir)
  end

  describe 'GET 请求的 token 重试' do
    subject(:client) { described_class.new }

    let(:expired) { { 'code' => 99_991_663, 'msg' => 'token expired' } }
    let(:ok) { { 'code' => 0, 'data' => { 'name' => 'ok' } } }

    def stub_get_responses(*bodies)
      responses = bodies.map do |body|
        instance_double(HTTParty::Response, parsed_response: body)
      end
      allow(Feishu::Client).to receive(:get).and_return(*responses)
    end

    it 'token 过期时刷新后重试一次' do
      stub_get_responses(expired, ok)

      expect(client.get('/ping')).to eq('name' => 'ok')
      expect(Feishu::Client).to have_received(:get).twice
      expect(access_token).to have_received(:clear_cache).once
      expect(access_token).to have_received(:tenant_access_token).twice
    end

    it '失败与成功重试各记一条日志' do
      log_file = File.join(log_dir, 'feishu_api.log')
      File.write(log_file, '') if File.exist?(log_file)
      stub_get_responses(expired, ok)

      client.get('/ping')

      entries =
        File.read(log_file).split(/\n\n+/).reject(&:empty?).map do |block|
          block.each_line.each_with_object({}) do |line, memo|
            line = line.sub(/\A\[[^\]]+\]\s*/, '').strip
            next if line.empty?

            key, value = line.split('=', 2)
            memo[key] = value
          end
        end

      expect(entries.size).to eq(2)
      expect(entries[0]).to include(
        'success' => 'false',
        'error_class' => 'Feishu::AccessTokenExpiredError'
      )
      expect(entries[1]).to include('success' => 'true')
    end

    it '连续两次 token 过期则抛错' do
      stub_get_responses(expired, expired)

      expect { client.get('/ping') }.to raise_error(Feishu::AccessTokenExpiredError)
      expect(Feishu::Client).to have_received(:get).twice
    end

    it '按 client 所属应用刷新 token' do
      jiangsu_client = described_class.new(app: :jiangsu)
      stub_get_responses(expired, ok)

      jiangsu_client.get('/ping')

      expect(Feishu::AccessToken).to have_received(:new)
        .with(app: :jiangsu)
        .at_least(:once)
      expect(access_token).to have_received(:clear_cache).once
    end

    it '用户 token 过期时不重试' do
      user_client = described_class.new('user-token')
      stub_get_responses(expired)

      expect { user_client.get('/ping') }.to raise_error(Feishu::AccessTokenExpiredError)
      expect(Feishu::Client).to have_received(:get).once
      expect(access_token).not_to have_received(:clear_cache)
    end
  end

  describe 'PUT 请求' do
    subject(:client) { described_class.new('user-token') }

    it '用户 token 需刷新时返回 nil' do
      response = instance_double(
        HTTParty::Response,
        parsed_response: { 'code' => 99_991_677, 'msg' => 'need refresh' }
      )
      allow(Feishu::Client).to receive(:put).and_return(response)

      expect(client.put('/sheets/v2/values', body: {})).to be_nil
    end
  end

  describe '多应用隔离' do
    it '各 client 实例使用独立的 URL 和 Authorization' do
      allow(Feishu::AccessToken).to receive(:new) do |app:|
        instance_double(
          Feishu::AccessToken,
          tenant_access_token: "token-#{app}"
        )
      end
      response = instance_double(
        HTTParty::Response,
        parsed_response: { 'code' => 0, 'data' => { 'ok' => true } }
      )
      allow(Feishu::Client).to receive(:get).and_return(response)

      beijing = described_class.new
      jiangsu = described_class.new(app: :jiangsu)
      beijing.get('/ping')
      jiangsu.get('/ping')

      expect(Feishu::Client).to have_received(:get).with(
        'https://beijing.example/open-apis/ping',
        headers: hash_including(Authorization: 'Bearer token-beijing'),
        query: {},
        timeout: 10
      )
      expect(Feishu::Client).to have_received(:get).with(
        'https://jiangsu.example/open-apis/ping',
        headers: hash_including(Authorization: 'Bearer token-jiangsu'),
        query: {},
        timeout: 10
      )
    end
  end
end
