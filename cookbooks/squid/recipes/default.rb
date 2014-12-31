def default_value(val, default)
  if val.nil?
    return default
  end
  if val === 'true'
    return true
  elsif val === 'false'
    return false
  elsif val.is_a? Numeric
    return BigDecimal.new(val).to_i
  else
    return val
  end
end

def str_to_arr(input)
  input = default_value(input, [])
  if input === []
    return input
  end
  return input.split(',')
end

squidConfig = {
  :cachePeer => ENV['cache_peer'],
  :cachePeerPort => default_value(ENV['cache_peer_port'], '8080'),
  :localServers => str_to_arr(ENV['local_servers']),
  :insecure => default_value(ENV['insecure'], false),
  :tdns_enabled => default_value(ENV['tdns_enabled'], true)
}

squidEnabled = default_value(ENV['thttp_enabled'], true) || default_value(ENV['thttps_enabled'], true)

if squidEnabled === true 
  cookbook_file 'squid.service.conf' do
    path '/etc/supervisord.d/squid.service.conf'
    action :create
  end

  template '/etc/squid/squid.conf' do
    source 'squid.conf.erb'
    variables ({ :confvars => squidConfig })
  end

  execute 'create_ssl_certificates' do
    cwd '/etc/squid/ssl_cert'
    command <<-EOH
    openssl req -subj "/CN=squid.docker.local/O=FakeOrg/C=UK/subjectAltName=DNS.1=*,DNS.2=*.*,DNS.3=*.*.*" -new -newkey rsa:2048 -days 1365 -nodes -x509 -sha256 -keyout key.pem -out cert.pem
    EOH
    user 'squid'
    group 'squid'
    not_if { File.exist?('/etc/squid/ssl_cert/key.pem') }
  end

  execute 'create_cache_dir' do
    command "/usr/sbin/squid -N -z"
    not_if { File.exist?('/var/cache/squid/swap.state') }
    user 'squid'
    group 'squid'
  end

end

#file '/etc/squid/ssl_cert/cert.pem' do
#  owner 'squid'
#  group 'squid'
#  action :create
#end
#
#file '/etc/squid/ssl_cert/key.pem' do
#  owner 'squid'
#  group 'squid'
#  action :create
#end

#bash 'output_ssl' do
#  code <<-EOH
#    echo "The CA certificate that will be used for signing is:"
#    cat /etc/squid/ssl_cert/cert.pem
#  EOH
#end
