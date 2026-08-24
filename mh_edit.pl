# put/set script for memhack.sh

use strict;
use warnings;

use POSIX qw(ceil);
use Fcntl qw(O_RDWR);
use URI::Escape qw(uri_unescape);

# Args
# 0		File path
# 1		Address to write
# 2		Payload length
# 3		Operation mode*
# 4		Payload content*
#
# Operation modes:
# 	0	PUT Mode
# 	1	SET Mode
#
# Payload content
# 	If operation mode is 1(SET Mode),
# 		the payload must be an integer (0 <= N)
#
# 	If mode is 0(PUT Mode) and the payload starts with "@",
#		payload will be treated as file name and read from it.
#	Else, this script will try to do URI decoding.
my $FILEPATH	= $ARGV[0];
my $ADDRESS		= $ARGV[1];
my $LENGTH		= $ARGV[2]; # When MODE Put, this value may be undetermined
my $MODE		= $ARGV[3];
my $PAYLOAD		= $ARGV[4] // "";

# Only for positive or zero
sub get_byte_size {
	my $byte = $_[0];
	my $byte_size = 1; # at least one byte(\x00 consumes 1 byte)

	while($byte > 255) {
		$byte >>= 8;
		++ $byte_size;
	}

	return $byte_size;
}

# Args
# 0		Payload content
sub write_at {
	my $code = 0;

	sysopen(my $MEMHANDLE, $FILEPATH, O_RDWR)
		or die "cannot open $FILEPATH";
	binmode($MEMHANDLE);

	$code = sysseek($MEMHANDLE, $ADDRESS, 0);
	if(defined $code) {
		$code = syswrite($MEMHANDLE, $_[0], $LENGTH);
		$code = -1 if !defined $code;
	}

	close($MEMHANDLE);
	return $code;
}

# Args
# 0		Buffer ref
# 1		File name
sub read_all {
	my ($buffer, $FILENAME) = @_;

	open(my $USERFILE_H, "<:raw", $FILENAME)
		or die "$FILENAME: cannot open(or not found?)";

	while(1) {
		my $read_count = read($USERFILE_H, $$buffer, 4096, length($$buffer));
		my $undef_tmp = !(defined $read_count);

		if($undef_tmp || $read_count == 0) {
			warn "warning: stopped reading but not eof" if $undef_tmp;
			last;
		}
	}

	close($USERFILE_H);
}

my $final_data = "";

if($MODE eq "0") { # PUT Mode
	if(substr($PAYLOAD, 0, 1) ne "@") {
		$final_data = uri_unescape($PAYLOAD);
	} else {
		# $PAYLOAD is file name at this time
		$PAYLOAD = substr($PAYLOAD, 1);
		read_all(\$final_data, $PAYLOAD);
	}
	$LENGTH = length($final_data);
} elsif($MODE eq "1") { # SET Mode
	# Match digits using regexp
	if($PAYLOAD =~ /^\d+$/) {
		$PAYLOAD = int($PAYLOAD);
		my $BYTE_SIZE = get_byte_size($PAYLOAD);
		my $char_unit = "";

		for(my $i = 0; $i < $BYTE_SIZE; ++ $i) {
			$char_unit .= chr($PAYLOAD & 0xff);
			$PAYLOAD >>= 8;
		}

		$final_data = $char_unit x ceil($LENGTH / $BYTE_SIZE);
	} else {
		die "PAYLOAD is not a number";
	}
} else {
	die "Invalid MODE was given";
}

my $code = write_at($final_data);
if(defined $code) {
	if($code > 0) {
		print "modification success\n";
	} else {
		print STDERR "modification failed when writing\n";
	}
} else {
	print STDERR "modification failed when seeking\n";
}

