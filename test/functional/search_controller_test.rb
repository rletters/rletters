# -*- encoding : utf-8 -*-
require 'test_helper'

class SearchControllerTest < ActionController::TestCase
  test "should get index" do
    stub_solr_response :standard_empty_search
    get :index
    assert_response :success
  end

  test "should set documents variable" do
    stub_solr_response :precise_all_docs
    get :index
    assert_not_nil assigns(:documents)
    assert_equal 10, assigns(:documents).count
  end

  test "should display number of documents found" do
    stub_solr_response :precise_all_docs
    get :index
    assert_select 'li', '10 articles in database'
  end

  test "should display correctly when no documents found" do
    stub_solr_response :standard_empty_search
    get :index, { :q => 'shatner' }
    assert_select 'li', 'no articles found'
  end

  test "should display search text in search box" do
    stub_solr_response :standard_empty_search
    get :index, { :q => 'shatner' }
    assert_select 'input[value=shatner]'
  end

  test "should display advanced search placeholder" do
    stub_solr_response :precise_year_2009
    get :index, { :precise => 'true', :q => 'year:2009' }
    assert_select 'input[value=(advanced search)]'
  end

  test "should display document details (default citation format)" do
    stub_solr_response :precise_all_docs
    get :index
    assert_select 'div.leftcolumn ul li:nth-of-type(3)' do
      assert_select 'h3', 'Parental and Mating Effort: Is There Necessarily a Trade-Off?'
      assert_select 'p:first-of-type', 'Kelly A. Stiver, Suzanne H. Alonzo'
      assert_select 'p:last-of-type', "Ethology, Vol. 115,\n(2009),\npp. 1101-1126"
    end
  end

  test "should display document details (chicago format)" do
    stub_solr_response :precise_all_docs
    session[:user] = users(:john)
    get :index
    assert_select 'div.leftcolumn ul li:nth-of-type(7)', "Botero, Carlos A., Andrew E. Mudge, Amanda M. Koltz, Wesley M. Hochachka, and Sandra L. Vehrencamp. 2008. “How Reliable are the Methods for Estimating Repertoire Size?”. Ethology 114: 1227-1238."
  end

  test "should show login prompt if not logged in" do
    stub_solr_response :standard_empty_search
    session[:user] = nil
    get :index
    assert_select 'li[data-theme=e]', 'Log in to analyze results!'
  end

  test "should show create-dataset prompt if logged in" do
    stub_solr_response :standard_empty_search
    session[:user] = users(:john)
    get :index
    assert_select 'li', 'Create dataset from search'
  end

  test "should show author facets" do
    stub_solr_response :precise_all_docs
    get :index
    assert_select 'div.rightcolumn ul:nth-of-type(3) li:nth-of-type(2)', 'Amanda M. Koltz1' do
      assert_select "a[href=#{search_path(:fq => [ 'authors_facet:"Amanda M. Koltz"' ])}]"
      assert_select 'span.ui-li-count', '1'
    end
  end

  test "should show journal facets" do
    stub_solr_response :precise_all_docs
    get :index
    # We show five author facet choices, then the journal facet, which is number 6.
    assert_select 'div.rightcolumn ul:nth-of-type(3) li:nth-of-type(8)', 'Ethology10' do
      assert_select "a[href=#{search_path(:fq => [ 'journal_facet:"Ethology"' ])}]"
      assert_select 'span.ui-li-count', '10'
    end
  end

  test "should show year facets" do
    stub_solr_response :precise_all_docs
    get :index
    # We show five author facet choices, then the journal facet, then the year facets by count
    assert_select 'div.rightcolumn ul:nth-of-type(3) li:nth-of-type(12)', '1990–19991' do
      assert_select "a[href=#{search_path(:fq => [ 'year:[1990 TO 1999]' ])}]"
      assert_select 'span.ui-li-count', '1'
    end
  end
  
  test "should parse 2010-* year facet correctly" do
    stub_solr_response :precise_all_docs
    get :index
    # We show five author facet choices, then the journal facet, then the year facets by count
    assert_select 'div.rightcolumn ul:nth-of-type(3) li:nth-of-type(11)', '2010 and later2' do
      assert_select "a[href=#{search_path(:fq => [ 'year:[2010 TO *]' ])}]"
      assert_select 'span.ui-li-count', '2'
    end    
  end
  
  test "should parse *-1790 year facet correctly" do
    stub_solr_response :precise_old_docs
    get :index
    # We show five author facet choices, then the journal facet, then the year facets by count
    assert_select 'div.rightcolumn ul:nth-of-type(3) li:nth-of-type(13)', 'Before 18001' do
      assert_select "a[href=#{search_path(:fq => [ 'year:[* TO 1799]' ])}]"
      assert_select 'span.ui-li-count', '1'
    end
  end

  test "should display remove all link with facets" do
    stub_solr_response :precise_with_facet_koltz
    get :index, { :fq => [ 'authors_facet:"Amanda M. Koltz"' ] }
    assert_select 'div.rightcolumn ul:nth-of-type(3) li:nth-of-type(2)', 'Remove All' do
      assert_select "a[href=#{search_path}]"
    end
  end

  test "should display specific remove facet links" do
    stub_solr_response :precise_facet_author_and_journal
    get :index, { :fq => [ 'authors_facet:"Amanda M. Koltz"', 'journal_facet:"Ethology"' ] }
    assert_select 'div.rightcolumn ul:nth-of-type(3) li:nth-of-type(3)', 'Authors: Amanda M. Koltz' do
      assert_select "a[href=#{search_path(:fq => [ 'journal_facet:"Ethology"' ])}]"
    end
  end

  test "should correctly parse page, per_page in index" do
    default_sq = { :q => "*:*", :qt => "precise" }
    options = { :offset => 20, :limit => 20 }
    Document.expects(:find_all_by_solr_query).with(default_sq, options).returns([])

    get :index, { :page => "1", :per_page => "20" }
    assert_equal 0, assigns(:documents).count
  end

  test "should correctly eliminate blank params" do
    params = { :q => '', :precise => '' }
    ret = @controller.search_params_to_solr_query(params)
    assert_equal '*:*', ret[:q]
    assert_equal 'precise', ret[:qt]
  end

  test "should copy over faceted browsing paramters" do
    params = { :q => "*:*", :precise => "true", :fq => [ "authors_facet:W. Shatner", "journal_facet:Astrobiology" ] }
    ret = @controller.search_params_to_solr_query(params)
    assert_equal 'authors_facet:W. Shatner', ret[:fq][0]
    assert_equal 'journal_facet:Astrobiology', ret[:fq][1]
  end

  test "should put together empty precise search correctly" do
    params = { :q => '', :precise => 'true' }
    ret = @controller.search_params_to_solr_query(params)
    assert_equal '*:*', ret[:q]
    assert_equal 'precise', ret[:qt]
  end

  test "should copy generic precise search content correctly" do
    params = { :q => 'test', :precise => 'true' }
    ret = @controller.search_params_to_solr_query(params)
    assert_equal 'test', ret[:q]
  end

  test "should mix in verbatim search parameters correctly" do
    params = { :precise => 'true', :authors => 'W. Shatner', 
      :volume => '30', :number => '5', :pages => '300-301' }
    ret = @controller.search_params_to_solr_query(params)
    assert ret[:q].include? 'authors:(W. Shatner)'
    assert ret[:q].include? 'volume:(30)'
    assert ret[:q].include? 'number:(5)'
    assert ret[:q].include? 'pages:(300-301)'
  end

  test "should handle fuzzy params as verbatim without type set" do
    params = { :precise => 'true', :journal => 'Astrobiology',
      :title => 'Testing with Spaces', :fulltext => 'alien' }
    ret = @controller.search_params_to_solr_query(params)
    assert ret[:q].include? 'journal:(Astrobiology)'
    assert ret[:q].include? 'title:(Testing with Spaces)'
    assert ret[:q].include? 'fulltext:(alien)'
  end

  test "should handle fuzzy params with type set to verbatim" do
    params = { :precise => 'true', :journal => 'Astrobiology',
      :journal_type => 'exact', :title => 'Testing with Spaces',
      :title_type => 'exact', :fulltext => 'alien',
      :fulltext_type => 'exact' }
    ret = @controller.search_params_to_solr_query(params)
    assert ret[:q].include? 'journal:(Astrobiology)'
    assert ret[:q].include? 'title:(Testing with Spaces)'
    assert ret[:q].include? 'fulltext:(alien)'
  end

  test "should handle fuzzy params with type set to fuzzy" do
    params = { :precise => 'true', :journal => 'Astrobiology',
      :journal_type => 'fuzzy', :title => 'Testing with Spaces',
      :title_type => 'fuzzy', :fulltext => 'alien',
      :fulltext_type => 'fuzzy' }
    ret = @controller.search_params_to_solr_query(params)
    assert ret[:q].include? 'journal_search:(Astrobiology)'
    assert ret[:q].include? 'title_search:(Testing with Spaces)'
    assert ret[:q].include? 'fulltext_search:(alien)'
  end

  test "should handle only year_start" do
    params = { :precise => 'true', :year_start => '1900' }
    ret = @controller.search_params_to_solr_query(params)
    assert ret[:q].include? 'year:(1900)'
  end

  test "should handle only year_end" do
    params = { :precise => 'true', :year_end => '1900' }
    ret = @controller.search_params_to_solr_query(params)
    assert ret[:q].include? 'year:(1900)'
  end

  test "should handle year range" do
    params = { :precise => 'true', :year_start => '1900', :year_end => '1910' }
    ret = @controller.search_params_to_solr_query(params)
    assert ret[:q].include? 'year:([1900 TO 1910])'
  end

  test "should correctly copy dismax search" do
    params = { :q => 'test' }
    ret = @controller.search_params_to_solr_query(params)
    assert_equal 'test', ret[:q]
  end
  
  test "should render show-document page" do
    stub_solr_response :precise_one_doc
    get :show, { :id => '00972c5123877961056b21aea4177d0dc69c7318' }
    assert_response :success
    assert_not_nil assigns(:document)
    assert_select 'li', 'Document details'
    assert_select 'ul li:nth-child(2) h3', 'How Reliable are the Methods for Estimating Repertoire Size?'
  end
  
  test "should have DOI link" do
    stub_solr_response :precise_one_doc
    get :show, { :id => '00972c5123877961056b21aea4177d0dc69c7318' }
    assert_response :success
    assert_not_nil assigns(:document)
    assert_select 'ul[data-inset=true]' do
      assert_select 'li' do
        assert_select "a[href='http://dx.doi.org/10.1111/j.1439-0310.2008.01576.x']"
      end
    end
  end
  
  test "should get links page" do
    stub_solr_response :precise_one_doc
    get :links, { :id => '00972c5123877961056b21aea4177d0dc69c7318' }
    assert_response :success
    assert_not_nil assigns(:document)
  end
  
  test "should have redirect links" do
    stub_solr_response :precise_one_doc
    get :links, { :id => '00972c5123877961056b21aea4177d0dc69c7318' }
    unless APP_CONFIG['mendeley_key'].blank?
      assert_select "ul li:nth-last-child(2)" do
        assert_select "a[href='#{mendeley_redirect_path(:id => '00972c5123877961056b21aea4177d0dc69c7318')}']"
      end
    end
    assert_select "ul li:nth-last-child(1)" do
      assert_select "a[href='#{citeulike_redirect_path(:id => '00972c5123877961056b21aea4177d0dc69c7318')}']"
    end    
  end
end
