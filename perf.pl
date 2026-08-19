use strict;
use warnings;
use Fcntl qw(O_RDONLY O_RDWR);

sysopen(my $DEVMEM, "/dev/mem", O_RDWR) or die "cannot open /dev/mem";
sysopen(my $URANDOM, "/dev/urandom", O_RDONLY) or die "kernel may be broken? (can't open /dev/urandom)";
binmode($DEVMEM); binmode($URANDOM);

# $0	MEMSIZE
# $1	PERFORM COUNT
# $2	BLOCK SIZE
my $MEMSIZE		= $ARGV[0];
my $COUNT		= $ARGV[1];
my $BLOCK_SIZE	= $ARGV[2];

my $payload = "";

for(my $i = 0; $i < $COUNT; ++ $i) {
	# Pick a random number between [0, $MEMSIZE)
	my $random_pos = int(rand($MEMSIZE));

	sysseek($DEVMEM, $random_pos, 0);
	sysread($URANDOM, $payload, $BLOCK_SIZE, 0);

	syswrite($DEVMEM, $payload, $BLOCK_SIZE);
}

close($DEVMEM);
close($URANDOM);
