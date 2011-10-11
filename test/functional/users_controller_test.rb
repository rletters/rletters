# -*- encoding : utf-8 -*-
require 'test_helper'

SimpleCov.command_name 'test:functionals'

class UsersControllerTest < ActionController::TestCase
  setup do
    @user = users(:john)
  end

  test "should get index (to login)" do
    get :index
    assert_redirected_to users_login_path
  end

  test "should get login" do
    get :login
    assert_response :success
    assert_select 'h3', "Log in to #{APP_CONFIG['app_name']}"
  end

  test "should create user" do
    assert_difference('User.count') do
      post :create, :user => { :name => 'New User Test', :email => 'new@user.com', :identifier => 'https://newuser.com', :per_page => 10, :language => 'es-MX' }
    end

    assert_redirected_to datasets_path
    assert_not_nil session[:user]
  end

  # Attempting to POST an invalid user should make the form
  # appear, with errors
  test "should not create invalid user" do
    assert_no_difference('User.count') do
      post :create, :user => { :name => 'New User Test', :email => 'this isabademail', :identifier => 'notaurl' }
    end

    assert_response :success
    assert_select 'form' do
      assert_select 'ul[data-theme=e]'
    end
  end
  
  # POSTing an invalid user is the only way to test the form on
  # the "new" template.
  test "should fill in the user's default language on the form" do
    @request.env['HTTP_ACCEPT_LANGUAGE'] = "es-mx,es;q=0.5"
    post :create, :user => { :name => 'New User Test', :email => 'this is a bad email', :identifier => 'notaurl' }
    assert_response :success
    assert_select 'select[id=user_language]' do
      assert_select 'option[value=es-MX][selected=selected]'
    end
  end

  test "should update user" do
    session[:user] = users(:john)
    post :update, :id => users(:john), :user => { :name => 'Not Johns Name', :email => 'jdoe@gmail.com', :identifier => 'https://google.com/profiles/johndoe' }
    assert_equal "Not Johns Name", User.find(users(:john).id).name
  end

  test "should fail to invalidly update user" do
    session[:user] = users(:john)
    post :update, :id => users(:john), :user => { :name => 'John Doe', :email => 'thisisnotan.email', :identifier => 'https://google.com/profiles/johndoe' }

    assert_response :success
    assert_select 'form' do
      assert_select 'li[data-theme=e]'
    end
  end

  # You shouldn't be able to load the RPX page without posting the
  # RPX data blob to it
  test "should not be able to load RPX page" do
    assert_raise(RPXNow::ApiError) do
      get :rpx
    end
  end

  test "should blank user on logout" do
    session[:user] = users(:john)
    get :logout
    assert_nil session[:user]
  end

  test "should redirect to search on logout" do
    session[:user] = users(:john)
    get :logout
    assert_redirected_to root_url
  end

  test "should redirect from logout if not logged in" do
    session[:user] = nil
    get :logout
    assert_redirected_to :controller => 'users', :action => 'index'
  end

  test "should redirect from update if not logged in" do
    session[:user] = nil
    get :update
    assert_redirected_to :controller => 'users', :action => 'index'
  end

  # We explicitly can't get a functional test for users#rpx, because
  # there's no way to mock the interaction with the Janrain server.
end
