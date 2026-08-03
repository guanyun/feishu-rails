# frozen_string_literal: true

require 'spec_helper'
require 'feishu/cipher'

RSpec.describe 'Feishu.parse_callback' do
  it '使用指定应用解密、记录并返回回调内容' do
    config = OpenStruct.new(
      app_id: 'cli_jiangsu',
      encrypt_key: 'jiangsu-encrypt-key'
    )
    callback = {
      'header' => { 'event_type' => 'im.message.receive_v1' },
      'event' => { 'message' => { 'message_id' => 'om_1' } }
    }
    cipher = instance_double(Feishu::Cipher)

    allow(Feishu).to receive(:config).with(:jiangsu).and_return(config)
    expect(Feishu::Cipher).to receive(:new)
      .with('jiangsu-encrypt-key')
      .and_return(cipher)
    expect(cipher).to receive(:decrypt).with('encrypted').and_return(callback)
    expect(Feishu::RequestLogger).to receive(:track).with(
      app: :jiangsu,
      app_id: 'cli_jiangsu',
      client: 'Feishu::Callback',
      method: :callback,
      path: '/callbacks',
      params: { callback: callback }
    ).and_yield

    expect(Feishu.parse_callback('encrypted', app: :jiangsu)).to eq(callback)
  end
end
