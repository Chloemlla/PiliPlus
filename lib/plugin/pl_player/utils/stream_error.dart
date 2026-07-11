abstract final class PlPlayerStreamError {
  static bool isNetworkOpenError(String event) {
    final message = event.toLowerCase();
    return message.startsWith('failed to open https://') ||
        message.startsWith('can not open external file https://') ||
        message.startsWith('tcp: ffurl_read returned ') ||
        message.startsWith('tcp: connection to tcp://') ||
        message.startsWith('tcp: failed to resolve hostname ');
  }

  static bool isInterruptedNetworkStream(String event) {
    final message = event.toLowerCase();
    return message.startsWith('https: stream ends prematurely') ||
        message.startsWith('http: stream ends prematurely');
  }
}
