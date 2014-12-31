def default_value(val, default)
  if val.nil?
    return default
  end
  if val.is_a? Numeric
    return BigDecimal.new(val).to_i
  elsif val.downcase === 'true'
    return true
  elsif val.downcase === 'false'
    return false
  else
    return val
  end
end


iptablesConfig = {
  :http => default_value(ENV['thttp_enabled'], true),
  :https => default_value(ENV['thttps_enabled'], true),
  :dns => default_value(ENV['tdns_enabled'], true),
}

template '/usr/local/bin/iptables.py' do
  source 'iptables.py.erb'
  variables ({ :confvars => iptablesConfig })
  mode   '0755'
end

cookbook_file 'iptables.service.conf' do
  path '/etc/supervisord.d/iptables.service.conf'
  action :create
end
