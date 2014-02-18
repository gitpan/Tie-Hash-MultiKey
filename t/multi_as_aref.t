
BEGIN { $| = 1; print "1..5\n"; }
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
tie %h, 'Tie::Hash::MultiKey';

# test 2	check data structure
my $exp = q|4	= bless([{
	},
{
	},
{
	},
0,], 'Tie::Hash::MultiKey');
|;

my $got = $dd->DumperA(tied %h);
print "got: $got\nexp: $exp\nnot "
	unless $got eq $exp;
&ok;

# test 3	add elements		"STORE"
$h{['foo','bar']} = 'baz';
$exp = q|10	= bless([{
		'bar'	=> 0,
		'foo'	=> 0,
	},
{
		'0'	=> 'baz',
	},
{
		'0'	=> {
			'bar'	=> 1,
			'foo'	=> 0,
		},
	},
1,], 'Tie::Hash::MultiKey');
|;
$got = $dd->DumperA(tied %h);  
print "got: $got\nexp: $exp\nnot "
        unless $got eq $exp;
&ok;

# test 4	add more keys to foo	"&addkey"
$exp = 'baz';
$got = tied(%h)->addkey([qw(buz)], 'foo');
print "got: $got, exp: $exp\nnot "
	unless $got && $got eq $exp;
&ok;

# test 5	check that values are actually their
$exp = q|12	= bless([{
		'bar'	=> 0,
		'buz'	=> 0,
		'foo'	=> 0,
	},
{
		'0'	=> 'baz',
	},
{
		'0'	=> {
			'bar'	=> 1,
			'buz'	=> 1,
			'foo'	=> 0,
		},
	},
1,], 'Tie::Hash::MultiKey');
|;
$got = $dd->DumperA(tied %h);
print "got: $got\nexp: $exp\nnot "
        unless $got eq $exp;
&ok;

