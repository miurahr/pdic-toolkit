#========================================================================
#
# Lingua::EL::Unicode.pm
#
# Copyright (c) 2002 Tsutomu Kuroda <tkrd@mail.com> All rights reserved.
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
#========================================================================

package Lingua::EL::Unicode;

require v5.6.1;

use strict;
use vars qw(@ISA $VERSION $DEBUG);

$VERSION = '1.01'; # $Date: 2002/02/17 10:44:00 $
$DEBUG = 0;

use Carp;

#######################################################################
#
# CONSTRUCTOR
#
#######################################################################

sub new {
    my $proto = shift;
    my $class = ref($proto) || $proto;
    my $self = {};
    bless $self, $class;
    return $self;
}

#######################################################################
#
# to_utf8($text, $gcode)
#
# $text  : Greek text
# $gcode : (win|iso|utf16)
#
#######################################################################

sub to_utf8 {
    my $self = shift;
    my $text = shift;
    my $gcode = shift or 'win';
    
    my $ref = ref($text) ? $text : \$text;
    
    if ($gcode eq 'utf16') {
        $$ref =~ s{(..)}{
            use utf8;
            chr(unpack('S', $&));
        }megx;
    }
    elsif ($gcode eq 'win') {
        $$ref =~ s{.}{
            use utf8;
            chr($self->win_to_uni(unpack('C', $&)));
        }megx;
    }
    else {
        $$ref =~ s{.}{
            use utf8;
            chr($self->iso_to_uni(unpack('C', $&)));
        }megx;
    }
    
    return $$ref;
}

#######################################################################
#
# to_utf16($text, $gcode)
#
# $text  : Greek text
# $gcode : (win|iso|utf8)
#
#######################################################################

sub to_utf16 {
    my $self = shift;
    my $text = shift;
    my $gcode = shift or 'win';
    
    my $ref = ref($text) ? $text : \$text;
    
    if ($gcode eq 'utf8') {
        
        $$ref =~ s{[\00-\7f]|[\xc0-\xdf][\x80-\xbf]|[\xe0-\xef][\x80-\xbf][\x80-\xbf]}{
            if (length($&) == 1){
                pack('n', unpack('C', $&));
            }
            elsif(length($&) == 2){
                my ($c1, $c2) = unpack('C2', $&);
                pack('n', (($c1 & 0x1f) << 6) | ($c2 & 0x3f));
            }else{
                my ($c1, $c2, $c3) = unpack('C3', $&);
                pack('n', (($c1 & 0x0f) << 12) | (($c2 & 0x3f) << 6) | ($c3 & 0x3f));
            }
        }egx;
        
        return $$ref;
    }
    else {
        
        if ($gcode eq 'win') {
            $$ref =~ s{(..)}{
                pack('S', $self->win_to_uni(unpack('C', $&)));
            }megx;
        }
        else {
            $$ref =~ s{(..)}{
                pack('S', $self->iso_to_uni(unpack('C', $&)));
            }megx;
        }
        
        return $$ref;
    }
}

#######################################################################
#
# to_win($text)
#
# $text  : Greek text (unicode)
#
#######################################################################

sub to_win {
    my $self = shift;
    my $text = shift;
    
    my $ref;
    if (not ref $text) {
        $ref = \$text;
    }
    elsif (ref $text eq 'SCALAR') {
        $ref = $text;
    }
    elsif (not defined $text) {
        croak("First argument is not defined.");
    }
    else {
        my $type = ref $text;
        croak("First argument must be SCALAR or SCALAR reference. [type=$type]");
    }
    
    use utf8;
    
    $$ref =~ s{.}{
        pack('C', $self->uni_to_win(ord($&)));
    }egx;

    return $$ref;
}

#######################################################################
#
# win_to_uni($char)
#
# $char  : Greek character
#
#######################################################################

