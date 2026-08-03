# frozen_string_literal: true

require 'json'
require 'logger'
require 'fileutils'
require 'tmpdir'
require 'active_support/time'

module Feishu
  # 将飞书 API 调用写入独立日志，便于多应用排查。
  class RequestLogger
    LOG_FILENAME = 'feishu_api.log'

    class << self
      attr_writer :logger

      # 包装一次 API 调用并记录 app / client / api / params。
      def track(client:, method:, path:, app:, app_id:, params: nil)
        started_at = monotonic_time
        api = format_api(method, path)
        app_context = { company: app, app_id: app_id }
        raise ArgumentError, 'Feishu app is required' if app.nil? || app.to_s.empty?

        app_context[:company] = app.to_sym

        result = yield
        success, error_message = result_status(result)

        write(
          app: app_context,
          client: client,
          api: api,
          params: params,
          success: success,
          duration_ms: elapsed_ms(started_at),
          error: error_message
        )
        result
      rescue StandardError => e
        write(
          app: app_context,
          client: client,
          api: api,
          params: params,
          success: false,
          duration_ms: elapsed_ms(started_at),
          error: e.message,
          error_class: e.class.name
        )
        raise
      end

      # 重置 logger，便于测试。
      def reset!
        @logger = nil
      end

      def log_path
        if defined?(Rails) && Rails.respond_to?(:root) && Rails.root
          File.join(Rails.root.to_s, 'log', LOG_FILENAME)
        else
          File.join(Dir.tmpdir, 'feishu', LOG_FILENAME)
        end
      end

      private

      def logger
        @logger ||= build_logger
      end

      def build_logger
        file = log_path
        FileUtils.mkdir_p(File.dirname(file))

        Logger.new(file).tap do |log|
          log.formatter = proc do |_severity, datetime, _progname, msg|
            "[#{datetime.in_time_zone.strftime('%Y-%m-%d %H:%M:%S')}] #{msg}\n"
          end
        end
      end

      def format_api(method, path)
        "#{method.to_s.upcase} #{path}"
      end

      def result_status(result)
        return [true, nil] unless result.respond_to?(:[])

        code = result['code']
        return [true, nil] if code.nil?
        return [true, nil] if code.to_i.zero?

        [false, "(#{code}) #{result['msg']}"]
      end

      def monotonic_time
        Process.clock_gettime(Process::CLOCK_MONOTONIC)
      end

      def elapsed_ms(started_at)
        ((monotonic_time - started_at) * 1000).round(1)
      end

      def write(app:, client:, api:, params:, success:, duration_ms:, error: nil, error_class: nil)
        lines = [
          "thread_id=#{Thread.current.object_id}",
          "company=#{app[:company]}",
          "app_id=#{app[:app_id]}",
          "client=#{client}",
          "api=#{api}",
          "params=#{params.nil? ? '' : JSON.generate(params)}",
          "success=#{success}",
          "duration_ms=#{duration_ms}"
        ]
        lines << "error=#{error}" if error
        lines << "error_class=#{error_class}" if error_class

        # 末尾多一个空行：join 后再 + "\n"，formatter 再追加 "\n"
        logger.public_send(success ? :info : :error, "#{lines.join("\n")}\n")
      end
    end
  end
end
