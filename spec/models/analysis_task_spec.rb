# -*- encoding : utf-8 -*-
require 'spec_helper'

describe AnalysisTask do

  describe '#valid?' do
    context 'when no name is specified' do
      before(:each) do
        @task = FactoryGirl.build(:analysis_task, name: nil)
      end

      it 'is not valid' do
        expect(@task).not_to be_valid
      end
    end

    context 'when no dataset is specified' do
      before(:each) do
        @task = FactoryGirl.build(:analysis_task, dataset: nil)
      end

      it 'is not valid' do
        expect(@task).not_to be_valid
      end
    end

    context 'when no type is specified' do
      before(:each) do
        @task = FactoryGirl.build(:analysis_task, job_type: nil)
      end

      it 'is not valid' do
        expect(@task).not_to be_valid
      end
    end

    context 'when dataset, type, and name are specified' do
      before(:each) do
        @task = FactoryGirl.create(:analysis_task)
      end

      it 'is valid' do
        expect(@task).to be_valid
      end
    end
  end

  describe '#finished_at' do
    context 'when newly created' do
      before(:each) do
        @task = FactoryGirl.create(:analysis_task)
      end

      it 'is not set' do
        expect(@task.finished_at).to be_nil
      end
    end
  end

  describe '#failed' do
    context 'when newly created' do
      before(:each) do
        @task = FactoryGirl.create(:analysis_task)
      end

      it 'is false' do
        expect(@task.finished_at).to be_false
      end
    end
  end

  def create_task_with_file
    @task = FactoryGirl.create(:analysis_task)
    @task.result_file = Download.create_file('test.txt') do |file|
      file.write 'test'
    end
    @task.save

    @filename = @task.result_file.filename
  end

  describe '#result_file' do
    context 'when a file is created' do
      before(:each) do
        create_task_with_file
      end

      after(:each) do
        @task.destroy
      end

      it 'creates the file' do
        expect(File.exists?(@filename)).to be_true
      end

      it 'points to the right file' do
        expect(IO.read(@filename)).to eq('test')
      end
    end
  end

  describe '#destroy' do
    context 'when there is an associated file' do
      before(:each) do
        create_task_with_file
        @task.destroy
      end

      it 'deletes the file' do
        expect(File.exists?(@filename)).to be_false
      end
    end
  end

  describe '.job_class' do
    context 'with a good class' do
      it 'returns the class' do
        klass = AnalysisTask.job_class('ExportCitations')
        expect(klass).to eq(Jobs::Analysis::ExportCitations)
      end
    end

    context 'with a bad class' do
      it 'raises an error' do
        expect {
          AnalysisTask.job_class('NotClass')
        }.to raise_error(ArgumentError)
      end
    end
  end

  describe '#job_class' do
    context 'with a good job_type' do
      it 'returns the class' do
        task = FactoryGirl.create(:analysis_task, job_type: 'ExportCitations')
        klass = task.job_class
        expect(klass).to eq(Jobs::Analysis::ExportCitations)
      end
    end

    context 'with a bad class' do
      it 'raises an error' do
        task = FactoryGirl.create(:analysis_task)
        expect {
          task.job_class
        }.to raise_error(ArgumentError)
      end
    end
  end

end
