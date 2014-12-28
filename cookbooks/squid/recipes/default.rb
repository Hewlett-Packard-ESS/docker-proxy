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

def enforce_value(val, name)
  if val.nil?
    raise "#{name} is a required environment variable"
  end
  return default_value(val, nil)
end

def str_to_arr(input)
  input = default_value(input, [])
  if input === []
    return input
  end
  return input.split(',')
end

squidConfig = {
  :cachePeer => enforce_value(ENV['cache_peer'], 'cache_peer'),
  :cachePeerPort => default_value(ENV['cache_peer_port'], '8080'),
  :localServers => str_to_arr(ENV['local_servers']),
  :insecure => default_value(ENV['insecure'], false)
}

template '/etc/squid/squid.conf' do
  source 'squid.conf.erb'
  variables ({ :confvars => squidConfig })
end
