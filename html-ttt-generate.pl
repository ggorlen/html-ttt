use strict;
use warnings;
use Getopt::Long qw(GetOptions);
use lib ".";
use TTT;

sub fwrite {
    my ($file, $contents) = @_;
    open(my $fh, ">", $file) or die "Could not open file '$file' $!";
    print $fh $contents;
    close $fh;
}

sub write_position {
    my ($position, $html, $dir) = @_;
    my ($x, $o, $ply) = @{$position}{qw(x o ply)};
    my $filename = "$dir/ply_$ply--x_$x--o_$o.html";
    $filename = $dir if $ply == 0 && $x == 0 && $o == 0;
    fwrite($filename, $html);
}

sub position_to_html {
    my ($position, $links) = @_;
    my ($x, $o) = @{$position}{qw(x o)};
    my $s = "<table><tbody><tr>\n";

    for (my ($i, $shift) = (0, 0); $i < 9; $i++, $shift++) {
        if ($i > 0 && $i % 3 == 0) {
            $shift++;
            $s .= "</tr>\n<tr>\n";
        }
  
        if ((($o >> $shift) & 1) == 1) {
            $s .= "<td>o</td>\n";
        }
        else {
            my $square = (($x >> $shift) & 1) == 1 ? "x" : "&nbsp;";

            if (defined($links) && $links->{$i}) {
                $square = qq{<a href="$links->{$i}">$square</a>};
            }

            $s .= "<td>$square</td>\n";
        }
    }
  
    "$s</tr></tbody></table>\n";
}

sub generate_html {
    my ($position, $get_next_position, $memo, $header, $footer, $dir) = @_;
    my ($x, $o, $ply) = @{$position}{qw(x o ply)};
    my $hash = "$ply $x $o";
    return if $memo->{$hash};
    $memo->{$hash} = 1;

    if (TTT::draw($position)) {
        my $content = "<h3>draw</h3>" . position_to_html($position);
        write_position($position, $header . $content . $footer, $dir);
    }
    elsif (TTT::winner($position) > 0) {
        my $content = "<h3>x wins!</h3>" . position_to_html($position);
        write_position($position, $header . $content . $footer, $dir);
    }
    elsif (TTT::winner($position) < 0) {
        my $content = "<h3>o wins!</h3>" . position_to_html($position);
        write_position($position, $header . $content . $footer, $dir);
    }
    else {
        my %links;

        for my $move (TTT::get_moves($position)) {
            my %next_position = $get_next_position->($position, $move);
            generate_html(\%next_position, $get_next_position, $memo, $header, $footer, $dir);
            my ($x, $o, $ply) = @next_position{qw(x o ply)};
            my $filename = "ply_$ply--x_$x--o_$o.html";
            $links{$move} = $filename;
        }

        my $xo = $ply & 1 ? "o" : "x";
        my $content = "<h3>$xo\'s turn</h3>" . position_to_html($position, \%links);
        write_position($position, $header . $content . $footer, $dir);
    }
}

sub play_self_test {
    my %position = ("x", 0, "o", 0, "ply", 0,);
    
    while (!TTT::draw(\%position) && TTT::winner(\%position) == 0) {
        print ((TTT::print_board \%position) . "\n");
        TTT::move(\%position, TTT::get_best_move(\%position, ~$position{"ply"} & 1));
    }
    
    print (print_board(\%position));
}

if (!caller) {
    my $usage = "Usage: $0 --1player --2player\n";
    my $p1 = 0;
    my $p2 = 0;
    GetOptions("1player" => \$p1, "2player" => \$p2) or die $usage;
    die $usage if !$p1 && !$p2;

    my $stylesheet = qq{
body {
  font-family: monospace;
  font-size: 15pt;
  display: flex;
  align-items: center;
  flex-direction: column;
}
#ttt {
  padding: 1em;
  margin: 0;
  display: flex;
  align-items: center;
  flex-direction: column;
}
#ttt h3 {
  margin: 0;
  padding: 0;
  margin-bottom: 1em;
}
#ttt table {
  table-layout: fixed;
  border-collapse: collapse;
}
#ttt table a {
  text-decoration: none;
}
#ttt td {  
  font-size: 35pt;
  width: 50px;
  height: 50px;
  text-align: center;
  border: 1px solid black;
}
.restart {
  font-size: 13pt;
}
};
    my $header = qq{<!DOCTYPE html>
<html lang="en">
<head>
<title>tic tac toe</title>
<meta charset="utf-8">
<link rel="stylesheet" href="style.css">
</head>
<body><div id="ttt">};
    my $footer = '<p class="restart"><a href="index.html">new game</a></p></body></html>';

    if ($p1) {
        my %position = ("x", 0, "o", 0, "ply", 0,);
        my %memo;
        my $dir = "1p";
        mkdir $dir unless -d $dir;
        fwrite("$dir/style.css", $stylesheet);

        my $next_position = sub {
            my ($position, $move) = @_;

            my %next_position;
            $next_position{"x"} = $position->{"x"};
            $next_position{"o"} = $position->{"o"};
            $next_position{"ply"} = $position->{"ply"};
            TTT::move(\%next_position, $move);
            my $best_move = TTT::get_best_move(\%next_position, $next_position{"ply"});
            
            my %next_next_position;
            $next_next_position{"x"} = $next_position{"x"};
            $next_next_position{"o"} = $next_position{"o"};
            $next_next_position{"ply"} = $next_position{"ply"};
            TTT::move(\%next_next_position, $best_move);
            return %next_next_position;
        };
        generate_html(\%position, $next_position, \%memo, $header, $footer, $dir);
    }

    if ($p2) {
        my %position = ("x", 0, "o", 0, "ply", 0,);
        my %memo;
        my $dir = "2p";
        mkdir $dir unless -d $dir;
        fwrite("$dir/style.css", $stylesheet);

        my $next_position = sub {
            my ($position, $move) = @_;
            my %next_position;
            $next_position{"x"} = $position->{"x"};
            $next_position{"o"} = $position->{"o"};
            $next_position{"ply"} = $position->{"ply"};
            TTT::move(\%next_position, $move);
            return %next_position;
        };
        generate_html(\%position, $next_position, \%memo, $header, $footer, $dir);
    }
}

1;
