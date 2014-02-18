
BEGIN { $| = 1; print "1..6\n"; }
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

# test 3	add element as reference		"STORE"
$h{['foo']} = 'baz';
$exp = q|8	= bless([{
		'foo'	=> 0,
	},
{
		'0'	=> 'baz',
	},
{
		'0'	=> {
			'foo'	=> 0,
		},
	},
1,], 'Tie::Hash::MultiKey');
|;
$got = $dd->DumperA(tied %h);  
print "got: $got\nexp: $exp\nnot "
        unless $got eq $exp;
&ok;

# test 4	add more keys to foo as reference	"&addkey"
$exp = 'baz';
$got = tied(%h)->addkey([qw(bar buz)],'foo');
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

# test 6	bad addkey
$exp = q|key 'not_there' does not exist
|;
eval {
	tied(%h)->addkey([qw(once upon a time)], 'not_there');
};
($got = $@) =~ s/\s+at.*//;
print "got: $got\nexp: $exp\nnot "
	unless $got eq $exp;
&ok;
