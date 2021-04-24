#!/usr/bin/env perl
use strict;
use warnings;
use Plack::Runner;

use Path::Tiny;
use Text::WikiCreole;
use JSON::XS;

my $filename = $ARGV[0];

unless ($filename) {
  print STDERR "Usage: $0 <filename>\n";
  exit(1);
}

my $html = do { local $/; <DATA> };
my $last_modified = 0;

sub response_reload {
  my $response_payload;
  my $current_modified = (stat $filename)[9];

  if ($last_modified == $current_modified) {
    $response_payload = "{ \"lastUpdated\": \"$current_modified\" }"
  } else {
    my $content = path($filename)->slurp_utf8;
    my $response_html = creole_parse($content);

    $response_payload = encode_json({
      lastUpdated => "$current_modified",
      content     => $response_html
    });
    $last_modified = $current_modified;
  }

  return [
    '200',
    [ 'Content-type' => 'application/json' ],
    [ $response_payload ]
  ];
}


my $app = sub {
  my $env = shift;
  my $response_index = [
    '200',
    [ 'Content-type' => 'text/html' ],
    [ $html ]
  ];

  if ($env->{REQUEST_URI} eq '/reload') {
    return response_reload;
  } else {
    return $response_index;
  }
};

print STDERR "Watching and autoreloading $filename\n";
Plack::Runner->new->run($app);

__DATA__
<!DOCTYPE html>
<html>
  <head>
    <meta charset="utf-8" />
    <meta http-equiv="x-ua-compatible" content="ie=edge" />
    <meta name="viewport" content="width=device-width, initial-scale=1" />

    <title></title>
  </head>

  <body>
  </body>

  <script>
    function updatePage(jsonResponse) {
      if (jsonResponse.content) {
        document.body.innerHTML = jsonResponse.content;
      }
    };

    function reload() {
      fetch('/reload')
        .then(response => response.json())
        .then(updatePage);
    };

    reload();
    setInterval(reload, 2000);
  </script>
</html>
