package WWW::IstanbulTeknik::SIS::Schedules;
use strict;
use vars qw[$VERSION $AUTOLOAD @ISA %URL @EXPORT @EXPORT_OK %EXPORT_TAGS];
use Exporter;
use LWP::UserAgent;
use HTTP::Request;
use HTML::TableContentParser;

# error constants
use constant PRINT_ON_ERROR  =>  1;
use constant DIE_ON_ERROR    =>  2;
use constant SILENT_ON_ERROR => -1;

# data table constants
use constant CRN       =>  0; # 'CRN'
use constant DKODU     =>  1; # 'Ders Kodu'
use constant DERS_ADI  =>  2; # 'Ders Adi'
use constant OUYESI    =>  3; # 'Öðretim Üyesi'
use constant BINA      =>  4; # 'Bina'
use constant GUN       =>  5; # 'Gün'
use constant SAAT      =>  6; # 'Saat'
use constant DERSLIK   =>  7; # 'Derslik'
use constant KONTENJAN =>  8; # 'Kon.'
use constant YAZILAN   =>  9; # 'Yaz.'
use constant RESERV    => 10; # 'Reservasyon Bol./Yaz./Kon.'
use constant DABOLUM   => 11; # 'Dersi Alabilen Bölümler'
use constant ONSART    => 12; # 'Önþart'

@ISA = qw[Exporter];

$VERSION = "1.0";

%EXPORT_TAGS = (
                 error => [qw(PRINT_ON_ERROR DIE_ON_ERROR SILENT_ON_ERROR)],
                 func  => [qw(web_print dos_print)],
                 data  => [qw(CRN DKODU DERS_ADI OUYESI BINA GUN SAAT DERSLIK KONTENJAN YAZILAN RESERV DABOLUM ONSART)],
);

@EXPORT_OK        = map{@{$EXPORT_TAGS{$_}}} keys %EXPORT_TAGS;
$EXPORT_TAGS{all} = [@EXPORT_OK];
@EXPORT           = ();

%URL = (
         CRNLIST => "http://earth.sis.itu.edu.tr/program/lis",     # list program
         LESCAT  => "http://earth.sis.itu.edu.tr/program/%s.html", # lesson cat
);

sub new {
   my $class = shift;
   my %o     = scalar(@_) % 2 ? () : @_;
   my $self  = {parser       => undef,
                cgi          => undef,
                PARSED       => [],
                PARSED_TITLE => [],
                WARN_LEVEL   => $o{WARN_LEVEL} || -1, # -1: don't die with fatal() 0: nothing 1: print STDERR 2: die
                };
   bless $self, $class;
   $self->{parser} = HTML::TableContentParser->new;
   return $self;
}

sub code {
   my $self = shift;
   my $key  = shift;
      $key  = lc $key;
   my @data = $self->crn_list;
   my %code = map { lc($_), 1 } @data;
   return exists($code{$key}) ? 1 : 0;
}

sub parse {
   my $self     = shift;
   my $thing    = shift;
   my $find_key = shift;
      $thing || $self->fatal("Nothing to parse!");
   my $junk;
      if ($self->code($thing)) { $junk = $self->get_url($self->build_url($thing)) or return $find_key ? $self : () } 
   elsif ($thing =~ m,^http,i) { $junk = $self->get_url($thing) or return $find_key ? $self : () } 
   elsif (-e $thing          ) { $junk = $self->slurp($thing)   or return $find_key ? $self : ()  } 
   else                        { $junk = $thing                 }

   $self->{PARSED} = [];

   if($junk) {
      my $junk_data = $self->{parser}->parse($junk);
      if($junk_data) {
         foreach my $array (@{ $junk_data->[0]{rows} }) {
            push @{ $self->{PARSED} }, [ map{ $self->clean(\$_->{data}) } @{ $array->{cells} } ];
         }
         push @{ $self->{PARSED_TITLE} }, @{$self->{PARSED}[0]} unless $self->{PARSED_TITLE}[0];
         return $find_key ? $self : @{ $self->{PARSED} };
      }
   }
   return $self if $find_key;
}

