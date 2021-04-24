#!/usr/bin/env perl
use strict;
use warnings;
use Plack::Runner;

use Path::Tiny;
use Text::WikiCreole;
use JSON::XS;

use Encode qw(encode_utf8 decode_utf8);
use String::Util 'trim';
use HTML::Escape;

my $filename = $ARGV[0];

unless ($filename) {
  print STDERR "Usage: $0 <filename>\n";
  exit(1);
}

my $html = do { local $/; <DATA> };
my $last_modified = 0;

my $creole_plugin = sub {
  my $inside = $_[0];
  my ($tag, $words) = split /\s+/, $inside, 2;

  my $build_blockquote_tag = sub {
    my ($quoted) = @_;
    return '<blockquote>'.trim(creole_parse($quoted)).'</blockquote>';
  };

  my $build_figure_tag = sub {
    my ($src, $size, $caption) = split /\s+/, $_[0], 3;

    my $width = ($size eq 'auto') ? 'auto' : ($size . 'px');
    my $caption_html = trim(creole_parse($caption));

    return <<~HTML;
    <figure style="max-width: $width">
    <img src="$src" />
    <figcaption>$caption_html</figcaption>
    </figure>
    HTML
  };

  my $build_abbr_tag = sub  {
    my ($abbr, $title) = split /\s+/, $_[0], 2;

    return qq[<abbr title="$title">$abbr</abbr>];
  };

  my $build_code_tag = sub {
    return '<code>' . escape_html(trim $_[0]) . '</code>';
  };
  my $methods = {
    bq => $build_blockquote_tag,
    abbr => $build_abbr_tag,
    figure => $build_figure_tag,
    c => $build_code_tag
  };

  my $method = $methods->{$tag} || sub { return $_[0]; };

  return $method->($words);
};

creole_plugin($creole_plugin);

