
BEGIN { $| = 1; print "1..3\n"; }
END {print "not ok 1\n" unless $loaded;}

use Tie::Hash::MultiKey;
use Data::Dumper::Sorted;

$loaded = 1;
print "ok 1\n";
######################### End of black magic.

my $dd = new Data::Dumper::Sorted;

$test = 2;

sub ok {
  print "ok $test\n";
  ++$test;
}

my %h;

# test 2	check accessor
my $th = tie %h, 'Tie::Hash::MultiKey';

my $exp = q|4	= bless([{
	},
{
	},
{
	},
0,], 'Tie::Hash::MultiKey');
|;
my $got = $dd->DumperA($th);
print "got: $got\nexp: $exp\nnot "
	unless $got eq $exp;
&ok;

# test 3	recheck accessor
$th = tied %h;
$got = $dd->DumperA($th);
print "got: $got\nexp: $exp\nnot "
	unless $got eq $exp;
&ok;

