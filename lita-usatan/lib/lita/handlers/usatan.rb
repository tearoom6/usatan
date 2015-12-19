require 'redis'
require 'okura/serializer'

module Lita
  module Handlers
    class Usatan < Handler
      REDIS_KEY_DICT = 'usa:dictionary'
      REDIS_KEY_LAST = 'usa:last'
      config :dictionary do
        config :path, type: String, required: true
      end

      route(/^(.+)/, :reply, help: { "SOMETHING" => "speak to usatan!!!" })
      def reply(response)
        message = response.matches[0][0]

        keyword = get_context
        if keyword
          reply = memorize(keyword, message)
          response.reply(reply)
          after(5) { |timer| response.reply(think(message)) }
          return
        end

        response.reply(think(message))
      end

      Lita.register_handler(self)

      private
      def get_context
        keyword = Lita.redis.get(REDIS_KEY_LAST)
        Lita.redis.del(REDIS_KEY_LAST)
        keyword
      end

      def ask(keyword)
        Lita.redis.set(REDIS_KEY_LAST, keyword)
        "#{keyword}ってなーに?"
      end

      def remember(keyword)
        Lita.redis.hget(REDIS_KEY_DICT, keyword)
      end

      def memorize(keyword, meaning)
        Lita.redis.hset(REDIS_KEY_DICT, keyword, meaning)
        ['ふーん', 'へぇ〜', 'なるほどぉ', 'ありがと！'].sample
      end

      def think(message)
        words = get_nouns(message)
        if words.any?
          words.each do |word|
            if (meaning = remember(word))
              return "それ知ってる！#{meaning}、でしょ？！"
            end
          end
          ask(words.sample)
        end
        ['うん？', 'へっ？', 'ふーん', 'そなんだー'].sample
      end

      def get_nouns(message)
        tagger = Okura::Serializer::FormatInfo.create_tagger(config.dictionary.path)
        nodes = tagger.parse(message)
        nodes.mincost_path.select{|node| /^名詞/ =~ node.word.left.text}.map{|node| node.word.surface}
      end
    end
  end
end
