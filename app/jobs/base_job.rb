
# Base class for all jobs
#
# Analysis jobs have two special partials that can be implemented to
# engage novel behavior:
#
# - `_params.html.haml` (optional): If this view is present, then after the
#   task has collected the appropriate number of datasets, the user will be
#   presented with this form in order to set special parameters for the
#   task.  This partial should consist of a form that submits to
#   `dataset_tasks_path` with `:post` (`datasets/tasks#create`).
# - `results.html.haml` (optional): Tasks may report their results in two
#   different ways.  Some tasks (e.g., ExportCitations) just dump all of
#   their results into a file (see `Task#result_file`) for the
#   user to download.  This is the default, for which `#download?` returns
#   `true`.  If `#download?` is overridden to return `false`, then the
#   job is expected to implement the `results` view, which will show the
#   user the results of the job in HTML form.  The standard way to do this
#   is to write the job results out as JSON in `Task#result_file`,
#   and then to parse this JSON into HAML in the view.
#
# Note that this class does several things that seem pretty hacky and
# involve class instance variables. All of them, however, are tied to the
# `.add_concern` method, which is *only* called when classes are loaded (as
# it should be called within the body of an analysis job class). That class
# loading happens during Rails boot time, which is explicitly guaranteed to
# be single-threaded.
class BaseJob < ActiveJob::Base
  queue_as :analysis

  # Try to rescue from everything, setting the failed bit
  rescue_from(Exception) do |e|
    # Usually, the arguments are (user_id, dataset_id, task_id, ...), and so
    # task_id is self.arguments[2]. Try that here.
    #
    # FIXME GLOBALID WILL BREAK THIS
    # FIXME test this code
    task_id = arguments[2]
    if task_id
      begin
        Datasets::Task.find(task_id).mark_failed
      rescue ActiveRecord::RecordNotFound
        # Can't do anything, don't bother
      end
    end
  end

  # Returns true if this job can be run right now
  #
  # In general, this checks if all required external tools are available.
  # It defaults to true in the base class, and can be overridden by jobs
  # which are sometimes not available.
  #
  # @return [Boolean] true if this job can be run now
  def self.available?
    true
  end

  # Return how many datasets this job requires
  #
  # This method defaults to 1 in the base class, and can be overridden by
  # jobs which require more than one dataset to operate.
  #
  # @return [Integer] number of datasets needed to perform this job
  def self.num_datasets
    1
  end

  # Returns a translated string for this job
  #
  # This handles the i18n scoping for analysis job classes.  It will
  # pass fully scoped translation keys along unaltered.
  #
  # @param [String] key the translation to look up (e.g., '.short_desc')
  # @param [Hash] opts the options for the translation
  # @return [String] the translated message
  def self.t(key, opts = {})
    return I18n.t(key, opts) unless key[0] == '.'

    I18n.t("#{name.underscore.tr('/', '.')}#{key}", opts)
  end

  # Returns a translated string for this job
  #
  # We alias the class method as an instance method, to save keystrokes
  # when programming job classes.
  #
  # @param [String] key the translation to look up (e.g., '.short_desc')
  # @return [String] the translated message
  def t(key, opts = {})
    self.class.t(key, opts)
  end

  # True if this job produces a download
  #
  # If true (default), then links to results of tasks will produce links to
  # download the result_file from that task.  If not, then the link to the
  # task results will point to the 'results' view for this job.  Override
  # this method to return false if you want to use the 'results' view.
  #
  # @return [Boolean] true if task produces a download, false otherwise
  def self.download?
    true
  end

  # Get a list of all classes that are analysis jobs
  #
  # This method looks up all the defined job classes in `lib/jobs/analysis`
  # and returns them in a list so that we may loop over them (e.g., when
  # including all job-start markup).
  #
  # @return [Array<Class>] array of class objects
  def self.job_list
    # Get all the classes defined in the Jobs::Analysis module
    analysis_files = Dir[Rails.root.join('app', 'jobs', '*.rb')]
    classes = analysis_files.map do |f|
      next if %w(base_job.rb csv_job.rb
                 create_dataset_job.rb
                 destroy_dataset_job.rb
                 expire_tasks_job.rb).include?(File.basename(f))

      # This will raise a NameError if the class doesn't exist, but we want
      # that, because that means there's a file in app/jobs that doesn't
      # respect Rails' naming conventions.
      File.basename(f, '.rb').camelize.constantize
    end
    classes.compact!

    # Make sure that worked
    classes.each do |c|
      return [] unless c.is_a?(Class)
    end

    classes
  end

  # Add a concern to this job class
  #
  # Concerns are bundles of job code and views that can be mixed into
  # different analysis job tasks.  This is intended to support pieces of
  # functionality that will be shared across many different job types.
  #
  # @param [String] concern the concern to mix in
  # @return [void]
  def self.add_concern(concern)
    # Protect against calling this more than once, though that would be
    # really daft
    if concerns && concerns.include?(concern)
      fail ArgumentError, "#{concern} has already been included in #{name}"
    end

    # We want this to throw a NameError if it doesn't work; this would be
    # a programmer's mistake
    klass = ('Jobs::Analysis::Concerns::' + concern).constantize
    include klass

    # Add it to the tracking list so that we'll pick up its views
    self.concerns ||= []
    self.concerns << concern
  end

  # Get the list of paths for this class's job views
  #
  # We let analysis jobs ship their own job view templates. This function
  # returns the name of that directory to be prepended into the Rails
  # view search path.
  #
  # When a job mixes in a concern, this method also supports the addition
  # of concern views.
  #
  # @return [Array<String>] the template directories to be added
  def self.view_paths
    # This turns 'ExportCitationsJob' into 'export_citations'
    class_name = name.underscore[0...-4]
    ret = [Rails.root.join('lib', 'jobs', 'analysis', 'views', class_name)]

    if @concerns
      @concerns.each do |c|
        ret << Rails.root.join('lib', 'jobs', 'analysis', 'concerns',
                               'views', c.underscore)
      end
    end

    ret
  end

  # Returns the path to a particular view on the filesystem
  #
  # The arguments to this function are somewhat like the Rails render call.
  # One of either `:template` or `:partial` must be specified
  #
  # @param [Hash] args options for finding view
  # @option args [String] :template if specified, template to search for
  # @option args [String] :partial if specified, partial to search for
  # @option args [String] :format if specified, format to render (deafults
  #   to HTML)
  def self.view_path(args)
    if args[:template]
      args[:filename] = args[:template]
    elsif args[:partial]
      args[:filename] = "_#{args[:partial]}"
    else
      fail ArgumentError, 'view_path requires at least :template or :partial'
    end
    args[:format] ||= 'html'

    view_paths.each do |p|
      # Look for any of the extensions that we can currently render
      extensions = ActionView::Template.template_handler_extensions.join(',')
      glob = "#{args[:filename]}.#{args[:format]}.{#{extensions}}"
      matches = Dir.glob(File.join(p, glob))

      return matches[0] unless matches.empty?
    end

    nil
  end

  # Returns true if the given view exists for this job class
  #
  # @param [String] view the view to search for
  # @param [String] format the format to search for
  # @return [Boolean] true if the given job has the view requested
  def self.view?(view, format = 'html')
    !view_path(template: view, format: format).nil?
  end

  # The exception raised when we kill a job externally
  class JobKilledError < RuntimeError; end

  protected

  # Sets a variety of standard option variables
  #
  # Almost all analysis jobs have a `user_id`, `dataset_id`, and `task_id`
  # parameter.  This function ensures that they are valid, and then sets
  # and saves the name of the task to the content of the `.short_desc`
  # translation key. Finally, it starts the progress measurement.
  #
  # @param [String] user_id the user whose dataset we are to work on
  # @param [String] dataset_id the dataset to operate on
  # @param [String] task_id the task we're working from
  # @return [undefined]
  def standard_options(user_id, dataset_id, task_id)
    user = User.find(user_id)
    dataset = user.datasets.find(dataset_id)
    task = dataset.tasks.find(task_id)

    task.name = t('.short_desc')
    task.save

    task.at(0, 100, t('common.progress_initializing'))
  end

  # Returns the task object, possibly throwing an exception
  #
  # At any point, we could get a request to kill the current task, which is
  # expressed by deleting the task out from under us. To that end, we
  # always check the task before using it.
  #
  # @return [Datasets::Task] the task, if not deleted
  def get_task(task_id)
    fail JobKilledError unless Datasets::Task.exists?(task_id)
    Datasets::Task.find(task_id)
  end

  # Returns the dataset object, possibly throwing an exception
  # @return [Dataset] the dataset, if we haven't been killed
  def get_dataset(task_id)
    get_task(task_id).dataset
  end

  # Returns the user object, possibly throwing an exception
  # @return [User] the user, if we haven't been killed
  def get_user(task_id)
    get_dataset(task_id).user
  end

  class << self
    # @return [Array<String>] the concerns mixed into this job class
    attr_accessor :concerns
  end
end
