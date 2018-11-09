jail_path = Chef::Config['file_cache_path'] + "/standalone_dns"

cookbook_file "#{jail_path}/add_compute_subnet.py" do
  source "add_compute_subnet.py"
  owner "root"
  group "root"
  mode "0700"
  action :create
end

if not node["appcatalog"].nil? 
    if not node["appcatalog"]["compute_subnet"].nil?
        execute "add_compute_subnet.py" do
            command "python #{jail_path}/add_compute_subnet.py #{node["appcatalog"]["compute_subnet"]} > #{jail_path}/add_compute_subnet.log"
            not_if 'grep "#The following was added for the separate compute subnet." /etc/hosts'
        end
    end
end

# add custom autoscaling

autostart_script = "#{node[:cyclecloud][:bootstrap]}/gridengine/appcatalog_autostart.py" 
cookbook_file "#{autostart_script}" do
    source "appcatalog_autostart.py"
    mode "0700"
    owner "root"
    group "root"
end

cron "appcatalog_autostart" do
    command "#{node[:cyclecloud][:bootstrap]}/cron_wrapper.sh #{autostart_script} >> /var/log/appcatalog_autostart.log"
end

# stage prolog file for environment variables for jobs
sgeroot = node[:gridengine][:root]
execute "setup_prolog" do
    command "#{node[:cyclecloud][:bootstrap]}/cron_wrapper.sh qconf -mattr queue prolog 'sgeadmin@#{sgeroot}/prolog_env_var.sh' all.q"
    action :nothing 
end
cookbook_file "#{sgeroot}/prolog_env_var.sh" do
    source "prolog_env_var.sh"
    mode "0755"
    owner "root"
    group "root"
    notifies :run, 'execute[setup_prolog]', :immediately
end

# Stage epilog script that sends results into log analytics

execute "setup_epilog" do
    command "#{node[:cyclecloud][:bootstrap]}/cron_wrapper.sh qconf -mattr queue epilog '#{sgeroot}/setup_epilog.sh' all.q"
    action :nothing 
end
cookbook_file "#{sgeroot}/submit_log_analytics.sh" do
    source "submit_log_analytics.sh"
    mode "0755"
    owner "root"
    group "root"
    notifies :run, 'execute[setup_epilog]', :immediately
end