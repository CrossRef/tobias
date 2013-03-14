HOME = File.join(File.expand_path(File.dirname(__FILE__)), '..')

God::Contacts::Email.defaults do |d|
  d.from_email = 'labs@crossref.org'
  d.from_name = 'CrossRef Labs'
  d.delivery_method = :sendmail
end

God.contact(:email) do |c|
  c.name = 'labs'
  c.to_email = 'labs@crossref.org'
end

God.watch do |w|
  w.name = 'tobias-scheduler'
  w.group = 'tobias'
  w.dir = HOME
  w.start = 'bundle exec rake resque:scheduler'
  w.uid = 'tobias'
  w.gid = 'tobias'
  w.keepalive

  w.transition(:up, :start) do |on|
    on.condition(:process_exits) do |c|
      c.notify = 'labs'
    end
  end
end

def monitor_workers kind, count
  count.times do |c|
    God.watch do |w|
      w.name = "#{kind}-#{c}"
      w.group = kind
      w.env = {'QUEUE' => kind}
      w.dir = HOME
      w.start = 'bundle exec rake resque:work'
      w.uid = 'tobias'
      w.gid = 'tobias'
      w.keepalive

      w.transition(:up, :start) do |on|
        on.condition(:process_exits) do |c|
          c.notify = 'labs'
        end
      end
    end
  end
end

monitor_workers('harvest', 10)
monitor_workers('load', 20)

  
