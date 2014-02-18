package Tie::Hash::MultiKey;

use strict;
use Carp;
use Tie::Hash;
use vars qw($VERSION);

$VERSION = do { my @r = (q$Revision: 0.02 $ =~ /\d+/g); sprintf "%d."."%02d" x $#r, @r };

=head1 NAME

Tie::Hash::MultiKey - multiple keys per value

=head1 SYNOPSIS

  use Tie::Hash::MultiKey;

  $accessor = tie %hash, qw(Tie::Hash::MultiValue);
  $accessor = tied %hash;

  untie %hash;

  $hash{'foo'}        = 'baz';
	or
  $hash{'foo', 'bar'} = 'baz';
	or
  $array_ref = ['foo', 'bar'];
  $hash{ $array_ref } = 'baz';

  print $hash{foo};	# prints 'baz'
  print $hash{bar};	# prints 'baz'

  $array_ref = ['fuz','zup'];
  $val = tied(%hash)->addkey('fuz' => 'bar');
  $val = tied(%hash)->addkey('fuz','zup' => 'bar');
  $val = tied(%hash)->addkey( $array_ref => 'bar');

  print $hash{fuz}	# prints 'baz'

  $array_ref = ['foo', 'bar'];
  $val = tied(%hash)->remove('foo');
  $val = tied(%hash)->remove('foo', 'bar');
  $val = tied(%hash)->remove( $array_ref );

  @list = tied(%hash)->keylist('foo')

  $num_vals = tied(%hash)->consolidate;

  All of the above methods can be accessed as:

  i.e.	$accessor->consolidate;

=head1 DESCRIPTION

Tie::Hash::MultiKey creates hashes that can have multiple keys for a single value. 
As shown in the SYNOPSIS, multiple keys share a common value.

Additional keys can be added that share the same value and keys can be removed without deleting other 
keys that share that value.

STORE..ing a value for one or more keys that already exist will overwrite
the existing value and add any missing keys to the key group for that
value.

B<WARNING:> multiple key values supplied as an ARRAY to STORE and DELETE
operations are passed by Perl as a B<single> string separated by the $;
multidimensional array seperator. i.e.

	$hash{'a','b','c'} = $something;
  or
	@keys = ('a','b','c');
	$hash{@keys} = $something'

This really means $hash{join($;, 'a','b','c')};

Tie::Hash::MultiKey will do the right thing as long as your keys B<DO NOT>
contain binary data the may include the $; separator character.

It is recommended that you use the ARRAY_REF construct to supply multiple
keys for binary data. i.e.

	$hash{['a','b','c']} = $something;
  or
	$keys = ['a','b','c'];
	$hash{$keys} = $something;

This construct is ALWAYS safe.

=cut

# data structure
# [
#
# 0 =>	{	# $kh
#	key	=> vi		# value_index for array below
#	},
# 1 =>	{	# $vh
#	vi	=> value,	# contains value
#	},
# 2 =>	{	# $sh	pointer to hash list of all shared keys
#	vi	= {key => dummy, key => dummy, ...}, values unused
#	},
# 3 =>	vi	# numeric value of value index
# ]

sub TIEHASH {
  my $class = shift;
  bless [{},{},{},0], $class;
}

sub FETCH {
  my($self,$key) = @_;
  return undef unless exists $self->[0]->{$key};
  my $vi = $self->[0]->{$key};	# get key index
  return $self->[1]->{$vi};
}

# take arguments of the form:
#	$array_ref, $val
# or
#	$a0, $a1, $a2, $val
# and returns
#	$val, @aN

sub _flip {
  my $val;
  if (ref $_[0] eq "ARRAY") {
    return ($_[1],@{$_[0]});
  }
  return (pop(@_),@_);
}

# 
sub _wash {
  my $keys = shift;
  $keys = [$keys eq '' 
	? ('')
	: split /$;/, $keys, -1] 
  		unless ref $keys eq 'ARRAY';
  croak "empty key" unless @$keys;
  return $keys;
}

sub STORE {
  my($self,$keys,$val) = @_;
  my @keys = @{&_wash($keys)};
  my($kh,$vh,$sh) = @{$self};
  my($vi,%found);
  foreach my $key (@keys) {
    my $vi;
    next unless exists $kh->{$key};
    $vi = $kh->{$key};	# get key index
    $found{$vi} = 1;
  }
  my @vi = sort keys %found;
  $keys = {};
  @{$keys}{@keys} = (0..$#keys);	# create key list
  if (@vi) {				# if there are existing keys
    foreach (@vi) {			# consolidate keys
      my @sk = keys %{$sh->{$_}};	# shared keys
      @{$keys}{@sk} = (0..$#sk);
      delete $vh->{$_};		# delete existing value
      delete $sh->{$_};		# delete existing key list
    }
  } else {
    $vi[0] = $self->[3]++;	# new key pointer
  }
  $vi = shift @vi;

  $vh->{$vi} = $val;		# set value
  $sh->{$vi} = $keys;		# set key list
  foreach (keys %$keys) {
    $kh->{$_} = $vi;		# set value index
  }
  $val;
}

sub DELETE {
  my($self,$keys,$val) = @_;
  my @keys = @{&_wash($keys)};
  my($kh,$vh,$sh) = @{$self};
  my @vis = delete @{$kh}{@keys};	# delete all identified keys
  foreach (@vis) {		# $vi delete key shared list entries
    unless (defined $_) {
      $_ = '';			# vi is never empty
      next;
    }
    my $keys = delete $sh->{$_};
    delete @{$kh}{keys %$keys};
  }
#  my @vals = delete @{$vh}{@vis};	# collect and delete values
#  return wantarray ? @vals : pop @vals;
  delete @{$vh}{@vis};		# undef's replaced with '' above,  collect and delete values
} # NOTE: does not look like 'delete' does a wantarray

sub EXISTS {
  exists $_[0]->[0]->{$_[1]};
}

sub FIRSTKEY {
  keys %{$_[0]->[0]};	# reset iterator
  &NEXTKEY;
}

sub NEXTKEY {
#  defined (my $key = each %{$_[0]->[0]}) or return undef;
#  return $key;
  scalar each %{$_[0]->[0]};
}

# delete all key, value sets
sub CLEAR {
  my $self = shift;
  $self->[3] = 0;
  %{$self->[0]} = ();		# empty existing hashes
  %{$self->[1]} = ();
  %{$self->[2]} = ();
}

sub SCALAR {
  scalar %{$_[0]->[0]};
}

=over 4

=item * $acc = tie %hash,'Tie::Hash::MultiValue';

Ties a %hash to this package for enhanced capability and returns a method
pointer.

  my %hash;
  my $accessor = tie %hash,'Tie::Hash::MultiValue';

=item * $acc = tied %hash;

Returns a method pointer for this package.

=item * untie %hash;

Breaks the binding between a variable and this package. There is no affect
if the variable is not tied.

=item * $val = ->addkey('new_key' => 'existing_key');

Add one or more keys to the shared key group for a particular value.

  input:	array or array_ref,
		existing_key
  returns:	hash value
	    or	dies with stack trace

Dies with stack trace if B<existing_key> does not exist OR if B<new> key
belongs to another key set.

Arguments may be a single SCALAR, ARRAY, or ARRAY_REF

=cut

sub addkey {
  my($kh,$vh,$sh) = @{shift @_};
  my($key,@new) = &_flip;
  croak "key '$key' does not exist" unless exists $kh->{$key};
  my $vi = $kh->{$key};
  foreach(@new) {
    if (exists $kh->{$_} && $kh->{$key} != $vi) {
      my @kset = sort keys %{$sh->{$vi}};
      croak "key belongs to key set @kset";
    }
    $sh->{$vi}->{$_} = 1;
    $kh->{$_} = $vi;
  }
  return $vh->{$vi};
}    

=item * $val = ->remove('key');

Remove one or more keys from the shared key group for a particular value 
If this operation removes the LAST key, then it performs a DELETE which is the same as:

	delete $hash{key};

B<remove> returns a reverse list of the removed value's by key

  i.e.	@val = remove(something);
   or	$val = remove(something);

Arguments may be a single SCALAR, ARRAY or ARRAY_REF

=cut

sub remove {
  my($kh,$vh,$sh) = @{shift @_};
  my @keys = ref $_[0] eq 'ARRAY'
	? @{$_[0]} : @_;
  my @vals;
  foreach my $key (@keys) {
    if (exists $kh->{$key}) {
      my $vi = $kh->{$key};
      delete $kh->{$key};
      unshift @vals, $vh->{$vi};
      delete $sh->{$vi}->{$key};
      unless (keys %{$sh->{$vi}}) {	# if last element in set
	delete $sh->{$vi};		# delete set values and keys
	delete $vh->{$vi};
      }
    } else {	# bogus key
      unshift @vals, undef;
    }
  }
  return wantarray ? @vals : $vals[0];
}

=item * @list = ->keylist('foo');

Returns all the shared keys for KEY 'foo', including 'foo'

  input:	key
  returns:	@shared_keys

=cut

sub keylist {
  my($self,$key) = @_;
  return () unless exists $self->[0]->{$key};
  my $vi = $self->[0]->{$key};
  return keys %{$self->[2]->{$vi}};
}

=item * ->consolidate;

USE WITH CAUTION

This method consolidates all keys with a common values.

  returns: number of consolidated key groups


=back

=cut

sub consolidate {
  my $self = shift;
  my($kh,$vh,$sh) = @{$self};
  my %kbv;				# keys by value
  while (my($k,$v) = each %$vh) {
    if (exists $kbv{$v}) {		# have key group?
      push @{$kbv{$v}}, keys %{$sh->{$k}};	# add keys
    } else {
      $kbv{$v} = [keys %{$sh->{$k}}]; 	# start new key group
    }
  }
  CLEAR($self);
  while (my($v,$k) = each %kbv) {	# values by key
    my $indx = $self->[3]++;
    $vh->{$indx} = $v;			# value
    @{$sh->{$indx}}{@$k} = (0..$#{$k});	# shared keys
    map{$kh->{$_} = $indx} @$k;
  }
  $self->[3];
}

1;

__END__

=head1 COMMON OPERATIONS

A tied multikey %hash behave like a regular %hash for most operations;

  B<$value = $hash{$key}> returns the key group value

  B<$hash{$key} = $value> sets the value for the key group
  i.e. all keys in the group will return that value

  B<$hash{$key1,$key2} = $value assigns $value to the key
  key group consisting of $key1, $key2 if they do not.
  If at least one of the keys already exists, the remaining
  keys are assigned to the key group and the value is set
  for the entire group.

  B<Better> syntax $hash{[$key,$key]} = $value;

  B<delete $hash{$key}> deletes the ENTIRE key group
  to which B<$key> belongs.

  B<delete $hash($key1,$key2> deletes ALL groups
  to which $key1 and $key2 belong.

  B<Better> syntax delete $hash{[$key1,$key2]};

  B<keys %hash> returns all keys.

  B<values %hash> returns all values
  NOTE: that this will not be the same number of
  items as returned by B<keys> unless there are no
  key groups containing more than one key.

  B<($k,$v) = each %hash> behaves as expected.

References to tied %hash behave in the same manner as regular %hash's except
as noted for multiple key values above.

=head1 LIMITATIONS

SLICE operations may produce unusual results. Tie::Hash::MultiKey hashs only
accept SCALAR or ARRAY_REF arguments for SLICE and direct assigment.

  i.e.
	%WRONG = (
		one	=> 1,
		two	=> 2,
		(3,4,5)	=> 12 # expands to 3 => 4, 5 => 12
	);

	%hash = ( # OK
		one	=> 1,
		two	=> 2,
		[3,4,5]	=> 12
	);

will produce a psuedo hash of the form:

	%hash = (
		one	=> 1,
		two	=> 2,
		3	=> 12, --|
		4	=> 12, --|
		5	=> 12  --|
	);

where the operation B<$hash{4} = 99> will change the hash to:

	%hash = (
		one	=> 1,
		two	=> 2,
		3	=> 99, --|
		4	=> 99, --|
		5	=> 99  --|
	);

Example: $hp = \%hash;

  @{$hp}{'one','two','[3,4,5]} = (1,2,12);

produces the same result as above. If the hash already contains a KEY of the
same name, the value will be changed for all other shared keys.

 --------------------------

If you are using ARRAY_REF's as keys (not as pointers to keys as above) they
must be blessed into some other package so that 

	ref $key ne 'ARRAY'

i.e.	bless $key, 'KEY'; # or anything other than 'ARRAY'

 --------------------------

Example SLICE assignments

TO tied hash

	@tiedhash{@keys} = @values;

	$hp = \%tiedhash;
	@{$hp}{@keys} =  @values;

FROM tied hash

	@values = @tiedhash{@keys};

	$hp = \%tiedhash;
	@values = @{$hp}{@keys};

NOTE: when assigning TO the hash, keys may be ARRAY_REF's as described
above.

=head1 AUTHOR

Michael Robinton, <miker@cpan.org>

=head1 COPYRIGHT

Copyright 2014, Michael Robinton

This program is free software; you may redistribute it and/or modify it
under the same terms as Perl itself.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

=cut

1;
