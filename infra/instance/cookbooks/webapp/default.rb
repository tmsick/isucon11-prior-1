include_cookbook 'systemd'
include_cookbook 'repository'

# execute 'rm -rf /home/isucon/webapp'

execute 'install webapp' do
  command <<-EOS
  rm -rf /home/isucon/webapp
  cp -a /home/isucon/src/github.com/isucon/isucon11-sc/webapp /home/isucon/webapp
  cp /home/isucon/src/github.com/isucon/isucon11-sc/REVISION /home/isucon/webapp/REVISION
  EOS
  user 'isucon'
  cwd '/home/isucon'
  not_if 'test -d /home/isucon/webapp && test -f /home/isucon/webapp/REVISION && test $(cat /home/isucon/webapp/REVISION) = $(cat /home/isucon/src/github.com/isucon/isucon11-sc/webapp/REVISION)'

  notifies :run, 'execute[setup db]', :immediately
  notifies :run, 'execute[bundle install]', :immediately
  notifies :restart, 'service[web-ruby]'
end

execute 'setup db' do
  action :nothing
  command <<-EOS
  cat *.sql | mysql -uroot
  EOS
  cwd '/home/isucon/webapp/sql'
end

execute 'bundle install' do
  action :nothing
  command <<-EOS
  /home/isucon/.x bundle config set deployment true
  /home/isucon/.x bundle config set path vendor/bundle
  /home/isucon/.x bundle install -j8
  /home/isucon/.x bundle config set deployment false
  EOS
  user 'isucon'
  cwd '/home/isucon/webapp/ruby'
  not_if 'cd /home/isucon/webapp/ruby && test -e .bundle && /home/isucon/.x bundle check'
  notifies :restart, 'service[web-ruby]'
end

execute '/home/isucon/.x bundle config set deployment false' do
  user 'isucon'
  cwd '/home/isucon/webapp/ruby'
  only_if 'cd /home/isucon/webapp/ruby && /home/isucon/.x bundle config get --parseable deployment | grep "deployment=true"'
end

remote_file '/home/isucon/env' do
  owner 'isucon'
  group 'isucon'
  mode  '0644'
end

remote_file '/etc/systemd/system/web-ruby.service' do
  owner 'root'
  group 'root'
  mode  '0644'
  notifies :run, 'execute[systemctl daemon-reload]', :immediately
  notifies :restart, 'service[web-ruby]'
end

service 'web-ruby' do
  action [:enable, :start]
end