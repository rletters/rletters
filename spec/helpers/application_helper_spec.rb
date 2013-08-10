# -*- encoding : utf-8 -*-
require 'spec_helper'

SimpleCov.command_name 'spec:helpers' if defined?(SimpleCov)

describe ApplicationHelper do

  # Note that these tests are also testing our extension
  # I18n.translate_markdown, in lib/core_ext.
  describe '#translate_markdown' do
    context 'without a shortcut' do
      it 'renders Markdown in translations' do
        I18n.backend.store_translations :en, test_markdown: '# Testing #'

        html = helper.translate_markdown(:test_markdown)
        expect(html).to be
        expect(html).to have_tag('h1', text: 'Testing')
      end

      it 'works when called as t_md' do
        I18n.backend.store_translations :en, test_markdown: '# Testing #'

        html = helper.t_md(:test_markdown)
        expect(html).to be
        expect(html).to have_tag('h1', text: 'Testing')
      end
    end

    context 'with a shortcut' do
      before(:all) do
        I18n.backend.store_translations(
          :en,
          info: { spectest: { testing: '# Testing #' } }
        )

        @custom_filename = Rails.root.join('app', 'views', 'info', 'spectest.html.haml')
        File.open(@custom_filename, 'w') do |f|
          f.write('= translate_markdown(".testing")')
        end
      end

      after(:all) do
        File.delete(@custom_filename)
      end

      it 'renders Markdown in translations' do
        render template: 'info/spectest'
        expect(rendered).to have_tag('h1', text: 'Testing')
      end
    end
  end

end
