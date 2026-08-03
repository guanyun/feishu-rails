require 'feishu/api/sheets'

module Feishu
  class SheetsClient < Feishu::Client
    include Feishu::Api::Sheets
  end
end
