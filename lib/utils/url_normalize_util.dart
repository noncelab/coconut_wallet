class UrlNormalizeUtil {
  static String normalize(String url) {
    String formattedUrl = url.trim();

    if (formattedUrl.isEmpty) {
      return '';
    }

    if (!formattedUrl.startsWith('http://') && !formattedUrl.startsWith('https://')) {
      formattedUrl = 'https://$formattedUrl';
    }

    if (formattedUrl.endsWith('/')) {
      formattedUrl = formattedUrl.substring(0, formattedUrl.length - 1);
    }

    return formattedUrl;
  }
}
