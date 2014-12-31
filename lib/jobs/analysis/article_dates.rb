
module Jobs
  module Analysis
    # Plot a dataset's members by year
    class ArticleDates < Jobs::Analysis::CSVJob
      add_concern 'NormalizeDocumentCounts'

      # Export the date format data
      #
      # Like all view/multiexport jobs, this job saves its data out as a JSON
      # file and then sends it to the user in various formats depending on
      # user selectons.
      #
      # @param [Hash] options parameters for this job
      # @option options [String] :user_id the user whose dataset we are to work on
      # @option options [String] :dataset_id the dataset to operate on
      # @option options [String] :task_id the analysis task we're working from
      # @return [void]
      def perform
        at(0, 100, t('common.progress_initializing'))
        standard_options!

        # Get the counts and normalize if requested
        analyzer = RLetters::Analysis::CountArticlesByField.new(
          @dataset,
          lambda do |p|
            at((p.to_f / 100.0 * 90.0).to_i, 100, t('.progress_counting'))
          end)
        dates = analyzer.counts_for(:year)

        at(90, 100, t('.progress_normalizing'))
        dates = normalize_document_counts(@user, :year, dates, options)

        dates = dates.to_a
        dates.each { |d| d[0] = Integer(d[0]) }

        # Fill in zeroes for any years that are missing
        at(95, 100, t('.progress_missing'))
        dates = Range.new(*(dates.map { |d| d[0] }.minmax)).each.map do |y|
          dates.assoc(y) || [y, 0]
        end

        # Save out the data, including getting the name of the normalization
        # set for pretty display
        at(100, 100, t('common.progress_finished'))

        norm_set_name = ''
        if options[:normalize_doc_counts] == '1'
          if options[:normalize_doc_dataset]
            norm_set = @user.datasets.active.find(options[:normalize_doc_dataset])
            norm_set_name = norm_set.name
          else
            norm_set_name = t('.entire_corpus')
          end
          value_header = t('.fraction_column')
        else
          value_header = t('.number_column')
        end
        year_header = Document.human_attribute_name(:year)

        csv = write_csv(nil, '') do |out|
          out << [year_header, value_header]
          dates.each do |d|
            out << d
          end
        end

        output = { data: dates,
                   csv: csv,
                   percent: (options[:normalize_doc_counts] == '1'),
                   normalization_set: norm_set_name,
                   year_header: year_header,
                   value_header: value_header }

        # Serialize out to JSON
        ios = StringIO.new(output.to_json)
        file = Paperclip.io_adapters.for(ios)
        file.original_filename = 'article_dates.json'
        file.content_type = 'application/json'

        @task.result = file

        # We're done here
        @task.finish!

        completed
      end

      # We don't want users to download the JSON file
      def self.download?
        false
      end
    end
  end
end
