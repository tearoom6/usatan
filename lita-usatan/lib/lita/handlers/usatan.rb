require 'okura/serializer'

module Lita
  module Handlers
    class Usatan < Handler
      config :dictionary do
        config :path, type: String, required: true
      end

      route(/^(.+)/, :reply, help: { "SOMETHING" => "speak to usatan!!!" })
      def reply(response)
        tagger = Okura::Serializer::FormatInfo.create_tagger(config.dictionary.path)
        nodes = tagger.parse(response.matches[0][0])
        nouns = nodes.mincost_path.select{|node| /^名詞/ =~ node.word.left.text}
        response.reply(nouns.first.word.surface)
      end

      Lita.register_handler(self)
    end
  end
end
