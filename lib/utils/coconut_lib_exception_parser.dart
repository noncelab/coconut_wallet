int? extractEstimatedFeeFromException(Exception e) {
  const pattern = 'Not enough amount for sending. (Fee : ';
  try {
    if (e.toString().contains(pattern)) {
      return int.parse(e.toString().split(pattern)[1].split(")")[0]);
    }
  } catch (_) {}
  return null;
}
