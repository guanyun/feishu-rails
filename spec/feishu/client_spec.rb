# frozen_string_literal: true

require 'spec_helper'
require 'json'

RSpec.describe Feishu::Client do
  let(:access_token) { instance_double(Feishu::AccessToken) }

  before do
    allow(Feishu::AccessToken).to receive(:new).and_return(access_token)
    allow(access_token).to receive(:tenant_access_token).and_return('tenant-token-1', 'tenant-token-2')
    allow(access_token).to receive(:clear_cache)
    allow(Feishu::Client).to receive(:default_options).and_return({})
  end

  describe '#get token retry' do
    subject(:client) { described_class.new }

    let(:expired) { { 'code' => 99_991_663, 'msg' => 'token expired' } }
    let(:ok) { { 'code' => 0, 'data' => { 'name' => 'ok' } } }

    def stub_get_responses(*bodies)
      responses = bodies.map do |body|
        instance_double(HTTParty::Response, parsed_response: body)
      end
      allow(Feishu::Client).to receive(:get).and_return(*responses)
    end

    it 'retries once after refreshing tenant authorization' do
      stub_get_responses(expired, ok)

      expect(client.get('/ping')).to eq('name' => 'ok')
      expect(Feishu::Client).to have_received(:get).twice
      expect(access_token).to have_received(:clear_cache).once
      expect(access_token).to have_received(:tenant_access_token).twice
    end

    it 'raises after the second AccessTokenExpiredError' do
      stub_get_responses(expired, expired)

      expect { client.get('/ping') }.to raise_error(Feishu::AccessTokenExpiredError)
      expect(Feishu::Client).to have_received(:get).twice
    end

    it 'does not retry when initialized with a user token' do
      user_client = described_class.new('user-token')
      stub_get_responses(expired)

      expect { user_client.get('/ping') }.to raise_error(Feishu::AccessTokenExpiredError)
      expect(Feishu::Client).to have_received(:get).once
      expect(access_token).not_to have_received(:clear_cache)
    end
  end

  describe '#put' do
    subject(:client) { described_class.new('user-token') }

    it 'returns nil when user token needs refresh' do
      response = instance_double(
        HTTParty::Response,
        parsed_response: { 'code' => 99_991_677, 'msg' => 'need refresh' }
      )
      allow(Feishu::Client).to receive(:put).and_return(response)

      expect(client.put('/sheets/v2/values', body: {})).to be_nil
    end
  end
end