sub win_to_uni {
    my $self = shift;
    my $char = shift;
    
    my $u_char;
    
    if ($char <= 0x7e or $char == 0xbb or $char == 0xbd) {
        $u_char = $char;
    }
    elsif ($char >= 0xb8 and $char <= 0xfe) {
        $u_char = $char + 0x2d0;
    }
    elsif ($char == 0x80) { $u_char = 0x20ac; } # Euro sign
    elsif ($char == 0x82) { $u_char = 0x201a; } # Single Low-9 Quotation Mark
    elsif ($char == 0x83) { $u_char = 0x0192; } # Latin Small Letter F With Hook
    elsif ($char == 0x84) { $u_char = 0x201e; } # Double Low-9 Quotation Mark
    elsif ($char == 0x85) { $u_char = 0x2026; } # Holizontal Ellipsis
    elsif ($char == 0x86) { $u_char = 0x2020; } # Dagger
    elsif ($char == 0x87) { $u_char = 0x2021; } # Double Dagger
    elsif ($char == 0x89) { $u_char = 0x2030; } # Per Mille Sign
    elsif ($char == 0x8b) { $u_char = 0x2039; } # Single Left-Pointing Angle Quotation Mark
    elsif ($char == 0x91) { $u_char = 0x2018; } # Single Left Quotation Mark
    elsif ($char == 0x92) { $u_char = 0x2019; } # Single Right Quotation Mark
    elsif ($char == 0x93) { $u_char = 0x201c; } # Double Left Quotation Mark
    elsif ($char == 0x94) { $u_char = 0x201d; } # Double Right Quotation Mark
    elsif ($char == 0x95) { $u_char = 0x2022; } # Bullet
    elsif ($char == 0x96) { $u_char = 0x2013; } # En Dash
    elsif ($char == 0x97) { $u_char = 0x2014; } # Em Dash
    elsif ($char == 0x99) { $u_char = 0x2122; } # Trade Mark Sign
    elsif ($char == 0x9b) { $u_char = 0x203a; } # Single Right-Pointing Angle Quotation Mark
    elsif ($char == 0xa1) { $u_char = 0x0385; } # Greek Dialytika Tonos
    elsif ($char == 0xa2) { $u_char = 0x0386; } # Greek Capital Letter Alpha With Tonos
    elsif ($char == 0xaa) { $u_char = 0x3f;   } # Question Mark
    elsif ($char == 0xaf) { $u_char = 0x2015; } # Holizontal Bar
    elsif ($char >= 0xa0) {
        $u_char = $char;
    }
    else {
        $u_char = 0x3f; # Question Mark
    }
    return $u_char;
}

#######################################################################
#
# uni_to_win($char)
#
# $char  : Greek character
#
#######################################################################

sub uni_to_win {
    my $self = shift;
    my $u_char = shift;
    
    my $char;
    
    if ($u_char <= 0x7e or $u_char == 0xbb or $u_char == 0xbd) {
        $char = $u_char;
    }
    elsif ($u_char >= 0x388 and $u_char <= 0x3ce) {
        $char = $u_char - 0x2d0;
    }
    elsif ($u_char == 0x20ac) { $char = 0x80; } # Euro sign
    elsif ($u_char == 0x201a) { $char = 0x82; } # Single Low-9 Quotation Mark
    elsif ($u_char == 0x0192) { $char = 0x83; } # Latin Small Letter F With Hook
    elsif ($u_char == 0x201e) { $char = 0x84; } # Double Low-9 Quotation Mark
    elsif ($u_char == 0x2026) { $char = 0x85; } # Holizontal Ellipsis
    elsif ($u_char == 0x2020) { $char = 0x86; } # Dagger
    elsif ($u_char == 0x2021) { $char = 0x87; } # Double Dagger
    elsif ($u_char == 0x2030) { $char = 0x89; } # Per Mille Sign
    elsif ($u_char == 0x2039) { $char = 0x8b; } # Single Left-Pointing Angle Quotation Mark
    elsif ($u_char == 0x2018) { $char = 0x91; } # Single Left Quotation Mark
    elsif ($u_char == 0x2019) { $char = 0x92; } # Single Right Quotation Mark
    elsif ($u_char == 0x201c) { $char = 0x93; } # Double Left Quotation Mark
    elsif ($u_char == 0x201d) { $char = 0x94; } # Double Right Quotation Mark
    elsif ($u_char == 0x2022) { $char = 0x95; } # Bullet
    elsif ($u_char == 0x2013) { $char = 0x96; } # En Dash
    elsif ($u_char == 0x2014) { $char = 0x97; } # Em Dash
    elsif ($u_char == 0x2122) { $char = 0x99; } # Trade Mark Sign
    elsif ($u_char == 0x203a) { $char = 0x9b; } # Single Right-Pointing Angle Quotation Mark
    elsif ($u_char == 0x0385) { $char = 0xa1; } # Greek Dialytika Tonos
    elsif ($u_char == 0x0386) { $char = 0xa2; } # Greek Capital Letter Alpha With Tonos
    elsif ($u_char == 0x2015) { $char = 0xaf; } # Holizontal Bar
    elsif ($u_char >= 0xa0 and $u_char <= 0xff) {
        $char = $u_char;
    }
    else {
        $char = 0x3f; # Question Mark
    }
    return $char;
}

