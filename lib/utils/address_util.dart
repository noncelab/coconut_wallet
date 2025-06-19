String shortenAddress(String address, {int head = 8, int tail = 8}) {
  if (address.length <= head + tail) return address;
  return '${address.substring(0, head)}...${address.substring(address.length - tail)}';
}
