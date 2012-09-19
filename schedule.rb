job_type :harvest, 'FROM=:from UNTIL=:until ACTION=:task bundle exec rake harvest'

every 2.days, :at => '11:00pm' do
  harvest 'dois', :from => (Date.today - 2), :until => (Date.today - 1)
end
