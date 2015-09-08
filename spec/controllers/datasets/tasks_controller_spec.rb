require 'rails_helper'

# Mock job for task controller tests
class ControllerJob < BaseJob
  def perform; end
end

RSpec.describe Datasets::TasksController, type: :controller do
  before(:example) do
    @user = create(:user)
    sign_in @user

    @dataset = create(:full_dataset, user: @user, working: true)
  end

  describe '#index' do
    context 'with a valid dataset' do
      it 'loads successfully' do
        get :index, dataset_id: @dataset.to_param
        expect(response).to be_success
      end

      it 'assigns dataset' do
        get :index, dataset_id: @dataset.to_param
        expect(assigns(:dataset)).to eq(@dataset)
      end
    end

    context 'with a disabled dataset' do
      before(:example) do
        @disabled = create(:dataset, user: @user, name: 'Disabled',
                                     disabled: true)
      end

      it 'raises an exception' do
        expect {
          get :index, dataset_id: @disabled.to_param
        }.to raise_error(ActiveRecord::RecordNotFound)
      end
    end

    context 'with an invalid dataset' do
      it 'raises an error' do
        expect {
          get :index, dataset_id: 'asdf'
        }.to raise_error(ActiveRecord::RecordNotFound)
      end
    end
  end

  describe '#new' do
    context 'when an invalid class is passed' do
      it 'raises an exception' do
        expect {
          get :new, dataset_id: @dataset.to_param, class: 'ThisIsNoClass'
        }.to raise_error(ArgumentError)
      end
    end

    context 'when Base is passed' do
      it 'raises an exception' do
        expect {
          get :new, dataset_id: @dataset.to_param, class: 'Base'
        }.to raise_error(ArgumentError)
      end
    end

    context 'with a disabled dataset' do
      before(:example) do
        @disabled = create(:dataset, user: @user, name: 'Disabled',
                                     disabled: true)
      end

      it 'raises an exception' do
        expect {
          get :new, dataset_id: @disabled.to_param, class: 'ArticleDates'
        }.to raise_error(ActiveRecord::RecordNotFound)
      end
    end

    context 'with valid parameters' do
      it 'loads successfully' do
        get :new, dataset_id: @dataset.to_param, class: 'ExportCitationsJob',
                  job_params: { format: 'bibtex' }

        expect(response).to be_success
      end
    end

    context 'when two datasets are needed and two are provided' do
      it 'loads successfully' do
        @dataset_2 = create(:full_dataset, user: @user, working: true)
        get :new, dataset_id: @dataset.to_param, class: 'CraigZetaJob',
                  job_params: { other_datasets: [@dataset_2.to_param] }

        expect(response).to be_success
      end
    end

    context 'when two datasets are needed and one is provided' do
      it 'raises and error' do
        @dataset_2 = create(:full_dataset, user: @user, working: true)
        expect {
          get :new, dataset_id: @dataset.to_param, class: 'CraigZetaJob'
        }.to raise_error(ArgumentError)
      end
    end
  end

  describe '#create' do
    context 'when an invalid class is passed' do
      it 'raises an exception' do
        expect {
          post :create, dataset_id: @dataset.to_param, class: 'ThisIsNoClass'
        }.to raise_error(ArgumentError)
      end
    end

    context 'when Base is passed' do
      it 'raises an exception' do
        expect {
          post :create, dataset_id: @dataset.to_param, class: 'Base'
        }.to raise_error(ArgumentError)
      end
    end

    context 'with a disabled dataset' do
      before(:example) do
        @disabled = create(:dataset, user: @user, name: 'Disabled',
                                     disabled: true)
      end

      it 'raises an exception' do
        expect {
          post :create, dataset_id: @disabled.to_param, class: 'ArticleDates'
        }.to raise_error(ActiveRecord::RecordNotFound)
      end
    end

    context 'when a valid class with no params is passed' do
      it 'does not raise an exception' do
        expect {
          post :create, dataset_id: @dataset.to_param, class: 'NamedEntitiesJob'
        }.not_to raise_error
      end

      it 'enqueues a job' do
        expect {
          post :create, dataset_id: @dataset.to_param, class: 'NamedEntitiesJob'
        }.to enqueue_a(NamedEntitiesJob)
      end

      it 'redirects to the dataset page' do
        post :create, dataset_id: @dataset.to_param, class: 'NamedEntitiesJob'
        expect(response).to redirect_to(dataset_path(@dataset))
      end
    end

    context 'when a valid class and params are passed' do
      it 'does not raise an exception' do
        expect {
          post :create, dataset_id: @dataset.to_param,
                        class: 'ExportCitationsJob',
                        job_params: { format: 'bibtex' }
        }.not_to raise_error
      end

      it 'enqueues a job' do
        expect {
          post :create, dataset_id: @dataset.to_param,
                        class: 'ExportCitationsJob',
                        job_params: { format: 'bibtex' }
        }.to enqueue_a(ExportCitationsJob)
      end

      it 'redirects to the dataset page' do
        post :create, dataset_id: @dataset.to_param, class: 'ExportCitationsJob',
                      job_params: { format: 'bibtex' }
        expect(response).to redirect_to(dataset_path(@dataset))
      end
    end

    context 'when a valid class/params are passed at the end of a workflow' do
      before(:example) do
        @user.workflow_active = true
        @user.workflow_datasets = [@dataset.to_param]
        @user.workflow_class = 'ExportCitationsJob'
        @user.save

        post :create, dataset_id: @dataset.to_param, class: 'ExportCitationsJob',
                      job_params: { format: 'bibtex' }

        @user.reload
      end

      it 'clears the workflow parameters' do
        expect(@user.workflow_active).to be false
        expect(@user.workflow_class).to be_nil
        expect(@user.workflow_datasets).to be_blank
      end

      it 'redirects to the root' do
        expect(response).to redirect_to(root_path)
      end
    end
  end

  describe '#show' do
    before(:example) do
      @task = create(:task, dataset: @dataset, job_type: 'ExportCitationsJob')
    end

    context 'when an invalid task ID is passed' do
      it 'raises an exception' do
        expect {
          get :show, dataset_id: @dataset.to_param,
                     id: '12345678', view: 'test'
        }.to raise_error(ActiveRecord::RecordNotFound)
      end
    end

    context 'with a disabled dataset' do
      before(:example) do
        @disabled = create(:dataset, user: @user, name: 'Disabled',
                                     disabled: true)
      end

      it 'raises an exception' do
        expect {
          get :show, dataset_id: @disabled.to_param, id: @task.to_param, view: '_params'
        }.to raise_error(ActiveRecord::RecordNotFound)
      end
    end

    context 'when rendering a job view' do
      # We want to let it render views, to make sure that the search path
      # addition is working properly
      render_views

      it 'raises an exception for missing views' do
        expect {
          get :show, dataset_id: @dataset.to_param,
                     id: @task.to_param, view: 'notaview'
        }.to raise_error(ActionView::MissingTemplate)
      end

      it 'does not raise an exception' do
        expect {
          get :show, dataset_id: @dataset.to_param,
                     id: @task.to_param, view: '_params'
        }.not_to raise_error
      end

      it 'renders the right view' do
        get :show, dataset_id: @dataset.to_param,
                   id: @task.to_param, view: '_params'
        expect(response.body).to include('<option')
      end

      it 'escapes JSON if some is available' do
        @task_2 = create(:task, dataset: @dataset, job_type: 'ExportCitationsJob')

        ios = StringIO.new('abc"123')
        file = Paperclip.io_adapters.for(ios)
        file.original_filename = 'test.txt'
        file.content_type = 'text/plain'

        @task_2.files.create(description: 'test', short_description: 'test',
                             result: file)
        @task_2.reload

        get :show, dataset_id: @dataset.to_param,
                   id: @task_2.to_param, view: '_params'

        expect(assigns(:json)).to eq('abc"123')
        expect(assigns(:json_escaped)).to eq('abc\"123')
      end
    end

    context 'when fetching a task download' do
      before(:example) do
        ExportCitationsJob.new.perform(
          @task,
          format: 'bibtex'
        )
      end

      it 'loads successfully' do
        get :show, dataset_id: @dataset.to_param, id: @task.to_param
        expect(response).to be_success
      end

      it 'has the right MIME type' do
        get :show, dataset_id: @dataset.to_param, id: @task.to_param
        expect(response.content_type).to eq('application/zip')
      end

      it 'sends some data' do
        get :show, dataset_id: @dataset.to_param, id: @task.to_param
        expect(response.body.length).to be > 0
      end
    end

    context 'with neither a view nor a download' do
      before(:example) do
        @task_2 = create(:task, dataset: @dataset, job_type: 'ControllerJob')
      end

      it 'raises an error' do
        expect {
          get :show, dataset_id: @dataset.to_param, id: @task.to_param
        }.to raise_error(ActiveRecord::RecordNotFound)
      end
    end
  end

  describe '#destroy' do
    context 'when an invalid task ID is passed' do
      it 'raises an exception' do
        expect {
          get :destroy, dataset_id: @dataset.to_param, id: '12345678'
        }.to raise_error(ActiveRecord::RecordNotFound)
      end
    end

    context 'with a disabled dataset' do
      before(:example) do
        @disabled = create(:dataset, user: @user, name: 'Disabled',
                                     disabled: true)
        @task = create(:task, dataset: @disabled, job_type: 'ExportCitationsJob')
      end

      it 'raises an exception' do
        expect {
          get :destroy, dataset_id: @disabled.to_param, id: @task.to_param
        }.to raise_error(ActiveRecord::RecordNotFound)
      end
    end

    context 'when a valid task ID is passed' do
      before(:example) do
        request.env['HTTP_REFERER'] = workflow_fetch_path
        @task = create(:task, dataset: @dataset, job_type: 'ExportCitationsJob')
      end

      it 'deletes the task' do
        expect {
          get :destroy, dataset_id: @dataset.to_param, id: @task.to_param
        }.to change { @dataset.tasks.count }.by(-1)
      end

      it 'redirects to the prior page' do
        get :destroy, dataset_id: @dataset.to_param, id: @task.to_param
        expect(response).to redirect_to(workflow_fetch_path)
      end
    end
  end
end
