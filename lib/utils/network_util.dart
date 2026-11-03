/// Whether a host is a Tor onion service (not a URL or an embedded substring).
bool isOnionHost(String host) => host.trim().toLowerCase().endsWith('.onion');
