RSpec.describe 'Feishu.redis_url' do
  around do |example|
    original = ENV['REDIS_URL']
    Feishu.instance_variable_set(:@redis, nil)
    example.run
  ensure
    if original.nil?
      ENV.delete('REDIS_URL')
    else
      ENV['REDIS_URL'] = original
    end
    Feishu.instance_variable_set(:@redis, nil)
  end

  it '优先使用配置中的 redis_url' do
    allow(Feishu::Config).to receive(:for).with(:feishu)
      .and_return(redis_url: 'redis://from-config/3')
    ENV['REDIS_URL'] = 'redis://from-env/3'

    expect(Feishu.redis_url).to eq('redis://from-config/3')
  end

  it '配置缺失时回退到 ENV[REDIS_URL]' do
    allow(Feishu::Config).to receive(:for).with(:feishu).and_return(redis_url: nil)
    ENV['REDIS_URL'] = 'redis://from-env/3'

    expect(Feishu.redis_url).to eq('redis://from-env/3')
  end

  it '配置与 ENV 均未设置时抛错' do
    allow(Feishu::Config).to receive(:for).with(:feishu).and_return(redis_url: nil)
    ENV.delete('REDIS_URL')

    expect { Feishu.redis_url }.to raise_error(
      ArgumentError,
      "Feishu redis_url is missing: set config.redis_url or ENV['REDIS_URL']"
    )
  end
end
