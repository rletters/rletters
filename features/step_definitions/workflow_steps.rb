
### WHEN ###
When(/^I start a new workflow analysis$/) do
  visit '/'
  click_link 'Start a new analysis'
end

When(/^I choose the (.*) task$/) do |task|
  map = {
    'plot dates' => 'How has the frequency of a term changed over time?',
    'Craig Zeta' => 'Given two sets of articles, what words mark out an article'
  }

  link_text = map[task]
  expect(link_text).to be

  click_link link_text
end

When(/^I confirm the choice$/) do
  click_link 'Start'
end

When(/^I link the dataset$/) do
  expect(@dataset).to be

  click_link 'Link an already created dataset'
  select @dataset.name, from: 'link_dataset_id'
  click_button 'Link dataset'

  # There's trouble with the modal dialog here acting unreliably; circumvent
  # it by going back to the workflow#activate page
  @user.reload
  visit workflow_activate_path(class: @user.workflow_class)
end

When(/^I link the other dataset$/) do
  expect(@other_dataset).to be

  click_link 'Link an already created dataset'
  select @other_dataset.name, from: 'link_dataset_id'
  click_button 'Link dataset'

  # There's trouble with the modal dialog here acting unreliably; circumvent
  # it by going back to the workflow#activate page
  @user.reload
  visit workflow_activate_path(class: @user.workflow_class)
end

When(/^I choose to create a new dataset$/) do
  click_link 'Create another dataset'
end

When(/^I confirm the data$/) do
  @user.reload
  visit workflow_activate_path(class: @user.workflow_class)

  within('.main') do
    if page.has_link? 'Start Analysis'
      with_resque { click_link 'Start Analysis' }
    else
      click_link 'Set Job Options'
    end
  end
end

When(/^I abort the workflow$/) do
  click_link 'Abort Building Analysis'
end

### THEN ###
Then(/^I should be able to fetch the workflow results$/) do
  within('nav') { click_link 'Fetch Results' }
  expect(page).to have_selector('td', text: @dataset.name)
end

Then(/^I should no longer be building a workflow$/) do
  expect(page).not_to have_link('Current Analysis')
end

Then(/^I should be able to view the result data$/) do
  click_link 'View Results'
  expect(page).to have_link('Download in CSV format')
end