#######################################################################
#
# iso_to_uni($char)
#
# $char  : Greek character
#
#######################################################################

sub iso_to_uni {
    my $self = shift;
    my $char = shift;
    my $gcode = shift;
    
    my $u_char;
    
    if ($char <= 0x7e or $char == 0xbb or $char == 0xbd) {
        $u_char = $char;
    }
    elsif ($char >= 0xb8 and $char <= 0xfe) {
        $u_char = $char + 0x2d0;
    }
    elsif ($char == 0x80) { $u_char = 0x80;   } # No-break Space
    elsif ($char == 0xa1) { $u_char = 0x2018; } # Single Left Quotation Mark
    elsif ($char == 0xa2) { $u_char = 0x2019; } # Single Right Quotation Mark
    elsif ($char == 0xaa) { $u_char = 0x3f;   } # Question Mark
    elsif ($char == 0xaf) { $u_char = 0x2015; } # Holizontal Bar
    elsif ($char == 0xb5) { $u_char = 0x0385; } # Greek Dialytika Tonos
    elsif ($char == 0xb6) { $u_char = 0x0386; } # Alpha With Tonos
    elsif ($char >= 0xa0) {
        $u_char = $char;
    }
    else {
        $u_char = 0x3f; # Question Mark
    }
    return $u_char;
}

#######################################################################
#
# lower_case($text)
#
# $text : Greek text(UTF16)
#
#######################################################################

sub lower_case {
    my $self = shift;
    my $text = shift;
    
    my @chars = unpack('S', $text);
    my $result = '';
    foreach my $char (@chars) {
        if    ($char == 0x386) { $char = 0x3ac; } # Alpha With Tonos
        elsif ($char == 0x388) { $char = 0x3ad; } # Epsilon With Tonos
        elsif ($char == 0x389) { $char = 0x3ae; } # Eta With Tonos
        elsif ($char == 0x38a) { $char = 0x3af; } # Iota With Tonos
        elsif ($char == 0x38c) { $char = 0x3cc; } # Omicron With Tonos
        elsif ($char == 0x38e) { $char = 0x3cd; } # Upsilon With Tonos
        elsif ($char == 0x38f) { $char = 0x3ce; } # Omega With Tonos
        elsif ($char == 0x3aa) { $char = 0x3ca; } # Iota With Dialytika
        elsif ($char == 0x3ab) { $char = 0x3cb; } # Upslion With Dialytika
        elsif ($char >= 0x3b1) { $char -= 0x20; }
        $result .= pack('S', $char);
    }
    return $result;
}

#######################################################################
#
# upper_case($text)
#
# $text : Greek text(UTF16)
#
#######################################################################

sub upper_case {
    my $self = shift;
    my $text = shift;
    
    my @chars = unpack('S', $text);
    my $result = '';
    foreach my $char (@chars) {
        if    ($char == 0x3ac) { $char = 0x386; } # Alpha With Tonos
        elsif ($char == 0x3ad) { $char = 0x388; } # Epsilon With Tonos
        elsif ($char == 0x3ae) { $char = 0x389; } # Eta With Tonos
        elsif ($char == 0x3af) { $char = 0x38a; } # Iota With Tonos
        elsif ($char == 0x3cc) { $char = 0x38c; } # Omicron With Tonos
        elsif ($char == 0x3cd) { $char = 0x38e; } # Upsilon With Tonos
        elsif ($char == 0x3ce) { $char = 0x38f; } # Omega With Tonos
        elsif ($char == 0x3ca) { $char = 0x3aa; } # Iota With Dialytika
        elsif ($char == 0x3cb) { $char = 0x3ab; } # Upslion With Dialytika
        elsif ($char == 0x390) { $char = 0x3aa; } # Iota With Dialytika And Tonos
        elsif ($char == 0x3b0) { $char = 0x3ab; } # Upslion With Dialytika And Tonos
        elsif ($char == 0x3c2) { $char = 0x3a3; } # Final Sigma
        elsif ($char <= 0x3a9) { $char += 0x20; }
        $result .= pack('S', $char);
    }
    return $result;
}

#######################################################################
#
# strip_tonos($text)
#
# $text : Greek text
#
#######################################################################