sub crn_title {
   my $self = shift;
   return wantarray ?  @{$self->{PARSED_TITLE}} : $self->{PARSED_TITLE};
}

sub find_crn {
   my $self = shift;
   my $crn  = shift;
   return unless $self->{PARSED};
   my @found;
   foreach my $row (@{ $self->{PARSED} }) {
      foreach my $crn (@{ $crn }) {
         next if      $row->[0] =~ m,CRN,i; # first element contain titles
         next if not  $row->[0];
         push @found, $row if $row->[0] == $crn;
      }
   }
   return @found;
}

sub build_url {
   my $self = shift;
   my $code = shift;
      $code = lc $code;
   return sprintf $URL{LESCAT}, $code;
}

sub get_url {
   my $self = shift;
   my $url  = shift || $self->fatal("Unknown URL!");
   my $ua   = LWP::UserAgent->new;
   my $r    = $ua->request(HTTP::Request->new(GET => $url));
   $self->error("Connection error [$url]!\n") and return unless $r->is_success;
   $self->error("No content [$url]!\n")       and return unless $r->content;
   return $r->content;
}

sub error {
   my $self = shift;
   my $msg  = shift;
      if ($self->{WARN_LEVEL} == DIE_ON_ERROR)   { $self->fatal($msg)}
   elsif ($self->{WARN_LEVEL} == PRINT_ON_ERROR) { print STDERR $msg."\n" } 
   else { return }
}

sub fatal {
   my $self = shift;
   my $msg  = shift;
   if ($self->{cgi}) {
      print $self->{cgi}->header(-charset => 'ISO-8859-9').$msg;
   } else {
      my($pkg,$file,$line) = caller(1);
      die sprintf "%s at %s line %s\n", $msg, $pkg, $line;
   }
}

sub tresc {
   # escape iso-8859-9 for ms-dos compatibility
   my $self = shift;
   my $s    = shift;
      $s    =~ tr/[çÇðÐýÝöÖþÞüÜ]/[cCgGiIoOsSuU]/;
   return $s;
}

sub clean { # clean html junk
   my $self = shift;
   my $sref = shift;
   return $$sref unless $$sref;
      $$sref =~ s,\r,,gs;
      $$sref =~ s,\n,,gs;
      $$sref =~ s,<.+?>(.+?)</.+?>,$1,gs;
      $$sref =~ s,^\s+,,g;
      $$sref =~ s,\s+$,,g;
      $$sref =~ s,<.+?>,,g;
      return $$sref;
}

sub slurp { # fetch data from hdd
   my $self = shift;
   my $f = shift;
   local $/;
   open FF,'<',$f or die "Can not open $f for reading: $!";
   my $r = <FF>;
   close FF;
   return $r;
}

sub crn_list_from_web { #try to get the crn lisr from web
   my $self = shift;
   my $data = $self->get_url($URL{CRNLIST}) or return;
   my @data = map{ /(\w+)\s+/ and $1 } split (/\n/,$data);
   return @data;
}

sub crn_list { 
   my $self = shift;
   return $self->crn_list_from_web or 
    qw [
ATA
AKM
BIL
BIO
BLG
CAB
CEV
DEN
DNK
EKO
ELE
ELH
ELK
END
ETK
EUT
FIZ
GEM
GID
GSB
HUK
ICM
IML
ING
INS
ISL
ITB
JDF
JEF
JEO
KIM
KMM
KMP
KON
MAD
MAL
MAK
MAT
MEK
MET
MIM
MTO
MUK
MUH
MUT
MUZ
PEM
PET
RES
SBP
SES
STA
TEB
TEK
TEL
TER
THO
TUR
UCK
UZB
   ];
}

