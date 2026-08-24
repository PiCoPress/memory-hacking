use strict;
use warnings;
use Fcntl qw(O_RDONLY O_RDWR);

sysopen(my $DEVMEM, "/dev/mem", O_RDWR) 
	or die "cannot open /dev/mem";
sysopen(my $URANDOM, "/dev/urandom", O_RDONLY) 
	or die "kernel may be broken? (can't open /dev/urandom)";

binmode($DEVMEM); binmode($URANDOM);

# Args
# 0		MEMORY SIZE
# 1		PERFORM COUNT
# 2		BLOCK SIZE
#
# Ensure all arguments are numeric.
# It won't check the inputs.
my $MEM_SIZE	= $ARGV[0];
my $PERF_COUNT	= $ARGV[1];
my $BLOCK_SIZE	= $ARGV[2];

my $payload = "";
my $code = 0;
my $suc = $PERF_COUNT;

$MEM_SIZE -= $BLOCK_SIZE;

for(my $i = 0; $i < $PERF_COUNT; ++ $i) {
	# Pick a random number between [0, $MEM_SIZE)
	my $random_pos = int(rand($MEM_SIZE));

	$code = sysread($URANDOM, $payload, $BLOCK_SIZE, 0);
	-- $suc, next if !defined $code; # decrease $suc and continue if $code is undef

	$code = sysseek($DEVMEM, $random_pos, 0);
	-- $suc, next if !defined $code;

	$code = syswrite($DEVMEM, $payload, $BLOCK_SIZE);
	-- $suc, next if !defined $code;
}

close($DEVMEM);
close($URANDOM);

print "$suc/$PERF_COUNT succeeded\n";

