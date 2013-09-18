# -*- encoding : utf-8 -*-
require 'spec_helper'

describe Jobs::Analysis::ExportCitations, vcr: { cassette_name: 'solr_single' } do

  it_should_behave_like 'an analysis job with a file' do
    let(:job_params) { { format: :bibtex } }
  end

  before(:each) do
    @user = FactoryGirl.create(:user)
    @dataset = FactoryGirl.create(:full_dataset, entries_count: 10,
                                  working: true, user: @user)
    @task = FactoryGirl.create(:analysis_task, dataset: @dataset)
  end

  after(:each) do
    @task.destroy
  end

  context 'when an invalid format is specified' do
    it 'raises an exception' do
      expect {
        Jobs::Analysis::ExportCitations.perform(
          user_id: @user.to_param,
          dataset_id: @dataset.to_param,
          task_id: @task.to_param,
          format: :notaformat)
      }.to raise_error(ArgumentError)
    end
  end

  context 'when the format is a string',
          vcr: { cassette_name: 'solr_single' } do
    it 'works anyway' do
      expect {
        Jobs::Analysis::ExportCitations.perform(
          user_id: @user.to_param,
          dataset_id: @dataset.to_param,
          task_id: @task.to_param,
          format: 'bibtex')
      }.to_not raise_error
    end
  end

  context 'when all parameters are valid' do
    before(:each) do
      Jobs::Analysis::ExportCitations.perform(
        user_id: @user.to_param,
        dataset_id: @dataset.to_param,
        task_id: @task.to_param,
        format: :bibtex)
    end

    it 'names the task correctly' do
      expect(@dataset.analysis_tasks[0].name).to eq('Export as BibTeX')
    end

    it 'creates a proper ZIP file' do
      data = @dataset.analysis_tasks[0].result.file_contents('original')
      entries = 0
      Zip::InputStream.open(StringIO.new(data)) do |zis|
        while (entry = zis.get_next_entry)
          entries += 1
        end
      end
      expect(entries).to eq(10)
     end
  end

end
