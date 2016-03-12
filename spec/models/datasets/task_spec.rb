require 'spec_helper'

RSpec.describe Datasets::Task, type: :model do
  describe '#valid?' do
    context 'when no name is specified' do
      before(:example) do
        @task = build_stubbed(:task, name: nil)
      end

      it 'is not valid' do
        expect(@task).not_to be_valid
      end
    end

    context 'when no dataset is specified' do
      before(:example) do
        @task = build_stubbed(:task, dataset: nil)
      end

      it 'is not valid' do
        expect(@task).not_to be_valid
      end
    end

    context 'when no type is specified' do
      before(:example) do
        @task = build_stubbed(:task, job_type: nil)
      end

      it 'is not valid' do
        expect(@task).not_to be_valid
      end
    end

    context 'when dataset, type, and name are specified' do
      before(:example) do
        @task = create(:task)
      end

      it 'is valid' do
        expect(@task).to be_valid
      end
    end
  end

  describe '#template_path' do
    it 'works' do
      @task = create(:task, job_type: 'ExportCitationsJob')
      expect(@task.template_path('test')).to eq('jobs/export_citations_job/test')
    end
  end

  describe '#finished_at' do
    context 'when newly created' do
      before(:example) do
        @task = create(:task)
      end

      it 'is not set' do
        expect(@task.finished_at).to be_nil
      end
    end
  end

  describe '#failed' do
    context 'when newly created' do
      before(:example) do
        @task = create(:task)
      end

      it 'is false' do
        expect(@task.finished_at).to be_nil
      end
    end
  end

  describe '#json' do
    context 'with JSON available' do
      before(:example) do
        @task = create(:task, job_type: 'ExportCitationsJob')
        @task.files.create!(description: 'test',
                            short_description: 'test') do |f|
          f.from_string('{"abc":123}', filename: 'test.json',
                                       content_type: 'application/json')
        end
        @task.reload
      end

      it 'returns the JSON' do
        expect(@task.json).to eq('{"abc":123}')
      end
    end

    context 'with no JSON available' do
      before(:example) do
        @task = create(:task, job_type: 'ExportCitationsJob')
      end

      describe '#json' do
        it 'is nil' do
          expect(@task.json).to be_nil
        end
      end
    end
  end

  def create_task_with_file
    @task = create(:task)
    @file = create(:file, task: @task) do |f|
      f.from_string('test')
    end
    @task.reload
  end

  describe '#files' do
    context 'when a file is created' do
      before(:example) do
        create_task_with_file
      end

      after(:example) do
        @task.destroy
      end

      it 'has the right file length' do
        expect(@task.files.first.result_file_size).to eq(4)
      end

      it 'has the right contents' do
        expect(@task.files.first.result.file_contents(:original)).to eq('test')
      end

      it 'has the right mime type' do
        expect(@task.files.first.result_content_type.to_s).to eq('text/plain')
      end
    end
  end

  describe '.job_class' do
    context 'with a good class' do
      it 'returns the class' do
        klass = Datasets::Task.job_class('ExportCitationsJob')
        expect(klass).to eq(ExportCitationsJob)
      end
    end

    context 'with a bad class' do
      it 'raises an error' do
        expect {
          Datasets::Task.job_class('NotClass')
        }.to raise_error(ArgumentError)
      end
    end
  end

  describe '#job_class' do
    context 'with a good job_type' do
      it 'returns the class' do
        task = create(:task, job_type: 'ExportCitationsJob')
        klass = task.job_class
        expect(klass).to eq(ExportCitationsJob)
      end
    end

    context 'with a bad class' do
      it 'raises an error' do
        task = create(:task)
        expect {
          task.job_class
        }.to raise_error(ArgumentError)
      end
    end
  end

  describe '#job_id' do
    context 'without running anything' do
      it 'is nil' do
        task = create(:task, job_type: 'ExportCitationsJob')
        expect(task.job_id).to be_nil
      end
    end
  end

  describe '#que_job' do
    context 'without running anything' do
      it 'is nil' do
        task = create(:task, job_type: 'ExportCitationsJob')
        expect(task.que_job).to be_nil
      end
    end
  end
end
