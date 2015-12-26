require 'redis'
require 'okura/serializer'

module Lita
  module Handlers
    class Usatan < Handler
      config :dictionary do
        config :path, type: String, required: true
      end
      config :bot do
        config :name, type: String, required: true
      end

      class Word
        attr_reader :body, :type

        def initialize(body, type)
          @body = body
          @type = type
        end

        def is_bone_word?
          ['名詞', '動詞', '形容詞', '感動詞', 'フィラー', '接続詞'].include? type
        end

        def is_meta_word?
          type == 'BOS/EOS'
        end

        def self.parse(message, dictionary_path)
          tagger = Okura::Serializer::FormatInfo.create_tagger(dictionary_path)
          nodes = tagger.parse(message)
          nodes.mincost_path.map{|node| self.new(node.word.surface, node.word.left.text.split(',')[0]) }
            .select{|node| !node.is_meta_word? }
        end
      end

      class Brain
        REDIS_KEY_RFU_WORDS     = 'usa:rfu_words'
        REDIS_KEY_CHAIN_WORDS   = 'usa:chain_words:%{word}'
        REDIS_KEY_NEAR_WORDS    = 'usa:near_words:%{word}'
        REDIS_KEY_CONTEXT_WORDS = 'usa:context_words:%{context}'

        def initialize(store)
          @store = store
        end

        def forget
          @store.zrange(REDIS_KEY_RFU_WORDS, 0, -1, :with_scores => true).each do |word, score|
            @store.zincrby(REDIS_KEY_RFU_WORDS, get_adjusted_forget_score(score), word)
          end
        end

        def memorize_rfu_word(word)
          score = @store.zscore(REDIS_KEY_RFU_WORDS, word) || 0
          @store.zincrby(REDIS_KEY_RFU_WORDS, get_adjusted_memorize_score(score), word)
        end

        def memorize_rfu_words(words)
          words.each { |word| memorize_rfu_word(word) }
        end

        def remember_rfu_words_with_score
          Hash[@store.zrange(REDIS_KEY_RFU_WORDS, 0, -1, :with_scores => true)]
        end

        def remember_rfu_word
          draw_weighted_lottery(remember_rfu_words_with_score)
        end

        def memorize_chain_word(word, next_word)
          key = REDIS_KEY_CHAIN_WORDS % {word: word}
          score = @store.zscore(key, next_word) || 0
          @store.zincrby(key, get_adjusted_memorize_score(score), next_word)
        end

        def remember_chain_words_with_score(word)
          key = REDIS_KEY_CHAIN_WORDS % {word: word}
          Hash[@store.zrange(key, 0, -1, :with_scores => true)]
        end

        def remember_chain_word(word)
          draw_weighted_lottery(remember_chain_words_with_score(word))
        end

        def memorize_near_word(word, near_word)
          key = REDIS_KEY_NEAR_WORDS % {word: word}
          score = @store.zscore(key, near_word) || 0
          @store.zincrby(key, get_adjusted_memorize_score(score), near_word)
        end

        def memorize_near_words_combination(words, near_words)
          (1 .. words.count).each do |i|
            words.combination(i).each do |arr|
              near_words.each { |near_word| memorize_near_word(arr.sort.join('-'), near_word) }
            end
          end
        end

        def remember_near_words_with_score(words)
          key = REDIS_KEY_NEAR_WORDS % {word: words.sort.join('-')}
          Hash[@store.zrange(key, 0, -1, :with_scores => true)]
        end

        def remember_near_word(words)
          draw_weighted_lottery(remember_near_words_with_score(words))
        end

        def remember_near_word_in_combination(words)
          (words.count .. 1).each do |i|
            words.combination(i).each do |arr|
              near_word = remember_near_word(arr)
              return near_word unless near_word.nil?
            end
          end

          nil
        end

        def memorize_context_words(context, words)
          key = REDIS_KEY_CONTEXT_WORDS % {context: context}
          @store.del(key)
          @store.sadd(key, words)
          @store.expire(key, 600)
        end

        def remember_context_words(context)
          @store.smembers(REDIS_KEY_CONTEXT_WORDS % {context: context})
        end

        private
        def get_adjusted_memorize_score(score)
          100000 / (score + 50)
        end

        def get_adjusted_forget_score(score)
          - (1 + score / 1000)
        end

        def draw_weighted_lottery(weighted_hash, default = nil)
          sum = weighted_hash.values.inject(:+)
          threshold = rand(sum)

          weight = 0
          weighted_hash.each do |val, score|
            weight += score
            return val if weight > threshold
          end

          default
        end
      end

      SENTENCE_SPLITTER = /\n|。|\!|！|\?|？/
      SENTENCE_END_MARK = '。'
      MAX_CONVERSATION_CHARACTER_COUNT = 100

      route(/^(.+)/, :make_response, help: { 'SOMETHING' => 'speak to usatan!!!' })
      def make_response(response)
        return if response.message.body == 'wakeup'

        @name = config.bot.name
        @dictionary_path = config.dictionary.path
        @brain = Brain.new(Lita.redis)
        hear(response.room, response.user, response.message, response)
      end

      route(/^wakeup$/, :trigger_conscious, help: { 'wakeup' => 'trigger conscious.' })
      def trigger_conscious(response)
        @name = config.bot.name
        @dictionary_path = config.dictionary.path
        @brain = Brain.new(Lita.redis)
        every(600) do |timer|
          forget
          if rand > 0.99
            speak('general')
          end
        end
      end

      Lita.register_handler(self)

      private
      def hear(room, user, message, response)
        return if is_too_long_message?(message.body)

        context_words = @brain.remember_context_words(room.name)
        sentences = breakdown_to_sentences(message.body)
        bone_words = sentences.map do |sentence|
          Word.parse(sentence, @dictionary_path).select{|word| word.is_bone_word? }.map{|word| word.body }
        end.flatten

        if is_direct_message?(message)
          log << "detect direct message. (#{message.body})"
          # rfu words
          input_rfu_words(bone_words)
          # chain words
          input_chain_words(sentences)
          # near words
          input_near_words(context_words, bone_words)

          reply(response, bone_words)
        elsif is_own_message?(user)
          log << "detect own message. (#{message.body})"
          # rfu words
          input_rfu_words(bone_words)

          if rand > 0.9
            reply(response, bone_words)
          end
        else
          log << "detect other message. (#{message.body})"
          # rfu words
          input_rfu_words(bone_words)
          # chain words
          input_chain_words(sentences)
          # near words
          input_near_words(context_words, bone_words)

          if rand > 0.8
            reply(response, bone_words)
          end
        end

        # context words
        @brain.memorize_context_words(room.name, bone_words)
      end

      def speak(room_name)
        room = Lita::Room.find_by_name(room_name)
        target = Lita::Source.new(room: room)
        robot.send_message(target, self_message)
        log << "speak by botself."
      end

      def reply(response, words)
        message = reply_message(words)
        log << "reply message. (#{message})"
        after(2) { |timer| response.reply(message) }
      end

      def forget
        @brain.forget
      end

      def is_own_message?(user)
        user.name == @name
      end

      def is_direct_message?(message)
        message.private_message?
      end

      def is_too_long_message?(message)
        message.length > MAX_CONVERSATION_CHARACTER_COUNT
      end

      def breakdown_to_sentences(message)
        message.split(SENTENCE_SPLITTER).select{|sentence| !sentence.start_with?('http')}
      end

      def input_rfu_words(words)
        @brain.memorize_rfu_words(words)
      end

      def input_chain_words(sentences)
        sentences.each do |sentence|
          words = Word.parse(sentence, @dictionary_path).map{|word| word.body }
          words.push(SENTENCE_END_MARK)
          prev_word = nil
          words.each do |word|
            break if word == SENTENCE_END_MARK
            @brain.memorize_chain_word(prev_word, word) unless prev_word.nil?
            prev_word = word
          end
        end
      end

      def input_near_words(context_words, bone_words)
        unless context_words.nil?
          @brain.memorize_near_words_combination(context_words, bone_words)
        end
      end

      def compose_sentence(seed_word)
        sentence = seed_word
        while (chain_word = @brain.remember_chain_word(seed_word))
          sentence += chain_word
          seed_word = chain_word
        end
        sentence
      end

      def reply_message(words)
        near_word = @brain.remember_near_word_in_combination(words)
        return self_message if near_word.nil?
        compose_sentence(near_word)
      end

      def self_message
        seed_word = @brain.remember_rfu_word
        compose_sentence(seed_word)
      end

    end
  end
end