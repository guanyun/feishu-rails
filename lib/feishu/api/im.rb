module Feishu
  module Api
    module Im
      def send_message(receive_id:, content:, msg_type:, receive_id_type: 'user_id')
        post(
          "/messages",
          query: { receive_id_type: receive_id_type },
          body: { receive_id: receive_id, content: content, msg_type: msg_type }
        )
      end
    end
  end
end
