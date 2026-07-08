abstract final class PlPlayerStreamError {
  static bool isNetworkOpenError(String event) {
    return event.startsWith("Failed to open https://") ||
        event.startsWith("Can not open external file https://") ||
        event.startsWith('tcp: ffurl_read returned ');
  }

  static bool isInterruptedNetworkStream(String event) {
    return event.startsWith('https: Stream ends prematurely') ||
        event.startsWith('http: Stream ends prematurely');
  }
}
