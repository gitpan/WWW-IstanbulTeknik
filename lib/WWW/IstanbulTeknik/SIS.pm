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
        ADVISER => "/pls/pprd/danisman.P_OgrDanisman", # Danýþman Bilgileri / Information of Adviser

        # unimplemented
        #PTOGRAD => "/pls/pprd/nekaldi.P_Mezun",      # Mezuniyetime Ne Kaldý (Deneme Sürümü) / My Progress to Graduation (Trial Version) 
        #COFMAJ  => "/pls/pprd/basvuru.P_YatayGecis", # Yatay Geçiþ Baþvuru Formu / Application for a change of Major  
        #SURVEY  => "/pls/pprd/anket.P_Anket",        # Ders Anket Formu / Survey

# ana menü
STUREC => "/pls/pprd/twbkwbis.P_GenMenu?name=amenu.P_AdminMnu",
# Öðrenci Bilgileri / Student Records
SHOLDS  => "/pls/pprd/hwskoacc.P_ViewHold",     # Engeller / View Holds  
SGRADES => "/pls/pprd/hwskogrd.P_ViewTermGrde", # Dönem Notlarý / Final Grades
STRANS  => "/pls/pprd/hwskotrn.P_ViewTermTran", # Not Dökümü / Academic Transcript 



        # silinecek
        PINFO  => "/pls/pprd/twbkwbis.P_GenMenu?name=bmenu.P_GenMnu", #Personal Information
        SSERV => "/pls/pprd/twbkwbis.P_GenMenu?name=amenu.P_StuMainMnu", # Student services

);

# STUDENT & FINANCIAL AID
# /pls/pprd/twbkwbis.P_GenMenu?name=amenu.P_RegMnu	Kayýt Menüsü / Registration Menu 
# 
# ----------------------------------------------------------------
# PERSONAL INFORMATION MENU
# 
# /pls/pprd/twbkwbis.P_GenMenu?name=bmenu.P_GenMnu		Kiþisel Bilgiler
# /pls/pprd/twbkwbis.P_GenMenu?name=amenu.P_StuMainMnu		Öðrenci Servisi
# /pls/pprd/twbkwbis.P_ChangePin		PIN Deðiþtir
# /pls/pprd/twbkwbis.P_SecurityQuestion		Güvenlik Sorusunu Deðiþtir
# /pls/pprd/bwgkogad.P_SelectAtypView		Adres ve Telefon Bilgileri
# /pls/pprd/bwgkogad.P_SelectAtypUpdate		Adres ve Telefon Bilgilerini Güncelle
# /pls/pprd/bwgkogad.P_SelectEmalView		E-mail Adresi
# /pls/pprd/bwgkogad.P_SelectEmalUpdate		E-mail Adresi Güncelle
# /pls/pprd/bwgkoemr.P_ViewEmrgContacts		Acil Durum Ýletiþim
# /pls/pprd/bwgkoemr.P_SelectEmrgContacts		Acil Durum Ýletiþim Güncelleme

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

WWW::IstanbulTeknik::SIS - ÝTÜ-SIS için programcý arayüzü.

=head1 TANIM

Ýstanbul Teknik Üniversitesi Öðrenci Otomasyon sistemi için
*oldukça eksik* programcý arayüzü.

Otomatik kayýt iþlemi için bu modülü inceliyorsanýz, bu özelliðin
eklenmediðini bilmeniz yararlý olacaktýr. Bu özellik muhtemelen 
gelecekte de eklenmeyecektir (sebep: sýnýrsýz deneme yapabileceðim 
bir ortam mevcut deðil). 

Þu an, sisteme baðlanma, baðlantýyý kesme ve bir kaç bölüm için
arayüz eklendi. Veri giriþi yapýlan alanlar öncelik olarak ikinci 
sýrada.

=head1 METODLAR

=head2 new

Nesne oluþturucudur. Alabileceði parametreler: C<server_num> ve
C<port>. C<port> parametresinin varsayýlan deðeri C<8092> dir
ve bu deðeri deðiþtirmeniz büyük olasýlýkla gerekmeyecektir.

C<server_num> ise SIS sunucu numarasýný belirtir. Varsayýlan deðeri
C<1> dir. Alabileceði deðerler: 1 ile 9 aralýðýndaki tam sayýlardýr.
Örneðin þu kod ile Node7 sunucusuna baðlanabiliriz:

   my $sis = WWW::IstanbulTeknik::SIS->new(server_num => 7);

Ancak 9 sunucunun her biri her zaman etkin olmayabilir. Genellikle
bunlarýn 4-5 adedi baðlantý kabul etmektedir.

=head2 login USER_ID, PIN

Bu nesne metodu, belirtilen sunucuya bir baðlantý açmaya çalýþýr.
Ýki adet parametre ile çaðrýlmak zorundadýr. Bunlar, sunucunun 
öðrenci kimliðinin tanýmlamasýný saðlayacak C<USER_ID> ve C<PIN>
deðerleridir. Bu deðerler her öðrenci için ayrý olup, öðrenci iþleri
tarafýndan verilmektedir. Buna göre C<USER_ID> alaný, B<kullanýcý adý>,
ve C<PIN> de B<parola> olarak düþünülebilir. 

   $sis->login($USER_ID, $PIN);

=head2 adviser

Öðrenci danýþmanýna ait bilgiler içeren bir hash döndürür.

   my %adviser = $sis->adviser;

=head2 holds

Öðrenciye ait kýsýtlamalarý içeren bir dizgi döndürür. Dönen 
deðer genellikle "I<No holds exist on your record>" þeklindedir.

   my $holds = $sis->holds;

=head2 grades TERM_NUMBER

Belirtilen döneme ait ders notlarýný karmaþýk bir yapý (hashref)
olarak döndürür.

   my $grades = $sis->grades($TERM);

Dönen deðeri incelemek için, yukarýdaki özet kýsmýnda önerildiði gibi
C<Data::Dumper> modülünü kullanabilirsiniz.

C<$TERM> deðeri 6 haneli bir tam sayýdýr. Ýlk dört hane yýlý, 
son iki hane ise dönemi belirtir. Buna göre C<200120> deðerini 
þu þekilde çözebiliriz:

   200120 = 2001 + 20 = 2001 bahar dönemi

Son iki hanede olabilecek deðerler: C<10>, C<20> ve C<30> dur.

   10	kýþ dönemi
   20	bahar dönemi
   30	yaz okulu

=head2 logout

SIS' e açýlan oturumu sonlandýrýr. Bunu kullanmanýz gerekmeyebilir, çünkü
program sonlandýrýlýrken (nesne yokedilirken) otomatik olarak 
çaðrýlacaktýr.

=head1 HATA DENETÝMÝ

Modülün metodlarý baþarýsýz olduðunda otomatik olarak die() ile program
sonlandýrýlmaktadýr. Bu tür hatalarý yakalamak için, metodlarý bir 
C<eval> bloðu içinde çalýþtýrabilirsiniz.

=head1 HATALAR

=over 4

=item * 

Arabirim herhangi bir beklentiyi karþýlayacak düzeyde deðil.

=back

=head1 SEE ALSO

L<WWW::IstanbulTeknik::SIS::Schedules>.

=head1 AUTHOR

Burak Gürsoy, E<lt>burakE<64>cpan.orgE<gt>

=head1 COPYRIGHT

Copyright 2003-2004 Burak Gürsoy. All rights reserved.

=head1 LICENSE

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself. 

=cut
