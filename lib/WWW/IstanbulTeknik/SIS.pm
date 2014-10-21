package WWW::IstanbulTeknik::SIS;
use strict;
use vars qw[$VERSION $AUTOLOAD %URL];
use WWW::Mechanize;

$VERSION = "0.01";

%URL = (
        LOGIN  => "/pls/pprd/twbkwbis.P_WWWLogin",
        MAIN   => "http://www.sis.itu.edu.tr/",
        BASE   => "http://Node%s.sis.itu.edu.tr:",
        HELP   => "/genhelp/hwghmain.htm", # main help
        SHELP  => "/wtlhelp/twbhhelp.htm", # student services help
        LOGOUT => "/pls/pprd/twbkwbis.P_Logout",

        # Student & Financial aid
        ADVISER => "/pls/pprd/danisman.P_OgrDanisman", # Dan��man Bilgileri / Information of Adviser

        # unimplemented
        #PTOGRAD => "/pls/pprd/nekaldi.P_Mezun",      # Mezuniyetime Ne Kald� (Deneme S�r�m�) / My Progress to Graduation (Trial Version) 
        #COFMAJ  => "/pls/pprd/basvuru.P_YatayGecis", # Yatay Ge�i� Ba�vuru Formu / Application for a change of Major  
        #SURVEY  => "/pls/pprd/anket.P_Anket",        # Ders Anket Formu / Survey

# ana men�
STUREC => "/pls/pprd/twbkwbis.P_GenMenu?name=amenu.P_AdminMnu",
# ��renci Bilgileri / Student Records
SHOLDS  => "/pls/pprd/hwskoacc.P_ViewHold",     # Engeller / View Holds  
SGRADES => "/pls/pprd/hwskogrd.P_ViewTermGrde", # D�nem Notlar� / Final Grades
STRANS  => "/pls/pprd/hwskotrn.P_ViewTermTran", # Not D�k�m� / Academic Transcript 



        # silinecek
        PINFO  => "/pls/pprd/twbkwbis.P_GenMenu?name=bmenu.P_GenMnu", #Personal Information
        SSERV => "/pls/pprd/twbkwbis.P_GenMenu?name=amenu.P_StuMainMnu", # Student services

);

# STUDENT & FINANCIAL AID
# /pls/pprd/twbkwbis.P_GenMenu?name=amenu.P_RegMnu	Kay�t Men�s� / Registration Menu 
# 
# ----------------------------------------------------------------
# PERSONAL INFORMATION MENU
# 
# /pls/pprd/twbkwbis.P_GenMenu?name=bmenu.P_GenMnu		Ki�isel Bilgiler
# /pls/pprd/twbkwbis.P_GenMenu?name=amenu.P_StuMainMnu		��renci Servisi
# /pls/pprd/twbkwbis.P_ChangePin		PIN De�i�tir
# /pls/pprd/twbkwbis.P_SecurityQuestion		G�venlik Sorusunu De�i�tir
# /pls/pprd/bwgkogad.P_SelectAtypView		Adres ve Telefon Bilgileri
# /pls/pprd/bwgkogad.P_SelectAtypUpdate		Adres ve Telefon Bilgilerini G�ncelle
# /pls/pprd/bwgkogad.P_SelectEmalView		E-mail Adresi
# /pls/pprd/bwgkogad.P_SelectEmalUpdate		E-mail Adresi G�ncelle
# /pls/pprd/bwgkoemr.P_ViewEmrgContacts		Acil Durum �leti�im
# /pls/pprd/bwgkoemr.P_SelectEmrgContacts		Acil Durum �leti�im G�ncelleme

sub stu {
my $self = shift;
   $self->{mech}->get($self->url('SGRADES'));

}


sub new {
   my $class = shift;
   my %o     = scalar @_ % 2 ? () : (@_);
   my $self  = {_LOGGEDIN_ => 0, _LOGGEDOUT_ => 0};
   bless $self, $class;
   # SIS works best with Netscape Navigator 4.77 :p
   $self->{mech} = WWW::Mechanize->new( 
                      autocheck => 1 ,
                      agent     => "Mozilla/4.77 [en] (Windows NT 5.0; U)",
                   );
   $self->{server_num} = $o{server_num} || 1; # 1-9
   $URL{BASE} .= $o{port} || '8092';
   return $self;
}

sub login {
   my $self = shift;
   @_ >= 2 or die "usage: \$obj->login(\$user_id, \$pin)";
   my $user_id = shift;
   my $pin     = shift;
   $self->{mech}->add_header( Referer => $URL{MAIN} );
   $self->{mech}->get($self->url('LOGIN'));

   $self->{mech}->field(sid => $user_id); # User ID
   $self->{mech}->field(pin => $pin    ); # PIN
   $self->{mech}->submit; # to get login cookie

   my $refresh = URI->new_abs( ($self->{mech}->find_all_links)[0]->url,
                                $self->{mech}->uri 
                               )->as_string;
   $self->{mech}->get($refresh); # after login, we're forwarded to a refresh page
   # now we are inside the system!
   $self->{_LOGGEDIN_} = 1;
}

