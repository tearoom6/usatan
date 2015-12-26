Lita.configure do |config|
  config.robot.name = "usatan"
  config.robot.adapter = :slack
  config.adapters.slack.token = ENV['LITA_SLACK_TOKEN']
  config.robot.admins = ["U0EHUPSH4"]
  config.http.port = ENV['PORT']

  # options for the Redis connection.
  config.redis[:url] = ENV['REDIS_URL']

  # lita-keepalive handler
  config.handlers.keepalive.url = ENV['KEEPALIVE_URL']

  # usatan handler
  config.handlers.usatan.dictionary.path = "naist-jdic"
end
