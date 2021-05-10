package TTT;
use strict;
use warnings;
use Exporter;
use List::Util qw/shuffle/;

our @ISA = qw(Exporter);
our @EXPORT = qw(draw get_best_move get_moves print_board winner);

my $MAX_INT = ~0 >> 1;

sub max { $_[0] > $_[1] ? $_[0] : $_[1] }

sub min { $_[0] < $_[1] ? $_[0] : $_[1] }

sub print_board {
    my ($position) = @_;
    my ($x, $o) = @{$position}{qw(x o)};
    my $s = "";
  
    for (my ($i, $shift) = (0, 0); $i < 9; $i++, $shift++) {
        if ($i > 0 && $i % 3 == 0) {
            $shift++;
            $s .= "\n";
        }
  
        if ((($o >> $shift) & 1) == 1) {
            $s .= "o";
        }
        else {
            $s .= (($x >> $shift) & 1) == 1 ? "x" : ".";
        }
    }
  
    "$s\n";
}

sub undo {
    my ($position, $square) = @_;
    my $dest = ~~($square / 3) + $square;
    
    if ($position->{"ply"} > 0 && !legal_move($position->{"o"}, $dest)) {
        $position->{"o"} ^= 1 << $dest;
        $position->{"ply"}--;
        return 1;
    }
    elsif ($position->{"ply"} > 0 && !legal_move($position->{"x"}, $dest)) {
        $position->{"x"} ^= 1 << $dest;
        $position->{"ply"}--;
        return 1;
    }
    
    0;
}

sub move {
    my ($position, $square) = @_;
    my $x = $position->{"x"};
    my $o = $position->{"o"};
    my $dest = ~~($square / 3) + $square;

    if (winner($position) == 0 && !draw($position) && 
        legal_move($x, $dest) && legal_move($o, $dest)) {

        if (($position->{"ply"}++ & 1) > 0) {
            $position->{"o"} |= 1 << $dest;
        }
        else {
            $position->{"x"} |= 1 << $dest;
        }
        
        return 1;
    }
    
    0;
}

sub get_moves {
    my ($position) = @_;
    my ($x, $o) = @{$position}{qw(x o)};
    my @moves;

    for (my $i = 0; $i < 9; $i++) {
        my $dest = ~~($i / 3) + $i;

        if (legal_move($x, $dest) && legal_move($o, $dest)) {
            push @moves, $i;
        }
    }

    shuffle @moves;
}

sub legal_move {
    my ($board, $square) = @_;
    (($board >> $square) & 1) != 1;
}

sub test_win {
    my ($board) = @_;
                                      # any column
    ($board & ($board >> 4) & ($board >> 8) & 0x7) > 0 ||
    (($board + 0x111) & 0x888) > 0 || # any row
    (($board & 0x421) == 0x421) ||    # / diagonal
    (($board & 0x124) == 0x124);      # \ diagonal
}

sub winner {
    my ($position) = @_;
    my ($x, $o, $ply) = @{$position}{qw(x o ply)};
    
    if ($ply > 4 && test_win($x) || test_win($o)) {
        return ($ply & 1) > 0 ? (10 - $ply) : (-10 + $ply);
    }
    
    0;
}

sub draw {
    my ($position) = @_;
    $position->{"ply"} > 8 && winner($position) == 0;
}

sub minimax {
    my ($position, $depth, $maximizing, $alpha, $beta, $side) = @_;

    if (draw($position) || winner($position) != 0) {
        return draw($position) ? 0 : (winner($position) > 0) == ($side == 0) ? 1 : -1;
    }
    elsif ($maximizing) {
        my $best = -$MAX_INT;
        my $best_move = -1;

        for my $move (get_moves($position)) {
            move($position, $move);
            my $child_val = minimax($position, $depth + 1, 0, $alpha, $beta, $side);
            undo($position, $move);

            if ($child_val > $best) {
                $best = $child_val;
                $alpha = max($alpha, $best);
                $best_move = $move;

                last if $alpha >= $beta;
            }
        }

        return $depth == 0 ? $best_move : $best;
    }

    my $best = $MAX_INT;

    for my $move (get_moves($position)) {
        move($position, $move);
        $best = min($best, minimax($position, $depth + 1, 1, $alpha, $beta, $side));
        undo($position, $move);
        $beta = min($beta, $best);

        last if $alpha >= $beta;
    }

    $best;
}

sub get_best_move {
    my ($position, $side) = @_;
    minimax($position, 0, 1, -$MAX_INT, $MAX_INT, $side);
}

1;
