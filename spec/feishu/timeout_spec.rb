# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Feishu.timeout' do
  it '未配置时默认 10 秒' do
    allow(Feishu::Config).to receive(:for).with(:feishu).and_return({})

    expect(Feishu.timeout).to eq(10)
  end

  it '从根配置读取 timeout' do
    allow(Feishu::Config).to receive(:for).with(:feishu).and_return(timeout: 15)

    expect(Feishu.timeout).to eq(15)
  end

  it '非法或非正数 timeout 时使用默认值' do
    allow(Feishu::Config).to receive(:for).with(:feishu).and_return(timeout: 0)
    expect(Feishu.timeout).to eq(10)

    allow(Feishu::Config).to receive(:for).with(:feishu).and_return(timeout: 'slow')
    expect(Feishu.timeout).to eq(10)
  end
end
