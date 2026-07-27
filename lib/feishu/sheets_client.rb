require 'feishu/api/sheets'

module Feishu
  class SheetsClient < Feishu::Client
    include Feishu::Api::Sheets

    def initialize
      super
      self.class.base_uri(Feishu.config.uri)
    end
  end
end
