package Tie::Hash::MultiKey;

use strict;
use Carp;
use Tie::Hash;
use vars qw($VERSION);

$VERSION = do { my @r = (q$Revision: 0.05 $ =~ /\d+/g); sprintf "%d."."%02d" x $#r, @r };

=head1 NAME

Tie::Hash::MultiKey - multiple keys per value

=head1 SYNOPSIS

  use Tie::Hash::MultiKey;

  $thm = tie %hash, qw(Tie::Hash::MultiValue);
  $thm = tied %hash;

  untie %hash;

  ($href,$thm) = new Tie::Hash::MultiValue;

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

  @ordered_keys = tied(%hash)->keylist('foo')
  @allkeys_by_order = tied(%hash)->keylist();
  @slotlist = tied(%hash)->slotlist($i);

  $num_vals = tied(%hash)->consolidate;

  ($newRef,$newThm) = tied(%hash)->clone();
  $newThm = tied(%hash)->copy(tied(%new));

  All of the above methods can be accessed as:

  i.e.	$thm->consolidate;

=head1 DESCRIPTION

Tie::Hash::MultiKey creates hashes that can have multiple ordered keys for a single value. 
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

The ARRAY_REF construct is ALWAYS safe.

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
# 4 =>	or	# numeric value of key order
# ]

sub TIEHASH {
  my $class = shift;
  bless [{},{},{},0,0], $class;
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
  croak "empty key\n" unless @$keys;
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
    $found{$vi} = $sh->{$vi}->{$key};	# capture shared key value
  }
  my @vi = keys %found;
  $keys = {};
  my $ostart = $self->[4];
  my $oend = $ostart + $#keys;		# first key order entry
  $self->[4] = $oend + 1;		# last key order entry
  @{$keys}{@keys} = ($ostart..$oend);	# create key list
  if (@vi) {				# if there are existing keys
    foreach (@vi) {			# consolidate keys
      my @sk = keys %{$sh->{$_}};	# shared keys
      @{$keys}{@sk} = @{$sh->{$_}}{@sk};
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
  $self->[4] = 0;
  %{$self->[0]} = ();		# empty existing hashes
  %{$self->[1]} = ();
  %{$self->[2]} = ();
  return $self;
}

sub SCALAR {
  scalar %{$_[0]->[0]};
}

=over 4

=item * $thm = tie %hash,'Tie::Hash::MultiValue';

Ties a %hash to this package for enhanced capability and returns a method
pointer.

  my %hash;
  my $thm = tie %hash,'Tie::Hash::MultiValue';

=item * $thm = tied %hash;

Returns a method pointer for this package.

=item * untie %hash;

Breaks the binding between a variable and this package. There is no affect
if the variable is not tied.

=item * ($href,$thm) = new Tie::Hash::MultiKey;

This method returns an UNBLESSED reference to an anonymous tied %hash.

  input:	none
  returns:	unblessed tied %hash reference,
		object handle

To get the object handle from \%hash use this.

	$thm = tied %{$href};

In SCALAR context it returns the unblessed %hash pointer. In ARRAY context it returns
the unblessed %hash pointer and the package object/method  pointer.

=cut

sub new {
  my %x;
  my $thm = tie %x, __PACKAGE__;
  return wantarray ? (\%x,$thm) : \%x;
}

=item * $val = $thm->addkey('new_key' => 'existing_key');

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
  my $self = shift;
  my($kh,$vh,$sh) = @{$self};
  my($key,@new) = &_flip;
  croak "key '$key' does not exist\n" unless exists $kh->{$key};
  my $vi = $kh->{$key};
  foreach(@new) {
    if (exists $kh->{$_} && $kh->{$key} != $vi) {
      my @kset = sort { $sh->{$vi}->{$a} <=> $sh->{$vi}->{$b} } keys %{$sh->{$vi}};
      croak "key belongs to key set @kset\n";
    }
    $sh->{$vi}->{$_} = $self->[4]++;
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

=item * @ordered_keys = $thm->keylist('foo');

=item * @allkeys_by_order = $thm->keylist();

Returns all the keys in the group that includes the KEY 'foo' in the order
that they were added to the %hash;

If no argument is specified, returns all the keys in the %hash in the order
that they were added to the %hash

  input:	key or EMPTY
  returns:	@ordered_keys

  returns:	() if $key is not in the %hash

=cut

sub keylist {
  my($self,$key) = @_;
  my($kh,$vh,$sh) = @{$self};
  if (defined $key) {
    return () unless exists $kh->{$key};
    my $vi = $kh->{$key};
    return sort { $sh->{$vi}->{$a} <=> $sh->{$vi}->{$b} } keys %{$sh->{$vi}};
  }
  my %ak;			# key => order
  foreach(keys %{$sh}) {
    my @keys = keys %{$sh->{$_}};
    @ak{@keys} = @{$sh->{$_}}{@keys};
  }
  return sort { $ak{$a} <=> $ak{$b} } keys %ak;
}

=item * @keys = $thm->slotlist($i);

Returns one key from each key group in position B<$i>.

  i.e.
	$thm = tie %hash, 'Tie::Hash::MultiKey';

	$hash{['a','b','c']} = 'one';
	$hash{['d','e','f']} = 'two';
	$hash{'g'}           = 'three';
	$hash{['h','i','j']} = 'four';

	@slotkeys = $thm->slotlist(1);

  will produce ('b','e', undef, 'i')

All the keys at index '1' for the groups to which they were added, in the
order which the FIRST KEY in the group was added to the %hash. If there is no key in the
specified slot, an undef is returned for that position.

=cut

sub slotlist($$) {
  my($self,$i) = @_;
  my($kh,$vh,$sh) = @{$self};
  my %kbs;			# order => key
  foreach(keys %{$sh}) {
    my $slot = $sh->{$_};
    my @keys = sort { $slot->{$a} <=> $slot->{$b} } keys %{$slot};
    my $key = $keys[$i];
    $kbs{$slot->{pop @keys}} = $key; # undef is there is no key
  }
  my @order = sort { $a <=> $b } keys %kbs;
  return @kbs{@order};
}

=item * $thm->consolidate;

USE WITH CAUTION

Consolidate all keys with the same values into common groups.

  returns: number of consolidated key groups

=cut

sub consolidate {	# NOTE, vi is not preserved. Since it's not used outside, this is not a big deal except for testing
  my $self = shift;
  my($kh,$vh,$sh) = @{$self};
  my (%kbv,%ko);		# keys by value, key order
  while (my($k,$v) = each %$vh) {
    my @keys = keys %{$sh->{$k}};
    @ko{@keys} = @{$sh->{$k}}{@keys};	# preserve key order
    if (exists $kbv{$v}) {		# have key group?
      push @{$kbv{$v}}, @keys;		# add keys
    } else {
      $kbv{$v} = [@keys]; 	# start new key group
    }
  }
  my $ko = $self->[4];		# save next key order number
  CLEAR($self);
  while (my($v,$k) = each %kbv) {	# values by key
    my $indx = $self->[3]++;
    $vh->{$indx} = $v;			# value
    @{$sh->{$indx}}{@$k} = @ko{@$k};	# restore shared keys and order
    map{$kh->{$_} = $indx} @$k;
  }
  $self->[4] = $ko;
  $self->[3];
}

=item * ($href,$thm) = $thm->clone();

This method returns an UNBLESSED reference to an anonymous tied %hash that
is a deep copy of the parent object.

  input:	none
  returns:	unblessed tied %hash reference,
		object handle

To get the object handle from \%hash use this.

	$thm = tied %{$href};

In SCALAR context it returns the unblessed %hash pointer. In ARRAY context it returns
the unblessed %hash pointer and the package object/method  pointer.

  i.e.
	$newRef = $thm->clone();

	$newRref->{'a','b'} = 'content'

	$newThm = tied %{$newRef};

=item * $new_thm = $thm->copy(tie %new,'Tie::Hash::MultiKey');

This method deep copies a MultiKey %hash to another B<new> %hash. It may
be invoked on an existing tied object handle or a reference to a tied %hash.

  input:	object handle OR reference to tied %hash
  returns:	object handle / method pointer

  i.e
	$thm = tie %hash,'Tie::Hash::MultiKey';
	$newThm = $thm->copy(tie %new,'Tie::Hash::MultiKey');
  or
	tie %new,'Tie::Hash::MultiKey');
	$newThm = $thm->copy(\%new);

NOTE: this method duplicates the data stored in the parent %hash,
overwriting and destroying anything that may have been stored in the copy
target.

=back

=cut

sub copy {
  my($self,$copy) = @_;
  croak "no target specified\n"
	unless defined $copy;
  croak "argument is not a ",__PACKAGE__," object\n"
	unless ref $copy eq __PACKAGE__ || (ref $copy eq 'HASH' && ref ($copy = tied %$copy) eq __PACKAGE__);
  CLEAR($copy) unless $copy->[3] == 0;	# skip if empty hash
  _copy($self,$copy);
}

sub clone {
  my($href,$copy) = &new;
  _copy(shift,$copy);
  return wantarray ? ($href,$copy) : $href;
}

sub _copy {
  my($self,$copy) = @_;
  my($kh,$vh,$sh) = @{$self};
  my @keys = keys %$kh;
  my @vals = @{$kh}{@keys};
  my($ckh,$cvh,$csh) = @{$copy};
  @{$ckh}{@keys} = @vals;		# clone keys
  @{$cvh}{@vals} = @{$vh}{@vals};	# clone value index
  foreach (@vals) {
    @keys = keys %{$sh->{$_}};
    @{$csh->{$_}}{@keys} = @{$sh->{$_}}{@keys};
  }
  @{$copy}[3,4] = @{$self}[3,4];
  return $copy;
}

sub DESTROY {}

1;

__END__

=head1 COMMON OPERATIONS

A tied multikey %hash behave like a regular %hash for most operations;

B<$value = $hash{$key}> returns the key group value

B<$hash{$key} = $value> sets the value for the key group

  i.e. all keys in the group will return that value

B<$hash{$key1,$key2} = $value> assigns $value to the key
key group consisting of $key1, $key2 if they do not.
If at least one of the keys already exists, the remaining
keys are assigned to the key group and the value is set
for the entire group.

B<Better> syntax $hash{[$key,$key]} = $value;

B<delete $hash{$key}> deletes the ENTIRE key group
to which B<$key> belongs.

B<delete $hash($key1,$key2)> deletes ALL groups
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

SLICE operations will produce unusual results if you try to use regular
ARRAYS to specify key groups in the slice. Tie::Hash::MultiKey %hash's only
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