sub web_print { # shortcut #1
   my $parser = (ref $_[0] and ref $_[0] eq __PACKAGE__) ? shift(@_) : __PACKAGE__->new;
   my %pref   = @_;
   if ($pref{cgi_object}) {
      $parser->{cgi} = delete $pref{cgi_object};
   } else {
      require CGI;
      $parser->{cgi} = CGI->new;
   }

   my @t;
   foreach my $key (sort keys %pref) {
      push @t, $parser->parse($key,'forward')->find_crn($pref{$key});
   }
   return unless @t;
   my @title = $parser->crn_title;

   my $html = sprintf qq~<html>
   <head>
   <title>ITU CRN</title>
  <meta http-equiv="Content-Type" content="text/html; charset=ISO-8859-9">
  <style>
   body { font-family: verdana; font-size: 12px }
   td   { font-family: verdana; font-size: 12px }
   .darktable  { background: black; }
   .lighttable { background: white; }
   .titletable { background: #dedede;}
  </style>
   </head>
   <body>
   <p align="center">
    <table border="0" cellpadding="0" cellspacing="0">
     <tr><td class="darktable">
      <table border="0" cellpadding="4" cellspacing="1">
       <tr><td class="titletable">%s</td>
        <td class="titletable">%s</td>
        <td class="titletable">%s</td>
        <td class="titletable">%s</td>
        <td class="titletable">%s</td>
        <td class="titletable">%s</td>
        </tr>\n~,
        $title[CRN],
        $title[KONTENJAN],
        $title[YAZILAN],
        'Kalan',
        $title[DERS_ADI],
        $title[OUYESI];
   foreach(@t) {
   $html .= sprintf qq~<tr>
                   <td class="lighttable">%s</td>
                   <td class="lighttable">%s</td>
                   <td class="lighttable">%s</td>
                   <td class="lighttable">%s</td>
                   <td class="lighttable">%s</td>
                   <td class="lighttable">%s</td>
                   </tr>~,
            $_->[CRN],
            $_->[KONTENJAN],
            $_->[YAZILAN],
            $_->[KONTENJAN] - $_->[YAZILAN],
            $_->[DERS_ADI],
            $_->[OUYESI];
   }
   $html .= qq~</table></td></tr></table></p></body></html>~;
   print $parser->{cgi}->header(-charset => 'ISO-8859-9').$html;
}

sub dos_print { # shortcut #2
   my $parser = (ref $_[0] and ref $_[0] eq __PACKAGE__) ? shift(@_) : __PACKAGE__->new;
   my %pref   = @_;
   my @t;
   foreach my $key (sort keys %pref) {
      push @t, $parser->parse($key,'forward')->find_crn($pref{$key});
   }
   return $parser->error("Empty CRN data!") unless @t;
   my @title = $parser->crn_title;

   my @xtitle = (@title[CRN, KONTENJAN, YAZILAN],'Kalan',@title[DERS_ADI, OUYESI]);
   my @lens   = map { '-' x length($_) } @xtitle;

   printf "%s\n", $parser->tresc(join("\t",@xtitle));
   printf "%s\n", join("\t",@lens);
   printf "%s\n", $parser->tresc(join("\t",$_->[CRN],
                                           $_->[KONTENJAN],
                                           $_->[YAZILAN],
                                          ($_->[KONTENJAN] - $_->[YAZILAN]),
                                           $_->[DERS_ADI],
                                           $_->[OUYESI])
                                           ) foreach @t;
}

sub AUTOLOAD {}
sub DESTROY  {}

1;

__END__

=head1 NAME

WWW::IstanbulTeknik::Schedules - Interface to ITU-SIS schedules.

=head1 SYNOPSIS

   use WWW::IstanbulTeknik::SIS::Schedules;
   
   my $crn     = WWW::IstanbulTeknik::SIS::Schedules->new;
   my @all_ata = $crn->parse('ata');             # get all 'ata' lessons
   my @results = $crn->find_crn([30088, 30090]); # get only these CRNs
   my @title   = $crn->crn_title;                # get titles

=head1 DESCRIPTION

Gets the course schedules from ITU-SIS and parses them. You can also 
search within the parsed structures to filter the results.

=head1 AD

WWW::IstanbulTeknik::Schedules - ÝTÜ ders programlarý için arayüz.

=head1 TANIM

ÝTÜ-SIS ten ders programlarýný alýr ve bunlarý ayrýþtýrýr. Sonuçlarý
süzmek için ayrýþtýrýlmýþ yapý içinde arama da yapabilirsiniz.

Ders kayýtlarý esnasýnda birden çok sayfada yeralan derslerin kontenjan 
durumlarýný denetlemek için kullanýlabilir.

=head1 METODLAR

Modül yüklenirken kýsayol fonksiyonlarý ve sabitlerde adboþluðunuza 
yüklenebilir. Modülden dönen veri yapýlarýný anlaþýlýr biçimde 
kullanabilmeniz için en azýndan veri alaný sabitlerini yüklemeniz 
gerekmektedir.

Hepsini yükle:

   use WWW::IstanbulTeknik::SIS::Schedules qw[:error :func :data];

Hepsini yükle:

   use WWW::IstanbulTeknik::SIS::Schedules qw[:all];

Sadece veri alaný sabitlerini yükle:

   use WWW::IstanbulTeknik::SIS::Schedules qw[:data];

Sadece þunu yükle:

   use WWW::IstanbulTeknik::SIS::Schedules qw[dos_print];

Modülü C<require()> ile yüklemeniz durumunda, bunlarý yüklemek 
için C<import> metodunu kullanabilirsiniz.

   require WWW::IstanbulTeknik::SIS::Schedules;
   import  WWW::IstanbulTeknik::SIS::Schedules qw[:all];

Sabitler ve kýsayol fonksiyonlarý aþaðýda açýklanmýþtýr.

=head2 new

Nesne oluþturucu. Hash olarak geçilen parametreleri alýr.
Desteklenen parametreler:

=over 4

=item WARN_LEVEL

Hata halinde modülün nasýl davranacaðýný belirler. Varsayýlan 
deðeriyle, hata halinde sessiz kalýnýr. Verilebilecek deðerler için
aþaðýda açýklamasý verilen hata sabitlerini inceleyin.

=back

=head2 parse

Ýki parametre alýr. Geçilen ilk parametre:

   "ata" gibi, ders gurubunu belirten bir dizgi, 
   veya http:// ile baþlayan bir URL, 
   veya diskte yeralan bir dosyaya ait yol
   veya ders programýný içeren bir dizgi

olabilir. Arayüz, bunlarý birbirinden ayýrabilecek þekilde tasarlanmýþtýr.
Eðer parse() baþarýlý olursa, ayrýþtýrýlan veriyi bir dizi olarak 
döndürecektir.

Ýkinci parametre ise seçimliktir ve doðru bir deðer olarak geçilmesi halinde
nesnenin kendisi döndürür. C<find_crn> metoduyla baðlamak için bu parametreyi
geçmeniz gerekebilir (örnekleri inceleyin).

=head2 crn_title

parse() dan sonra çaðrýlmasý gerekir. Ders program sayfasýnýn ilk satýrýnda
yeralan baþlýklarý döndürür.

=head2 find_crn

Bir dizi referansý olan tek bir parametre ile çaðrýlýr. Geçilen parametre,
CRN numaralarýný içerir ve daha önce ayrýþtýrýlan ders programý içinde,
bu CRNleri arayarak, bulmasý halinde, bunlara ait bilgileri döndürür.
C<parse()> ile dönen bilgileri süzmek için kullanýlabilir. Bütün 
liste yerine belli dersleri izlemek için kullanýlmasý gerekir.

=head2 crn_list

Ders program kategorilerini SIS sitesinden veya modülün içindeki
kayýttan alarak dizi deðeri olarak döndürür.

=head1 SABÝTLER

Hata sabitleri (:error anahtarýyla veya teker teker yüklenebilir).

   Sabit                Anlamý
   -------------------  -------------
   PRINT_ON_ERROR	Hata iletisini ekrana bas (uyarý)
   DIE_ON_ERROR		Hata halinde programý sonlandýr
   SILENT_ON_ERROR	Hata halinde bir iþlem yapma (varsayýlan)

Veri alaný sabitleri (:data anahtarýyla veya teker teker yüklenebilir).

   Sabit        Anlamý
   -----------  -------------
   CRN		CRN
   DKODU	Ders Kodu
   DERS_ADI	Ders Adý
   OUYESI	Öðretim Üyesi
   BINA		Bina
   GUN		Gün
   SAAT		Saat
   DERSLIK	Derslik
   KONTENJAN	Kon.
   YAZILAN	Yaz.
   RESERV	Reservasyon Bol./Yaz./Kon.
   DABOLUM	Dersi Alabilen Bölümler
   ONSART	Önþart

=head1 ÖRNEKLER

=head2 Tam örnek

   use WWW::IstanbulTeknik::SIS::Schedules qw[:error :data];

   my $crn  = WWW::IstanbulTeknik::SIS::Schedules->new(WARN_LEVEL => DIE_ON_ERROR);
   # alýnacak CRNleri belirleyelim
   my %find = (
               ata => [30088, 30090], 
               mat => [30057, 30058],
               );
   my @results;
   # CRNleri çekip aradýklarýmýzý ayýralým
   foreach my $key (sort keys %find) {
      push @results, $crn->parse($key,'forward')->find_crn($find{$key});
   }
   
   # CRN sayfasýndaki baþlýklarý alalým
   my @title = $crn->crn_title;
   
   # baþlýklarý basalým
   printf "%s\t%s\t%s\t%s\t%s\n",
          $title[CRN],
          $title[KONTENJAN],
          $title[YAZILAN],
          'Kalan',
          $title[DERS_ADI];
   
   # Ders bilgilerini basalým
   foreach my $r (@results) {
      printf "%s\t%s\t%s\t%s\t%s\n", 
             $r->[CRN],
             $r->[KONTENJAN],
             $r->[YAZILAN],
             $r->[KONTENJAN] - $r->[YAZILAN],
             $r->[DERS_ADI];
   }

=head2 Kýsayollar

Modülün iki adet kýsayolu mevcut: C<dos_print> ve C<web_print>.
Bunlarý fonksiyon olarak çaðýrabileceðiniz gibi, nesne metodu olarakta 
çaðýrabilirsiniz:

   use WWW::IstanbulTeknik::SIS::Schedules qw[:error];

   my $crn = WWW::IstanbulTeknik::SIS::Schedules->new(WARN_LEVEL => DIE_ON_ERROR);
      $crn->dos_print(ata => [30088, 30090], 
                      mat => [30057, 30058, 30059],
                      # diðerleri ...
                      );

fonksiyon olarak:

   use WWW::IstanbulTeknik::SIS::Schedules qw[:func];
   dos_print ata => [30088, 30090],
             mat => [30057, 30058, 30059],
             # diðerleri ...
             ;

veya 

   use WWW::IstanbulTeknik::SIS::Schedules qw[:func];
   web_print ata => [30088, 30090],
             mat => [30057, 30058, 30059],
             # diðerleri ...
             ;

C<web_print> metoduna C<cgi_object> parametresiyle bir C<CGI> nesnesi
geçebilirsiniz. Aksi taktirde kendisi C<CGI> modülünü yüklemeye
çalýþacaktýr. C<CGI> modülü, HTTP baþlýk bilgisini oluþturmak için
kullanýlmaktadýr.

Kýsayol fonksiyonlarýný, komut satýrýndan, tek satýrlýk bir kod 
ile de çalýþtýrabilirsiniz:

   perl -e "use WWW::IstanbulTeknik::SIS::Schedules ':func';dos_print ata=>[30088]"

Bu kod ile C<ata> kodlu ve C<30088> CRN numaralý derse ait bilgiler
ekrana basýlacaktýr. Linux altýndaysanýz, terminalde çift týrnak 
yerine tek týrnak kullanýn.

=head1 HATALAR

Herhangi bir hata bulursanýz yazara baþvurun.

=head1 BUGS

Contact the author, if you find any.

=head1 SEE ALSO

L<WWW::IstanbulTeknik::SIS>.

=head1 AUTHOR

Burak Gürsoy, E<lt>burakE<64>cpan.orgE<gt>

=head1 COPYRIGHT

Copyright 2003-2004 Burak Gürsoy. All rights reserved.

=head1 LICENSE

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself. 

=cut
