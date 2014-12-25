#========================================================================
#
# PDIC::Header.pm
#
# Copyright (c) 2002 Tsutomu Kuroda <tkrd@mail.com> All rights reserved.
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
#========================================================================

package PDIC::Header;

require 5.004;

use strict;
use warnings;
use vars qw(@ISA $VERSION $DEBUG);

$VERSION = '1.10_a'; # $Date: 2002/02/24 10:51:00 $
$DEBUG = 0;

use Carp;

use vars qw(@STRUCTURE %TYPE %DEFAULT);

@STRUCTURE = qw{
    headername a100
    dictitle a40
    version s
    lword s
    ljapa s
    block_size s
    index_block s
    header_size s
    index_size S
    empty_block s
    nindex s
    nblock s
    nword L
    dicorder c
    dictype c
    attrlen c
    olenumber l
    os c
    lid_word S
    lid_japa S
    lid_exp S
    lid_pron S
    lid_other S
    extheader L
    empty_block2 l
    nindex2 l
    nblock2 l
    index_blkbit c
    dummy a57
};

%TYPE = @STRUCTURE;

#------------------------------------------------------------------------
#
# new($filehandle)
#
# Create a new PDIC::Header object.
#
# $filehandle : IO REF for a PDIC data file handler.
#
#------------------------------------------------------------------------

sub new {
    my $class = shift;
    my $self = {};
    bless $self, $class;
    
    my $fh = $self->{FILE_HANDLE} = shift;
    
    if (not defined $fh) {
        croak('The first argument is not defined.');
    }
    if (ref $fh ne 'IO::Handle') {
        croak('The first argument is not IO::Handle object.');
    }
    
    $self->{headername} =
        "\x1b[2J\x1b[32;7m             ===========" .
        "==== Dictionary for PDIC =============== " .
        "      \x81\x40       \x1b[37;0m\x1a\x00";
    $self->{dictitle} = "\x00" x 40;
    $self->{version} = 0x0400;
    $self->{lword} = 248;
    $self->{ljapa} = 3000;
    $self->{block_size} = 256;
    $self->{index_block} = 0;
    $self->{header_size} = 256;
    $self->{index_size} = 0;
    $self->{empty_block} = -1;
    $self->{nindex} = 0;
    $self->{nblock} = 0;
    $self->{nword} = 0;
    $self->{dicorder} = 0;
    $self->{dictype} = 1;
    $self->{attrlen} = 1;
    $self->{olenumber} = 0;
    $self->{os} = 0;
    $self->{lid_word} = 0;
    $self->{lid_japa} = 0;
    $self->{lid_exp} = 0;
    $self->{lid_pron} = 0;
    $self->{lid_other} = 0;
    $self->{extheader} = 0;
    $self->{empty_block2} = -1;
    $self->{nindex2} = 0;
    $self->{nblock2} = 0;
    $self->{index_blkbit} = 0xff;
    $self->{dummy} = "\x00" x 57;
    
    return $self;
}

#------------------------------------------------------------------------
#
# load()
#
# Load header data from $self->{FILE_HANDLE}
#
#------------------------------------------------------------------------

sub load {
    my $self = shift;
    
    my $fh = $self->{FILE_HANDLE};
    
    my $header_data;
    sysseek($fh, 0, 0);
    sysread($fh, $header_data, 256) or croak("Can't load header data.");
    
    my $template = '';
    my $i;
    for ($i = 1; $i <= $#STRUCTURE; $i += 2) {
        $template .= $STRUCTURE[$i];
    }
    
    my @array = unpack($template, $header_data);
    
    for ($i = 0; $i <= $#STRUCTURE; $i += 2) {
        $self->{$STRUCTURE[$i]} = shift(@array);
    }
    
    return $self;
}

#------------------------------------------------------------------------
#
# set($name, $value)
#
# Sets a value to a property of PDIC::Header object.
#
# $name  : the name of the property
# $value : the value to be set
#
#------------------------------------------------------------------------

sub set {
    my $self = shift;
    my $name = shift;
    my $value = shift;
    
    if (not defined $name) {
        croak("First argument is not defined.");
    }
    
    if (not defined $value) {
        croak("Second argument is not defined.");
    }
    
    my $type = $TYPE{$name};
    
    if (not defined $type) {
        croak("Property '$name' is not defined.");
    }
    elsif ($type eq 'c') {
        unless ($value >= -0x7f and $value <= 0x80) {
            croak("Property '$name' should be 'signed char'.");
        }
    }
    elsif ($type eq 'C') {
        unless ($value >= 0 and $value <= 0xff) {
            croak("Property '$name' should be 'unsigned char'.");
        }
    }
    elsif ($type eq 's') {
        unless ($value >= -0x7fff and $value <= 0x8000) {
            croak("Property '$name' should be 'signed short'.");
        }
    }
    elsif ($type eq 'S') {
        unless ($value >= 0 and $value <= 0xffff) {
            croak("Property '$name' should be 'unsigned short'.");
        }
    }
    elsif ($type eq 'l') {
        unless ($value >= -0x7fffffff and $value <= 0x80000000) {
            croak("Property '$name' should be 'signed long'.");
        }
    }
    elsif ($type eq 'L') {
        unless ($value >= 0 and $value <= 0xffffffff) {
            croak("Property '$name' should be 'unsigned long'.");
        }
    }
    elsif ($type =~ /^a(\d+)$/) {
        unless (length($value) <= $1) {
            croak("Length of the property '$name' should be $1 or less.");
        }
    }
    
    $self->{$name} = $value;
}

#------------------------------------------------------------------------
#
# get($name)
#
# Returns the value of a particular property of PDIC::Header object.
#
# $name  : the name of the property
#
#------------------------------------------------------------------------

sub get {
    my $self = shift;
    my $name = shift;
    
    if (not defined $name) {
        croak("The first argument is not defined.");
    }
    
    if (exists $self->{$name}) {
        if (defined $self->{$name}) {
            return $self->{$name};
        }
        else {
            croak("Property '$name' is not defined.");
        }
    }
    else {
        croak("Property '$name' does not exist.");
    }
}

#------------------------------------------------------------------------
#
# save()
#
# Save the header to the file.
#
# $name  : name of property
# $value : value to be set
#
#------------------------------------------------------------------------

sub save {
    my $self = shift;
    
    my $template = '';
    my $i;
    for ($i = 1; $i <= $#STRUCTURE; $i += 2) {
        $template .= $STRUCTURE[$i];
    }
    
    my @array = ();
    
    for ($i = 0; $i <= $#STRUCTURE; $i += 2) {
        if (not defined $self->{$STRUCTURE[$i]}) {
            croak("The property '$STRUCTURE[$i]' of PDIC::Header is not defined.");
        }
        push(@array, $self->{$STRUCTURE[$i]});
    }
    
    my $fh = $self->{FILE_HANDLE};
    sysseek($fh, 0, 0);
    syswrite($fh, pack($template, @array))
        or croak("Can't write the header section.");
}

1;
