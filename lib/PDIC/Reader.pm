#========================================================================
#
# PDIC::Reader.pm
#
# Copyright (c) 2002 Tsutomu Kuroda <tkrd@mail.com> All rights reserved.
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
#========================================================================

package PDIC::Reader;

require 5.004;

use strict;
use vars qw(@ISA $VERSION $DEBUG);
use open IN => ':raw', OUT => ':raw';

$VERSION = '1.11'; # $Date: 2002/02/23 00:00:00 $
$DEBUG = 0;

use PDIC::Header;
use PDIC::Index;
use PDIC::Data;

use IO::Handle;
use Carp;

#------------------------------------------------------------------------
#
# new($f)
#
# Create a new PDIC object.
#
# $f : Path name of a PDIC data file or IO::Handle object.
#
#------------------------------------------------------------------------

sub new {
    my $class = shift;
    my $self = {};
    bless $self, $class;
    
    my $f = shift;
    if (not defined $f) {
        croak("The second argument is not given or defined.")
    }
    elsif (ref $f) {
        if (ref $f eq 'IO::Handle') {
            $self->{FH} = $f;
        }
        else {
            croak("The second argument must be a filename or IO::Handle object.");
        }
    }
    else {
        open(IN, "< $f") or croak("Can't open '$f'.");
        $self->{FH} = *IN{IO};
    }
    
    my $header = $self->{OBJ_HEADER} = new PDIC::Header($self->{FH});
    $header->load();
    if ($header->{version} != 0x400) {
        croak(sprintf("Unsupported Version:0x%04x", $header->{version}));
    }
    
    $self->{OBJ_INDEX} = new PDIC::Index($self->{FH}, $self->{OBJ_HEADER});
    $self->{OBJ_DATA} = new PDIC::Data($self->{FH}, $self->{OBJ_HEADER});
    
    $self->{OBJ_INDEX}->load();
    
    $self;
}

#------------------------------------------------------------------------
#
# DESTRUCTOR
#
# * Superfluous, maybe.
#
#------------------------------------------------------------------------

sub DESTROY {
    my $self = shift;
    close($self->{FH});
}

#------------------------------------------------------------------------
#
# get_indices()
#
# Get a PDIC index (ARRAY REF of HASH REFs). (See. PDIC::Index.pm's new)
#
#------------------------------------------------------------------------

sub get_indices {
    my $self = shift;
    $self->{OBJ_INDEX}{INDICES};
}

#------------------------------------------------------------------------
#
# get_data_section($block_number)
#
# returns a ARRAY REF of HASH REFs that hold every field of each record
#   of a particular data block. (See. PDIC::Data.pm's get_index method)
#
#------------------------------------------------------------------------

sub get_data_section {
    my $self = shift;
    my $data_block_number = shift;
    $self->{OBJ_DATA}->get_data_section($data_block_number);
}

#------------------------------------------------------------------------
#
# get_header_object()
#
# returns a ARRAY REF of HASH REFs that hold every field of each record
#   of a particular data block. (See. PDIC::Data.pm's get_index method)
#
#------------------------------------------------------------------------

sub get_header_object {
    my $self = shift;
    $self->{OBJ_HEADER};
}

1;
