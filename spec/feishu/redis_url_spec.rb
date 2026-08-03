RSpec.describe "Feishu.redis_url" do
  around do |example|
    original = ENV["REDIS_URL"]
    Feishu.instance_variable_set(:@redis, nil)
    example.run
  ensure
    if original.nil?
      ENV.delete("REDIS_URL")
    else
      ENV["REDIS_URL"] = original
    end
    Feishu.instance_variable_set(:@redis, nil)
  end

  it "prefers config.redis_url over ENV" do
    allow(Feishu::Config).to receive(:for).with(:feishu)
      .and_return(redis_url: "redis://from-config/3")
    ENV["REDIS_URL"] = "redis://from-env/3"

    expect(Feishu.redis_url).to eq("redis://from-config/3")
  end

  it "falls back to ENV['REDIS_URL'] when config has no redis_url" do
    allow(Feishu::Config).to receive(:for).with(:feishu).and_return(redis_url: nil)
    ENV["REDIS_URL"] = "redis://from-env/3"

    expect(Feishu.redis_url).to eq("redis://from-env/3")
  end

  it "raises when neither config.redis_url nor ENV['REDIS_URL'] is set" do
    allow(Feishu::Config).to receive(:for).with(:feishu).and_return(redis_url: nil)
    ENV.delete("REDIS_URL")

    expect { Feishu.redis_url }.to raise_error(
      ArgumentError,
      "Feishu redis_url is missing: set config.redis_url or ENV['REDIS_URL']"
    )
  end
end
