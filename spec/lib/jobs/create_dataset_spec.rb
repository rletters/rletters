# -*- encoding : utf-8 -*-
require 'spec_helper'

describe Jobs::CreateDataset do
  
  fixtures :users
  
  context "when user is invalid" do
    it "raises an exception" do
      expect {
        Jobs::CreateDataset.new('123123123123', 'Test Dataset', 
          '*:*', nil, 'precise').perform
      }.to raise_error(ActiveRecord::RecordNotFound)
    end
  end
  
  context "when Solr fails" do
    before(:each) do
      SolrExamples.stub :error
    end
    
    it "raises an exception" do
      expect {
        Jobs::CreateDataset.new(users(:alice).to_param, 'Test Dataset', 
          '*:*', nil, 'precise').perform        
      }.to raise_error
      
      users(:alice).datasets.should have(0).items
    end
  end
  
  context "given precise_all Solr results" do
    before(:each) do
      SolrExamples.stub :dataset_precise_all
      Jobs::CreateDataset.new(users(:alice).to_param, 'Test Dataset', 
        '*:*', nil, 'precise').perform
    end
    
    it "creates a dataset" do
      users(:alice).datasets.should have(1).items
      users(:alice).datasets[0].should be
    end
    
    it "puts the right number of items in the dataset" do
      users(:alice).datasets[0].entries.should have(10).items
    end
  end
  
  context "given precise_with_facet_koltz Solr results" do
    before(:each) do
      SolrExamples.stub :dataset_precise_with_facet_koltz
      Jobs::CreateDataset.new(users(:alice).to_param, 'Test Dataset',
        '*:*', ['authors_facet:"Amanda M. Koltz"'], 'precise').perform
    end
    
    it "creates a dataset" do
      users(:alice).datasets.should have(1).items
      users(:alice).datasets[0].should be
    end
    
    it "puts the right number of items in the dataset" do
      users(:alice).datasets[0].entries.should have(1).items
    end
  end
  
  context "given search_diversity Solr results" do
    before(:each) do
      SolrExamples.stub :dataset_search_diversity
      Jobs::CreateDataset.new(users(:alice).to_param, 'Test Dataset',
        'diversity', nil, 'standard').perform
    end
    
    it "creates a dataset" do
      users(:alice).datasets.should have(1).items
      users(:alice).datasets[0].should be
    end
    
    it "puts the right number of items in the dataset" do
      users(:alice).datasets[0].entries.should have(1).items
    end
  end
  
  context "given large Solr dataset" do
    before(:each) do
      SolrExamples.stub [ :long_query_one, :long_query_two, :long_query_three ]
      Jobs::CreateDataset.new(users(:alice).to_param, 'Long Dataset',
        '*:*', nil, 'precise').perform
    end
    
    it "creates a dataset" do
      users(:alice).datasets.should have(1).items
      users(:alice).datasets[0].should be
    end
    
    it "puts the right number of items in the dataset" do
      users(:alice).datasets[0].entries.should have(2300).items
    end
  end
  
end
