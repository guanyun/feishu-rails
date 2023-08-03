module Feishu
  module Api
    module Department
      def get_info(department_id, department_id_type: 'open_department_id')
        get("/departments/#{department_id}", query: { department_id_type: department_id_type})
      end

      def get_children(department_id, fetch_child: false, page_size: 50)
        get("/departments/#{department_id}/children", query: { fetch_child: fetch_child, page_size: page_size })
      end

      def get_users(department_id, page_size: 50)
        get("/users/find_by_department", query: { department_id: department_id, page_size: page_size })
      end
    end
  end
end
