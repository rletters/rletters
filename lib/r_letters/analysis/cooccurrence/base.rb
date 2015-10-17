
module RLetters
  module Analysis
    # Various analyzers for cooccurrence patterns
    #
    # Co-occurrences, as opposed to collocations, are words whose appearance is
    # statistically significantly correlated, but which (unlike collocations)
    # do *not* appear directly adjacent to one another.
    #
    # This analyzer takes a given word and returns all pairs in which that
    # word appears, sorted by significance.
    module Cooccurrence
      # Base methods common to all cooccurrence analyzers
      class Base
        # Create a new cooccurrence analyzer
        #
        # @param [Dataset] dataset the dataset to analyze
        # @param [Integer] num_pairs the number of cooccurrences to return
        # @param [String] words one or more words to analyze. If this is a
        #   single word, the analyzer will return the top +num_pairs+ pairs
        #   containing that word. If it is a comma-separated list of words, it
        #   will analyze only all combinations of those words.
        # @param [Integer] window the window size to use for analysis.
        #   The default size of 200 approximates "paragraph-level" cooccurrence
        #   analysis.
        # @param [Symbol] stemming the stemming method to use; can be +nil+ for
        #   no stemming, +:stem+ for basic Porter stemming, or +:lemma+ for
        #   full lemmatization
        # @param [Proc] progress If set, a function to call with a percentage
        #   of completion (one Integer parameter)
        def initialize(dataset, num_pairs, words, window = 200, stemming = nil,
                       progress = nil)
          @dataset = dataset
          @window = window.to_i
          @stemming = stemming
          @progress = progress

          # Split into an array if required
          @words = words.mb_chars.downcase.to_s
          if @words.include?(',')
            @words = @words.split.map { |w| w.gsub(',', '').strip }
          else
            @words = [@words]
          end

          # Lemmatize or stem the target words
          if @stemming == :lemma
            @words = NLP.lemmatize_words(@words)
          elsif @stemming == :stem
            @words = @words.map!(&:stem)
          end

          if @words.size > 1
            # Don't go by count, take all the pairs
            @num_pairs = nil

            @pairs = {}
            combos = @words.combination(2).to_a
            combos.group_by(&:first).each { |k, v| @pairs[k] = v.map(&:last) }
          else
            # Just one word, use the most frequent num_pairs
            @num_pairs = num_pairs
            @pairs = { @words[0] => [] }
          end
        end

        # Perform cooccurrence analysis
        #
        # Don't call this on the base class, but on one of the child classes
        # that implements a pair-scoring method.
        #
        # @return [Array<Array(String, Float)>] a set of words and their
        #   associated significance values, sorted in order of significance
        #   (most significant first)
        def call
          base_frequencies, joint_frequencies, n = frequencies
          total_i = @pairs.size.to_f

          n = n.to_f
          ret = []

          @pairs.each_with_index do |(word, word_2_array), i|
            f_a = base_frequencies[word].to_f

            # Loop over the right array -- either just the words that we want
            # to query, or all of them
            if word_2_array.empty?
              enum = base_frequencies.each_key
            else
              enum = word_2_array.each
            end
            total_words = enum.size.to_f

            enum.each_with_index do |word_2, j|
              if @progress
                p = (i.to_f / total_i) + (1 / total_i) * j.to_f / total_words
                @progress.call((p * 33.0).to_i + 66)
              end
              next if word_2 == word

              f_b = base_frequencies[word_2].to_f
              f_ab = joint_frequencies[word][word_2].to_f

              ret << [word + ' ' + word_2, score(f_a, f_b, f_ab, n)]
            end
          end

          ret.compact!
          if @num_pairs
            ret = sort_results(ret)
            ret = ret.take(@num_pairs) if @num_pairs > 0
          end

          @progress && @progress.call(100)

          ret
        end

        private

        # Return frequency counts
        #
        # All cooccurrence analyzers use the same input data -- the frequency
        # of words in bins of the given window size. This function computes
        # that data.
        #
        # Also, putting this in its own function *should* encourage the GC to
        # clean up the analyzer object after this function returns.
        #
        # @return [Array<(Hash<String, Integer>, Hash<String, Integer>, Integer)]
        #   First, the number of bins in which every word in the dataset
        #   appears (the +base_frequencies+). Second, the number of bins in
        #   which every word *and* the word at issue both appear (the
        #   +joint_frequencies+). Lastly, the number of bins (+n+).
        def frequencies
          wl = RLetters::Documents::WordList.new(stemming: @stemming)
          ds = RLetters::Documents::Segments.new(wl,
                                                 block_size: @window,
                                                 last_block: :small_last)
          ss = RLetters::Datasets::Segments.new(@dataset,
                                                ds,
                                                split_across: false)

          analyzer = RLetters::Analysis::Frequency::FromPosition.call(
            dataset_segments: ss,
            progress: lambda do |p|
              @progress && @progress.call((p.to_f / 100.0 * 33.0).to_i)
            end)

          # Combine all the block hashes, summing the values
          total = analyzer.blocks.size.to_f

          base_frequencies = {}
          analyzer.blocks.each_with_index do |b, i|
            @progress && @progress.call((i.to_f / total * 16.0).to_i + 33)

            b.each_key do |k|
              base_frequencies[k] ||= 0
              base_frequencies[k] += 1
            end
          end

          # Get the frequencies of cooccurrence with the word in question
          joint_frequencies = {}
          @pairs.each_with_index do |(word, word_2_array), i|
            joint_frequencies[word] = {}

            analyzer.blocks.each_with_index do |b, j|
              if @progress
                p = ((i.to_f) / @pairs.size.to_f) +
                    (1 / @pairs.size.to_f) * (j.to_f / total.to_f)
                @progress.call((p * 17.0).to_i + 49)
              end

              next unless b[word] && b[word] > 0

              if word_2_array.empty?
                b.each_key do |k|
                  joint_frequencies[word][k] ||= 0
                  joint_frequencies[word][k] += 1
                end
              else
                word_2_array.each do |w|
                  if b.keys.include?(w)
                    joint_frequencies[word][w] ||= 0
                    joint_frequencies[word][w] += 1
                  end
                end
              end
            end
          end

          [base_frequencies, joint_frequencies, analyzer.blocks.size]
        end
      end
    end
  end
end
