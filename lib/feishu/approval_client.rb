require 'feishu/api/approval'

module Feishu
  class ApprovalClient < Client
    BASE_URI_CONFIG_KEY = :approval_uri

    include Feishu::Api::Approval
  end
end