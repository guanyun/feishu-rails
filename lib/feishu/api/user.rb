module Feishu
  module Api
    module User
      def batch_get_id(mobiles: [], emails: [])
        get(
          '/user/v1/batch_get_id',
          query: { mobiles: mobiles, emails: emails },
        )
      end

      def batch_get(employee_ids: [], open_ids: [])
        get(
          '/contact/v1/user/batch_get',
          query: { employee_ids: employee_ids, open_ids: open_ids },
        )
      end

      def get_user_id_by_mobile(mobile)
        res = batch_get_id(mobiles: [mobile])
        res['mobile_users'][mobile].first['user_id']
      end

      def get_user_id_by_open_id(open_id)
        union_id =
          batch_get(open_ids: [open_id])['user_infos'].first['union_id']
        res =
          get(
            '/user/v1/union_id/batch_get/list',
            query: { union_ids: [union_id] },
          )
        res['user_infos'][union_id]['user_id']
      end

      def get_user_info(user_id, user_id_type = 'open_id', department_id_type = 'open_department_id')
        puts "Getting user #{user_id} info #{user_id_type} for #{department_id_type}"
        get(
          "/contact/v3/users/#{user_id}",
          query: { user_id_type: user_id_type, department_id_type: department_id_type }
        )
      end

      # 搜索用户信息：https://open.feishu.cn/document/ukTMukTMukTM/uMTM4UjLzEDO14yMxgTN
      def search_users(user_name, page_size = 20)
        res = get(
            "/search/v1/user",
            query: {query: user_name, page_size: page_size}
        )
        res['users']
      end
    end
  end
end