sub adviser {
   # get and parse adviser info
   my $self = shift;
   $self->{mech}->get($self->url('ADVISER'));
   my $content = $self->{mech}->content;
   $content =~ m[<DIV class="pagebodydiv">(.+?)</div>]is;
   $content = $1 || die "Unknown adviser content!";
   $content =~ s[<a.+?>.+?</a>][]isg;
   $content =~ s[<!--.+?-->][]isg;
   my %adviser;
   my @raw = split /<p>/i, $content;
   my @data;
   foreach (@raw) {
      s/\n//g;
      s/\r//g;
      push @data, $_;
   }
   $adviser{name}      = shift @data;
   $adviser{email}     = pop   @data;
   $adviser{telephone} = pop   @data;
   $adviser{address}   = join ',', @data;
   $adviser{address}   =~ s[\s{2,}][ ]g;
   foreach (keys %adviser) {
      $adviser{$_} =~ s[^.+?:\s(.+?)$][$1];
   }
   return %adviser;
}

sub holds {
   my $self = shift;
   $self->{mech}->get($self->url('SHOLDS'));
   my $content = $self->{mech}->content;
   my $start = quotemeta '<!--  ** END OF twbkwbis.P_OpenDoc ** hwskoacc.P_ViewHold -->';
   my $end   = quotemeta '<!--  ** 12 START OF twbkwbis.P_CloseDoc **  -->';
   $content  =~ m[$start(.+?)$end]is;
   $content  = $1;
   $content  =~ s[<div.+?>.+?</div>][]isg;
   $content  =~ s[.+?<img.+?>(.*?)$][$1]is;
   $content  =~ s[<.+?>][]isg;
   $content  =~ s[^\s+][]isg;
   $content  =~ s[\s+$][]isg;
   return $content;
}

