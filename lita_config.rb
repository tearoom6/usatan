Lita.configure do |config|
  config.robot.name = "usatan"
  config.robot.adapter = :slack
  config.adapters.slack.token = ENV['LITA_SLACK_TOKEN']
  config.robot.admins = ["U0EHUPSH4"]

  ## Set options for the Redis connection.
  # config.redis.host = "127.0.0.1"
  # config.redis.port = 1234

  # usatan adapter
  config.handlers.usatan.dictionary.path = "naist-jdic"
end
