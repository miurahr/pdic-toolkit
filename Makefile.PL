use ExtUtils::MakeMaker;


my %opts = (
    'NAME' => 'PDIC',
    'DISTNAME' => 'PDIC-Toolkit',
    'AUTHOR' => 'Tsutomu Kuroda',
    'ABSTRACT' => 'Perl modules and scripts for manipulating PDIC files',
    'VERSION' => '1.15',
    'EXE_FILES' => [ 'bin/pdic2txt',  'bin/txt2pdic',
                     'bin/pdic_utf8', 'bin/utf8_pdic',
                     'bin/pdic_xml',  'bin/xml_pdic',
                     'bin/pdic2csv' ],
    'PMLIBDIRS' => [ 'lib' ],
    'INST_LIB' => 'blib/lib',
    'INST_ARCHLIB' => 'blib/arch',
    'INST_HTMLLIBDIR' => 'blib/html',
    'INST_HTMLSCRIPTDIR' => 'blib/html/script',
    'INST_MAN1DIR' => 'blib/man1',
    'INST_MAN3DIR' => 'blib/man3',
);

WriteMakefile( %opts );

#
# for ActivePerl
#
sub MY::htmlifypods {
    package MY;
    my($self, %attribs) = @_;
    unless ($^O eq 'MSWin32') {
    	return $self->SUPER::htmlifypods(%attribs);
    }
    return "\nhtmlifypods : pure_all\n\t$self->{NOECHO}\$(NOOP)\n" unless
		%{$self->{HTMLLIBPODS}} || %{$self->{HTMLSCRIPTPODS}};
    my($dist);
    my(@m);
    push @m,
qq[POD2HTML_EXE = -S pod2html.bat --header\n],
qq[POD2HTML = \$(PERL) -we "use File::Basename; use File::Path qw(mkpath); %m=\@ARGV;for (keys %m){" \\\n],
q[-e "next if -e $$m{$$_} && -M $$m{$$_} < -M $$_ && -M $$m{$$_} < -M '],
 $self->{MAKEFILE}, q[';" \\
-e "print qq(Htmlifying $$m{$$_}\n);" \\
-e "$$fn = substr($$m{$$_}, index($$m{$$_}, '\lib') + 4);" \\
-e "$$css = '../' x ($$fn =~ s/[\\\\\/]//g) . 'Active.css';" \\
-e "$$dir = dirname($$m{$$_}); mkpath($$dir) unless -d $$dir;" \\
-e "system(qq[$$^X ].q["-I$(PERL_ARCHLIB)" "-I$(PERL_LIB)" $(POD2HTML_EXE) ].qq[ --css=$$css $$_>$$m{$$_}])==0 or warn qq(Couldn\\047t install $$m{$$_}\n);" \\
-e "chmod(oct($(PERM_RW))), $$m{$$_} or warn qq(chmod $(PERM_RW) $$m{$$_}: $$!\n);}"
];
    push @m, "\nhtmlifypods : pure_all ";
    push @m, join " \\\n\t", keys %{$self->{HTMLLIBPODS}}, keys %{$self->{HTMLSCRIPTPODS}};

    push(@m,"\n");
    if (%{$self->{HTMLLIBPODS}} || %{$self->{HTMLSCRIPTPODS}}) {
	push @m, "\t$self->{NOECHO}\$(POD2HTML) \\\n\t";
	push @m, join " \\\n\t", %{$self->{HTMLLIBPODS}}, %{$self->{HTMLSCRIPTPODS}};
    }
    join('', @m);
}
