require 'feishu/api/department'

module Feishu
  class DepartmentClient < Feishu::Client
    include Feishu::Api::Department
    
    def initialize
      super
      self.class.base_uri(Feishu.config.contact_uri)
    end
  end
end