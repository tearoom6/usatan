module Lita
  module Handlers
    class Healthcheck < Handler
      http.get "/healthcheck/*", :health_check
      def health_check(request, response)
        response.body << 'OK'
      end

      Lita.register_handler(self)
    end
  end
end
