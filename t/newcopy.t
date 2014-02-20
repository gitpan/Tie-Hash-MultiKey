
# newcopy.t

BEGIN { $| = 1; print "1..13\n"; }
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

# test 2	check accessor
my($x,$thx) = new Tie::Hash::MultiKey;

my $base = q|5	= bless([{
	},
{
	},
{
	},
0,0,], 'Tie::Hash::MultiKey');
|;
my $got = $dd->DumperA($thx);
print "got: $got\nexp: $base\nnot "
	unless $got eq $base;
&ok;

# test 3	add stuff
$x->{['a','b']} = 'ab';
$x->{['c','d','e']} = 'cde';

my $expx = q|19	= bless([{
		'a'	=> 0,
		'b'	=> 0,
		'c'	=> 1,
		'd'	=> 1,
		'e'	=> 1,
	},
{
		'0'	=> 'ab',
		'1'	=> 'cde',
	},
{
		'0'	=> {
			'a'	=> 0,
			'b'	=> 1,
		},
		'1'	=> {
			'c'	=> 2,
			'd'	=> 3,
			'e'	=> 4,
		},
	},
2,5,], 'Tie::Hash::MultiKey');
|;
$got = $dd->DumperA($thx);
print "got: $got\nexp: $expx\nnot "
	unless $got eq $expx;
&ok;

# test 4	second tied hash
my($y,$thy) = new Tie::Hash::MultiKey;

$got = $dd->DumperA($thy);
print "got: $got\nexp: $base\nnot "
	unless $got eq $base;
&ok;

# test 5	clone
my($z,$thz) = $thx->clone;

$got = $dd->DumperA($thz);
print "got: $got\nexp: $expx\nnot "
	unless $got eq $expx;
&ok;

# test 6	modify secondary
$y->{qw(the quick brown fox jumped over the lazy)} = 'dog';
$y->{qw(give a mouse)} = 'a cookie';

my $expy = q|29	= bless([{
		'a'	=> 1,
		'brown'	=> 0,
		'fox'	=> 0,
		'give'	=> 1,
		'jumped'	=> 0,
		'lazy'	=> 0,
		'mouse'	=> 1,
		'over'	=> 0,
		'quick'	=> 0,
		'the'	=> 0,
	},
{
		'0'	=> 'dog',
		'1'	=> 'a cookie',
	},
{
		'0'	=> {
			'brown'	=> 2,
			'fox'	=> 3,
			'jumped'	=> 4,
			'lazy'	=> 7,
			'over'	=> 5,
			'quick'	=> 1,
			'the'	=> 6,
		},
		'1'	=> {
			'a'	=> 9,
			'give'	=> 8,
			'mouse'	=> 10,
		},
	},
2,11,], 'Tie::Hash::MultiKey');
|;
$got = $dd->DumperA($thy);
print "got: $got\nexp: $expy\nnot "
	unless $got eq $expy;
&ok;

# test 7	copy x to y
$thx->copy($thy);
$got = $dd->DumperA($thy);
print "got: $got\nexp: $expx\nnot "
	unless $got eq $expx;
&ok;

# test 8	modify 'y'
my $expm = q|31	= bless([{
		'a'	=> 0,
		'b'	=> 0,
		'bar'	=> 0,
		'c'	=> 1,
		'd'	=> 1,
		'dang'	=> 2,
		'ding'	=> 2,
		'dong'	=> 2,
		'e'	=> 1,
		'foo'	=> 0,
	},
{
		'0'	=> 'baz',
		'1'	=> 'cde',
		'2'	=> 'ddd',
	},
{
		'0'	=> {
			'a'	=> 0,
			'b'	=> 1,
			'bar'	=> 7,
			'foo'	=> 6,
		},
		'1'	=> {
			'c'	=> 2,
			'd'	=> 3,
			'e'	=> 4,
		},
		'2'	=> {
			'dang'	=> 9,
			'ding'	=> 8,
			'dong'	=> 10,
		},
	},
3,11,], 'Tie::Hash::MultiKey');
|;
$y->{qw(a foo bar)} = 'baz';
$y->{qw(ding dang dong)} = 'ddd';
$got = $dd->DumperA($thy);
print "got: $got\nexp: $expm\nnot "
	unless $got eq $expm;
&ok;

# test 9	verify 'x'
$got = $dd->DumperA($thx);
print "got: $got\nexp: $expx\nnot "
	unless $got eq $expx;
&ok;

# test 10	verify 'z'
$got = $dd->DumperA($thz);
print "got: $got\nexp: $expx\nnot "
	unless $got eq $expx;
&ok;

# test 11	clear 'z';
%$z = ();
$got = $dd->DumperA($thz);
print "got: $got\nexp: $base\nnot "
	unless $got eq $base;
&ok;

# test 12	verify 'x'
$got = $dd->DumperA($thx);
print "got: $got\nexp: $expx\nnot "
	unless $got eq $expx;
&ok;

# test 13	verify 'y'
$got = $dd->DumperA($thy);
print "got: $got\nexp: $expm\nnot "
	unless $got eq $expm;
&ok;