sub response_reload {
  my $first = shift;

  my $response_payload;
  my $current_modified = (stat $filename)[9];

  if (($last_modified == $current_modified) && !$first) {
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

  if ($env->{REQUEST_URI} eq '/reload?first') {
    return response_reload(1);
  } elsif ($env->{REQUEST_URI} eq '/reload') {
    return response_reload(0);
  } else {
    return $response_index;
  }
};

print STDERR "Watching and autoreloading $filename\n";

my $runner = Plack::Runner->new;
$runner->parse_options('--access-log','/dev/null');
$runner->run($app);

__DATA__
<!DOCTYPE html>
<html>
  <head>
    <meta charset="utf-8" />
    <meta http-equiv="x-ua-compatible" content="ie=edge" />
    <meta name="viewport" content="width=device-width, initial-scale=1" />
    <title></title>
    <style>
    :root{--nc-font-sans:"Inter",-apple-system,BlinkMacSystemFont,"Segoe UI",Roboto,Oxygen,Ubuntu,Cantarell,"Open Sans","Helvetica Neue",sans-serif,"Apple Color Emoji","Segoe UI Emoji","Segoe UI Symbol";--nc-font-mono:Consolas,monaco,"Ubuntu Mono","Liberation Mono","Courier New",Courier,monospace;--nc-tx-1:#000;--nc-tx-2:#1a1a1a;--nc-bg-1:#fff;--nc-bg-2:#f6f8fa;--nc-bg-3:#e5e7eb;--nc-lk-1:#0070f3;--nc-lk-2:#0366d6;--nc-lk-tx:#fff;--nc-ac-1:#79ffe1;--nc-ac-tx:#0c4047}@media (prefers-color-scheme:dark){:root{--nc-tx-1:#fff;--nc-tx-2:#eee;--nc-bg-1:#000;--nc-bg-2:#111;--nc-bg-3:#222;--nc-lk-1:#3291ff;--nc-lk-2:#0070f3;--nc-lk-tx:#fff;--nc-ac-1:#7928ca;--nc-ac-tx:#fff}}*{margin:0;padding:0}address,area,article,aside,audio,blockquote,datalist,details,dl,fieldset,figure,form,iframe,img,input,meter,nav,ol,optgroup,option,output,p,pre,progress,ruby,section,table,textarea,ul,video{margin-bottom:1rem}button,html,input,select{font-family:var(--nc-font-sans)}body{margin:0 auto;max-width:750px;padding:2rem;border-radius:6px;overflow-x:hidden;word-break:break-word;overflow-wrap:break-word;background:var(--nc-bg-1);color:var(--nc-tx-2);font-size:1.03rem;line-height:1.5}::selection{background:var(--nc-ac-1);color:var(--nc-ac-tx)}h1,h2,h3,h4,h5,h6{line-height:1;color:var(--nc-tx-1);padding-top:.875rem}h1,h2,h3{color:var(--nc-tx-1);padding-bottom:2px;margin-bottom:8px;border-bottom:1px solid var(--nc-bg-2)}h4,h5,h6{margin-bottom:.3rem}h1{font-size:2.25rem}h2{font-size:1.85rem}h3{font-size:1.55rem}h4{font-size:1.25rem}h5{font-size:1rem}h6{font-size:.875rem}a{color:var(--nc-lk-1)}a:hover{color:var(--nc-lk-2)}abbr:hover{cursor:help}blockquote{padding:1.5rem;background:var(--nc-bg-2);border-left:5px solid var(--nc-bg-3)}abbr{cursor:help}blockquote :last-child{padding-bottom:0;margin-bottom:0}header{background:var(--nc-bg-2);border-bottom:1px solid var(--nc-bg-3);margin:-2rem calc(-50vw - -50%) 2rem;padding:2rem calc(50vw - 50%)}header h1,header h2,header h3{padding-bottom:0;border-bottom:0}header>:first-child{margin-top:0;padding-top:0}header>:last-child{margin-bottom:0}a button,button,input[type=button],input[type=reset],input[type=submit]{font-size:1rem;display:inline-block;padding:6px 12px;text-align:center;text-decoration:none;white-space:nowrap;background:var(--nc-lk-1);border:0;border-radius:4px;box-sizing:border-box;cursor:pointer;color:var(--nc-lk-tx)}a button[disabled],button[disabled],input[type=button][disabled],input[type=reset][disabled],input[type=submit][disabled]{cursor:default;opacity:.5;cursor:not-allowed}.button:focus,.button:hover,button:focus,button:hover,input[type=button]:focus,input[type=button]:hover,input[type=reset]:focus,input[type=reset]:hover,input[type=submit]:focus,input[type=submit]:hover{background:var(--nc-lk-2)}code,kbd,pre,samp{font-family:var(--nc-font-mono);background:var(--nc-bg-2);border:1px solid var(--nc-bg-3);border-radius:4px;padding:3px 6px;font-size:.9rem}kbd{border-bottom:3px solid var(--nc-bg-3)}pre{padding:1rem 1.4rem;max-width:100%;overflow:auto}code pre,pre code{background:inherit;font-size:inherit;color:inherit;border:0;padding:0;margin:0}code pre{display:inline}details{padding:.6rem 1rem;background:var(--nc-bg-2);border:1px solid var(--nc-bg-3);border-radius:4px}summary{cursor:pointer;font-weight:700}details[open]{padding-bottom:.75rem}details[open] summary{margin-bottom:6px}details[open]>:last-child{margin-bottom:0}dt{font-weight:700}dd:before{content:"â†’ "}hr{border:0;border-bottom:1px solid var(--nc-bg-3);margin:1rem auto}fieldset{margin-top:1rem;padding:2rem;border:1px solid var(--nc-bg-3);border-radius:4px}legend{padding:auto .5rem}table{border-collapse:collapse;width:100%}td,th{border:1px solid var(--nc-bg-3);text-align:left;padding:.5rem}th,tr:nth-child(2n){background:var(--nc-bg-2)}table caption{font-weight:700;margin-bottom:.5rem}textarea{max-width:100%}ol,ul{padding-left:2rem}li{margin-top:.4rem}ol ol,ol ul,ul ol,ul ul{margin-bottom:0}mark{padding:3px 6px;background:var(--nc-ac-1);color:var(--nc-ac-tx)}input,select,textarea{padding:6px 12px;margin-bottom:.5rem;background:var(--nc-bg-2);color:var(--nc-tx-2);border:1px solid var(--nc-bg-3);border-radius:4px;box-shadow:none;box-sizing:border-box}img{max-width:100%}h1>a,h2>a{color:#333;text-decoration:none}h1>a:hover,h2>a:hover{text-decoration:none;color:#222}h1>a[href="/"]{padding-left:40px;background:url(https://storage.googleapis.com/static.prehistoric.me/pictures/tewet.png) 0 bottom/32px no-repeat}figure{margin:auto}figcaption{margin-top:-1em;font-size:.9em;color:#444}a{color:#004da8;text-decoration:none}a:hover{text-decoration:underline}body{font-size:1.2rem;max-width:840px}.blogroll__list{padding:0}.blogroll__item{display:inline;list-style-type:none}.blogroll__item:after{content:"\a0\b7\a0"}.post-list{padding-left:0}.post-list__item{list-style-type:none}.post-list__timestamp{width:120px}.post-list__link,.post-list__timestamp{display:inline-block;vertical-align:top}.post-list__link{width:620px}.post__timestamp{font-style:italic}.Special{color:#c000c0}.Statement{color:#af5f00}.Constant{color:#c00000}.Identifier{color:teal}.PreProc{color:#c000c0}.Comment{color:#0000c0}
    </style>
  </head>

  <body>
  </body>

  <script>
    function updatePage(jsonResponse) {
      if (jsonResponse.content) {
        document.body.innerHTML = jsonResponse.content;
      }
    };

    function reload(first = false) {
      let reloadUrl = '/reload';

      if (first) {
        reloadUrl = '/reload?first';
      }

      fetch(reloadUrl)
        .then(response => response.json())
        .then(updatePage);
    };

    reload(true);
    setInterval(reload, 2000);
  </script>
</html>
