Lita.configure do |config|
  config.robot.name = "usatan"
  config.robot.adapter = :slack
  config.adapters.slack.token = ENV['LITA_SLACK_TOKEN']
  config.robot.admins = ["U0EHUPSH4"]

  # options for the Redis connection.
  config.redis[:url] = ENV['REDIS_URL']

  # lita-keepalive
  config.url = ENV['KEEPALIVE_URL']
  config.minutes = 20

  # usatan adapter
  config.handlers.usatan.dictionary.path = "naist-jdic"
end
