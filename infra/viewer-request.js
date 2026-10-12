// Runs at the edge on every request, before the cache (site.tf). Two jobs: send www to the bare
// name, and turn a folder address into the file S3 actually holds, since S3 serves no index pages.
function handler(event) {
  var request = event.request;
  var host = request.headers.host ? request.headers.host.value : '';
  var uri = request.uri;

  if (host === 'www.faktron.com') {
    return {
      statusCode: 301,
      statusDescription: 'Moved Permanently',
      headers: { location: { value: 'https://faktron.com' + uri } },
    };
  }

  var last = uri.split('/').pop();
  if (uri.endsWith('/')) {
    request.uri = uri + 'index.html';
  } else if (last.indexOf('.') === -1) {
    // /contact becomes /contact/, so every page has one address.
    return {
      statusCode: 301,
      statusDescription: 'Moved Permanently',
      headers: { location: { value: uri + '/' } },
    };
  }
  return request;
}