sub strip_tonos {
    my $self = shift;
    my $text = shift;
    
    my @chars = unpack('S', $text);
    my $result = '';
    foreach my $char (@chars) {
        if    ($char == 0x386) { $char = 0x391; } # Alpha With Tonos
        elsif ($char == 0x388) { $char = 0x395; } # Epsilon With Tonos
        elsif ($char == 0x389) { $char = 0x397; } # Eta With Tonos
        elsif ($char == 0x38a) { $char = 0x399; } # Iota With Tonos
        elsif ($char == 0x3aa) { $char = 0x399; } # Iota With Dialytika
        elsif ($char == 0x38c) { $char = 0x39f; } # Omicron With Tonos
        elsif ($char == 0x38e) { $char = 0x3a5; } # Upsilon With Tonos
        elsif ($char == 0x3ab) { $char = 0x3a5; } # Upsilon With Dialytika And Tonos
        elsif ($char == 0x38f) { $char = 0x3a9; } # Omega With Tonos
        elsif ($char == 0x3ac) { $char = 0x3b1; } # Small Alpha With Tonos
        elsif ($char == 0x3ad) { $char = 0x3b5; } # Small Epsilon With Tonos
        elsif ($char == 0x3ae) { $char = 0x3b7; } # Small Eta With Tonos
        elsif ($char == 0x3af) { $char = 0x3b9; } # Small Iota With Tonos
        elsif ($char == 0x3ca) { $char = 0x3b9; } # Small Iota With Dialytika
        elsif ($char == 0x390) { $char = 0x3b9; } # Small Iota With Dialytika And Tonos
        elsif ($char == 0x3cc) { $char = 0x3bf; } # Small Omicron With Tonos
        elsif ($char == 0x3cd) { $char = 0x3c5; } # Small Upsilon With Tonos
        elsif ($char == 0x3cb) { $char = 0x3c5; } # Small Upsilon With Dialytika
        elsif ($char == 0x3b0) { $char = 0x3c5; } # Small Upsilon With Dialytika And Tonos
        elsif ($char == 0x3ce) { $char = 0x3c9; } # Small Omega With Tonos
        $result .= pack('S', $char);
    }
    return $result;
}

1;

__END__

=head1 NAME

Lingua::EL::Unicode - Convert 8-bit Greek codes into Unicode, and vice versa.


=head1 SYNOPSIS

 use Lingua::EL::Unicode;
 
 my $el = new Lingua::EL::Unicode;
 
 $el->to_utf8($greek_text, 'win'); # Windows-1253 to UTF-8
 $el->to_utf16($greek_text, 'win'); # Windows-1253 to UTF-16
 $el->to_utf8($greek_text, 'iso'); # ISO-8859-7 to UTF-8
 $el->to_utf16($greek_text, 'iso'); # ISO-8859-7 to UTF-16
 $el->to_win($unicode_text', utf8'); # UTF-8 to Windows-1253
 $el->to_win($unicode_text', utf16'); # NOT YET IMPLEMENTED
 $el->to_iso($unicode_text', utf8'); # NOT YET IMPLEMENTED
 $el->to_iso($unicode_text', utf16'); # NOT YET IMPLEMENTED

=head1 DESCRIPTION

Lingua::EL::Unicode privides the methods that convert traditional 8-bit Greek codes (Windows-1253/ISO-8859-7) into Unicode (UTF-8/UTF-16), and vice versa.

Some methods that convert unicode into 8-bit Greek codes are not yet implemented.

This module requires Perl 5.6 or later.

=head1 CONSTRUCTOR

=over 4

=item new()

=back

=head1 METHODS

=over 4

=item to_utf8(TEXT, [CODE])

Takes a greek text and converts it into UTF-8. CODE should be 'win' (Windows-1253) or 'iso' (ISO-8859-7). If omitted, 'win' will be assumed.

=item to_utf16(TEXT, [CODE])

Takes a greek text and converts it into UTF-16. CODE should be 'win' (Windows-1253) or 'iso' (ISO-8859-7). If omitted, 'win' will be assumed.

=item to_win(TEXT, [CODE])

Takes a greek text and converts it into Windows-1253. CODE should be 'utf8' or 'utf16'. If omitted, 'utf8' will be assumed. The conversion from UTF-16 IS NOT YET IMPLEMENTED.

=item to_iso(TEXT, [CODE])

Takes a greek text and converts it into ISO-8859-7. CODE should be 'utf8' or 'utf16'. If omitted, 'utf8' will be assumed. (NOT YET IMPLEMENTED)

=back

=head1 AUTHOR

Tsutomu Kuroda <tkrd@mail.com>

=head1 COPYRIGHT

Copyright (c) 2002 Tsutomu Kuroda <tkrd@mail.com> All rights reserved.
This program is free software; you can redistribute it and/or
modify it under the same terms as Perl itself.

=cut