sub grades {
   my $self = shift;
   my $term = shift || die "No term specified!";
   die "term parameter must be six characters long!" unless length $term == 6;
   $self->{mech}->get($self->url('SGRADES'));
   # term: YYYYT0 = 4 digit year + term number + 0; 
   # term number => 1: winter, 2: spring, 3: summer
   # 2001 spring: 200120
   $self->{mech}->field(term => $term);
   $self->{mech}->submit; # to get login cookie

   # grade parser
   require HTML::TableContentParser;
   my $parser = HTML::TableContentParser->new;
   my $junk = $parser->parse($self->{mech}->content);
   my $data = {
   info    => [],
   course  => [],
   summary => [],
   };
   my $x = 0;
   my @sumtit;
   foreach my $row (@{ $junk->[0]{rows} }) {
      my @cell = @{$row->{cells}};
      if ($cell[0]->{data} eq '&nbsp;') {
         $x++;
         next;
      }
      if($x == 0) {
         $cell[0]->{data} =~ s[<.+?>][]g;
         $cell[0]->{data} =~ s[:$][];
         push @{$data->{info}}, [$cell[0]->{data}, $cell[1]->{data}];
      } elsif ($x == 1) {
         my @cdata = map {$_->{data} =~ s[<.+?>][]g;
                          $_->{data} =~ s[^\s+][]g;
                          $_->{data}
                          } @cell;
         pop @cdata;
         push @{$data->{course}}, [@cdata];
      } else { # $x == 2
         my @cdata = map {$_->{data} =~ s[<.+?>][]g;
                          $_->{data} =~ s[^\s+][]g;
                          $_->{data} =~ s[:$][];
                          $_->{data}
                          } @cell;
         push @sumtit, shift @cdata;
         push @{$data->{summary}}, [@cdata];
      }
   }

   # remove titles
   shift @{$data->{info}};
   shift @{$data->{course}};

   my @stitle = ("Attempt Hours","Earned Hours","GPA Hours","Quality Points","GPA");
   my $dat = {};
   for my $i (0..$#stitle) {
      $dat->{$stitle[$i]} = {
         map{ $sumtit[$_] => $data->{summary}->[$_][$i] } (0..$#sumtit)
      };
   }
   $data->{summary} = $dat;
   return $data;
}

sub logout {
   my $self = shift;
   $self->{mech}->get($self->url('LOGOUT'));
   $self->{_LOGGEDOUT_} = 1;
}

sub url {
   my $self = shift;
   my $name  = shift;
   return sprintf($URL{BASE}, $self->{server_num}) . $URL{$name};
}

sub AUTOLOAD {}

sub DESTROY {
   my $self = shift;
   if ($self->{_LOGGEDIN_} && !$self->{_LOGGEDOUT_}) {
      $self->logout;
   }
}

1;

__END__

=head1 NAME

WWW::IstanbulTeknik::SIS - Programmer interface to ITU-SIS.

=head1 SYNOPSIS

   my $sis = WWW::IstanbulTeknik::SIS->new(server_num => 2); # 1-9
      $sis->login($USER_ID, $PIN);
   my %adviser = $sis->adviser;
   my $grades  = $sis->grades($TERM);
   my $holds   = $sis->holds;
      $sis->logout; # not mandatory

   # analyze the returned structures
   use Data::Dumper;
   print "ADVISER: ", Dumper \%adviser;
   print "GRADES: " , Dumper $grades;
   print "HOLDS: "  , $holds;

=head1 DESCRIPTION

This is an *incomplete* programmer interface to the Istanbul 
Technical University (ITU) Student Information System (SIS).

Documentation below is in Turkish language.

=head1 AD

WWW::IstanbulTeknik::SIS - �T�-SIS i�in programc� aray�z�.

=head1 TANIM

�stanbul Teknik �niversitesi ��renci Otomasyon sistemi i�in
*olduk�a eksik* programc� aray�z�.

Otomatik kay�t i�lemi i�in bu mod�l� inceliyorsan�z, bu �zelli�in
eklenmedi�ini bilmeniz yararl� olacakt�r. Bu �zellik muhtemelen 
gelecekte de eklenmeyecektir (sebep: s�n�rs�z deneme yapabilece�im 
bir ortam mevcut de�il). 

�u an, sisteme ba�lanma, ba�lant�y� kesme ve bir ka� b�l�m i�in
aray�z eklendi. Veri giri�i yap�lan alanlar �ncelik olarak ikinci 
s�rada.

=head1 METODLAR

=head2 new

Nesne olu�turucudur. Alabilece�i parametreler: C<server_num> ve
C<port>. C<port> parametresinin varsay�lan de�eri C<8092> dir
ve bu de�eri de�i�tirmeniz b�y�k olas�l�kla gerekmeyecektir.

C<server_num> ise SIS sunucu numaras�n� belirtir. Varsay�lan de�eri
C<1> dir. Alabilece�i de�erler: 1 ile 9 aral���ndaki tam say�lard�r.
�rne�in �u kod ile Node7 sunucusuna ba�lanabiliriz:

   my $sis = WWW::IstanbulTeknik::SIS->new(server_num => 7);

Ancak 9 sunucunun her biri her zaman etkin olmayabilir. Genellikle
bunlar�n 4-5 adedi ba�lant� kabul etmektedir.

=head2 login USER_ID, PIN

Bu nesne metodu, belirtilen sunucuya bir ba�lant� a�maya �al���r.
�ki adet parametre ile �a�r�lmak zorundad�r. Bunlar, sunucunun 
��renci kimli�inin tan�mlamas�n� sa�layacak C<USER_ID> ve C<PIN>
de�erleridir. Bu de�erler her ��renci i�in ayr� olup, ��renci i�leri
taraf�ndan verilmektedir. Buna g�re C<USER_ID> alan�, B<kullan�c� ad�>,
ve C<PIN> de B<parola> olarak d���n�lebilir. 

   $sis->login($USER_ID, $PIN);

=head2 adviser

��renci dan��man�na ait bilgiler i�eren bir hash d�nd�r�r.

   my %adviser = $sis->adviser;

=head2 holds

��renciye ait k�s�tlamalar� i�eren bir dizgi d�nd�r�r. D�nen 
de�er genellikle "I<No holds exist on your record>" �eklindedir.

   my $holds = $sis->holds;

=head2 grades TERM_NUMBER

Belirtilen d�neme ait ders notlar�n� karma��k bir yap� (hashref)
olarak d�nd�r�r.

   my $grades = $sis->grades($TERM);

D�nen de�eri incelemek i�in, yukar�daki �zet k�sm�nda �nerildi�i gibi
C<Data::Dumper> mod�l�n� kullanabilirsiniz.

C<$TERM> de�eri 6 haneli bir tam say�d�r. �lk d�rt hane y�l�, 
son iki hane ise d�nemi belirtir. Buna g�re C<200120> de�erini 
�u �ekilde ��zebiliriz:

   200120 = 2001 + 20 = 2001 bahar d�nemi

Son iki hanede olabilecek de�erler: C<10>, C<20> ve C<30> dur.

   10	k�� d�nemi
   20	bahar d�nemi
   30	yaz okulu

=head2 logout

SIS' e a��lan oturumu sonland�r�r. Bunu kullanman�z gerekmeyebilir, ��nk�
program sonland�r�l�rken (nesne yokedilirken) otomatik olarak 
�a�r�lacakt�r.

=head1 HATA DENET�M�

Mod�l�n metodlar� ba�ar�s�z oldu�unda otomatik olarak die() ile program
sonland�r�lmaktad�r. Bu t�r hatalar� yakalamak i�in, metodlar� bir 
C<eval> blo�u i�inde �al��t�rabilirsiniz.

=head1 HATALAR

=over 4

=item * 

Arabirim herhangi bir beklentiyi kar��layacak d�zeyde de�il.

=back

=head1 SEE ALSO

L<WWW::IstanbulTeknik::SIS::Schedules>.

=head1 AUTHOR

Burak G�rsoy, E<lt>burakE<64>cpan.orgE<gt>

=head1 COPYRIGHT

Copyright 2003-2004 Burak G�rsoy. All rights reserved.

=head1 LICENSE

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself. 

=cut
