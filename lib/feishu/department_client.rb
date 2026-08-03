require 'feishu/api/department'

module Feishu
  class DepartmentClient < Feishu::Client
    BASE_URI_CONFIG_KEY = :contact_uri

    include Feishu::Api::Department
  end
end