# -*- encoding : utf-8 -*-
require 'spec_helper'

describe WorkflowController do

  # N.B.: This is an ApplicationController test, but we have to spec it
  # in a real controller, as its implementation uses url_for().
  describe '#ensure_trailing_slash' do
    it 'adds a trailing slash when there is none' do
      request.env['REQUEST_URI'] = '/workflow'
      get :index, trailing_slash: false
      expect(response).to redirect_to('/workflow/')
    end

    it 'does not redirect when there is a trailing slash' do
      get :index, trailing_slash: true
      expect(response).not_to be_redirect
    end
  end

  describe '#index' do
    context 'given Solr results' do
      context 'when logged in' do
        before(:each) do
          @user = FactoryGirl.create(:user)
          sign_in @user

          get :index
        end

        it 'loads successfully' do
          expect(response).to be_success
        end

        it 'renders the dashboard' do
          expect(response).to render_template(:dashboard)
        end

        it 'sets the number of documents' do
          expect(assigns(:database_size)).to be
          expect(assigns(:database_size)).to eq(1042)
        end
      end

      context 'when not logged in' do
        before(:each) do
          get :index
        end

        it 'loads successfully' do
          expect(response).to be_success
        end

        it 'renders the index' do
          expect(response).to render_template(:index)
        end
      end
    end

    context 'when Solr fails' do
      it 'loads successfully' do
        stub_request(:any, /(127\.0\.0\.1|localhost)/).to_timeout
        get :index

        expect(response).to be_success
      end
    end
  end

  describe '#image' do
    context 'with an invalid id' do
      it 'returns a 404' do
        expect {
          get :image, id: '123456789'
        }.to raise_error(ActiveRecord::RecordNotFound)
      end
    end

    context 'with a valid id' do
      before(:each) do
        @asset = UploadedAsset.find_by(name: 'splash-low').to_param
        @id = @asset.to_param

        get :image, id: @id
      end

      it 'succeeds' do
        expect(response).to be_success
      end

      it 'returns a reasonable content type' do
        expect(response.content_type).to eq('image/png')
      end

      it 'sends some data' do
        expect(response.body.length).to be > 0
      end
    end
  end

end
