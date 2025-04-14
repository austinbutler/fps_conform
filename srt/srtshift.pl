#!/usr/bin/perl

#
#    Copyright 2006-2011 Soos Gergely <soger@users.sourceforge.net>
#
#    This file is part of mplayer-tools.
#
#    mplayer-tools is free software; you can redistribute it and/or modify
#    it under the terms of the GNU General Public License as published by
#    the Free Software Foundation; either version 2 of the License, or
#    (at your option) any later version.
#
#    mplayer-tools is distributed in the hope that it will be useful,
#    but WITHOUT ANY WARRANTY; without even the implied warranty of
#    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#    GNU General Public License for more details.
#
#    You should have received a copy of the GNU General Public License
#    along with mplayer-tools; if not, write to the Free Software
#    Foundation, Inc., 51 Franklin St, Fifth Floor, Boston, MA  02110-1301  USA
#

$identity='srtshift v7.8';

$minlength=15;    # char
$maxlength=100;   # char
$maxsublength=20; # sec

use POSIX;

$lpar=shift @ARGV;
if ($lpar eq '-l') {
  $scorrect=0;
} else {
  unshift @ARGV,$lpar;
  $scorrect=1;
}
die <<ENDS if $lpar eq '--help' || $lpar eq '--version' || $lpar eq '';

$identity
A command line driven SRT manipulation program.

usage:
srtshift -l [shiftval [breakpoint]] [fps1-fps2] [-b [-m] [pos]] filename [output]
where (the order of the parameters are NOT variable):
    -l         - leave the subtitles alone, do not try to
                 correct them and do not remove the marks
    shiftval   - a floating point number to shift the file with
                 expressed in seconds.hundreth_seconds
		 also accepts number in base 60, for example +1:0:2.3
		 would shift the subtitles with 3602.3 seconds
    breakpoint - in mm:ss or hh:mm:ss format, a position to start the shifting
    fps1-fps2  - adjust from fps1 to fps2;
                 usable if the srt was converted with the wrong fps
    -b         - automatically break subtitle entry into pieces
                 this feature is EXPERIMENTAL, use with care
    -m         - mark the entries that were broke
                 a simple correction removes the marks
    pos        - in hh:mm:ss - the entry to break
                 w/out this: break every entry longer than $maxlength chars
    filename   - file to manipulate
    output     - file to output, use - to output to stdout
                 every other message is written to stderr so you can use a pipe


(c)2008 Soos Gergely <soger\@users.sourceforge.net>

srtshift is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

ENDS

$_=shift @ARGV;
if (/^([\-\+]{0,1})[\d:]+\.*\d*$/) {
    $sign=$1 eq '-'?-1:+1;
    s/^[\-\+]//;
    $shiftval=0;
    s/(\.\d*)$/$shiftval+="0$1"*1000;''/e;
    $b=1;
    foreach (reverse split /:/)
    {
	$shiftval+=$b*1000*$_;
	$b*=60;
    }
    $shiftval*=$sign;
    $position=shift @ARGV;
    if ($position=~/^(\d{1,3}):(\d{1,2})$/) {
        $reference=($1*60+$2)*1000;
    } elsif ($position=~/^(\d{1,2}):(\d{1,2}):(\d{1,2})$/) {
        $reference=($1*3600+$2*60+$3)*1000;
    } else {
	unshift @ARGV,$position;
	$reference=0;
    }
} else {
    unshift @ARGV,$_;
    $shiftval=0;
}

$fps1fps2=shift @ARGV;
if ($fps1fps2=~/^(\d+\.*\d*)-(\d+\.*\d*)$/) {
    $fps1=$1+0;
    $fps2=$2+0;
} else {
    unshift @ARGV,$fps1fps2;
    $fps1=$fps2=0;
}

$breakpar=shift @ARGV;
if ($breakpar eq '-b') {
  $break=1;
  $markpar=shift @ARGV;
  if ($markpar eq '-m') {
    $breakmark=1;
  } else {
    unshift @ARGV,$markpar;
    $breakmark=0;
  }
  $pospar=shift @ARGV;
  if ($pospar=~/^\d\d:\d\d:\d\d$/) {
    $bpos=time2msec("$pospar,000");
  } else {
    unshift @ARGV,$pospar;
    $bpos=0;
  }
} else {
  unshift @ARGV,$breakpar;
  $break=0;
}

$file=shift @ARGV;
$output=shift @ARGV;
$output=$file if $output eq '';
die "Unused parameters:\n  ".join("\n  ",@ARGV)."\n" if $#ARGV!=-1;
open F,"<$file" or die "Cannot open input file $file: $!\n";
@input=<F>;
close F;

### Parse
$i=0;$entry=0;$currentbody=$currenthead='';
while ($i<=$#input) {
  $line=$input[$i];$i++;
  $line=~s/[\x0D]{0,1}\x0A$//;
  if ($line=~/^(-{0,1}\d{1,3}:\d\d:\d\d[,:]\d\d\d) --> (-{0,1}\d{1,3}:\d\d:\d\d[,:]\d\d\d)([XY:\d\s]*)$/) {
    ($time1,$time2,$addition)=($1,$2,$3);
    $time2=msec2time(time2msec($time1)+$maxsublength*1000) if time2msec($time1)+$maxsublength*1000<time2msec($time2);
    nextentry();
    $currenthead=time2msec($time1).'-'.time2msec($time2).'-'.$addition;
  } else {
    if ($scorrect) {
      $line=~s/\x04[^\x04]+\x04//g;
      $line=~s/\xA1\xA6/ /g;
      $line=~s/\s*([\.,!;?])\s*(\w)/$1 $2/g;
      $line=~s/(\d[\.,]) (\d)/$1$2/g;
      $line=~s/\.\s*\.\s*\./.../g;
      $line=~s/\.{2,3}([^\.])/...$1/g;
      $line=~s/\.\s\./.../g;
      $line=~s/\.{4,}/.../g;
      $line=~s/\.,/,/g;
      $line=~s/([!?]),/$1/g;
      $line=~s/([\.!?])\s+([\.!?])/$1$2/ while $line=~/[\.!?]\s+[\.!?]/;
      $line=~s/ $// while $line=~/ $/;
      $line=~s/^ // while $line=~/^ /;
      $line=~s/  / /g while $line=~/  /;
      $line=~s/^- - /- /g;
      $line=~s/!!/!/g while $line=~/!!/;
      $line=~s/([A-Z])\.\s([A-Z])\.\s([A-Z])/$1.$2.$3/g;
      $line=~s/([A-Z])\.\s([A-Z]\W)/$1.$2/g;
      $line=~s/[<\[]\/?i[>\]]//g;
      $line=~s/\{\\a\d+\}//g;
      @line=split(' / ',$line);
      if ($#line>0) {
	foreach (@line) {$_="- $_"}
	$line=join("\n",@line);
      }
    }
    $currentbody.=$line."\n" if $line=~/[^\s\x0D\x0A]/ &&
      $input[$i]!~/^(-{0,1}\d{1,3}:\d\d:\d\d[,:]\d\d\d) --> (-{0,1}\d{1,3}:\d\d:\d\d[,:]\d\d\d)([XY:\d\s]*)[\x0D]{0,1}\x0A$/
  }
}
nextentry();
die "$file is not an srt file\n" if $entry==0;
if ($entry<$#input/8) {
  warn "WARNING: $file has too few entries".($file eq $output?", outputting to $file.srt":'')."\n";
  $output.=".srt" if $file eq $output;
}

### Break
if ($break) {
  $by[$#by+1]="\x01";#replace ...
  $by[$#by+1]="\x02";#replace ?
  $by[$#by+1]="\x03";#replace \n
  $by[$#by+1]="\x05";#replace !
  $by[$#by+1]='.';
  $by[$#by+1]=',';
  $by[$#by+1]=' ';
  $bylist="\x01\x02\x03., ";
  $i=1;$BREAKNR=0;$REALNR=0;$border=$maxlength;$border=10000 if $border<10000;
  while ($i<=$entry) {
    ($time1,$time2,$addition)=splithead($entryhead[$i]);
    $i+=breakentry($i) if ($bpos==0&&length($entrybody[$i])>$maxlength) || ($bpos>0&&($time1>=$bpos&&$time2<=$bpos));
    $i++;
  }
}

### Manipulate
if ($shiftval||($fps1>0 && $fps2>0)) {
  for ($i=1;$i<=$entry;$i++) {
    ($time1,$time2,$addition)=splithead($entryhead[$i]);
    $time1=manipulate($time1);
    $time2=manipulate($time2);
    $entryhead[$i]=$time1.'-'.$time2.'-'.$addition;
  }
}

### Write
if ($output eq '-') {
    *F=*STDOUT;
} else {
    open F, ">$output" or die "Cannot open $output for writing: $!\n";
}
for ($i=1;$i<=$entry;$i++) {
  ($time1,$time2,$addition)=splithead($entryhead[$i]);
  $entrybody[$i].="\n";
  $entrybody[$i]=~s/\n\n/\n/ while $entrybody[$i]=~/\n\n/;
  $entrybody[$i]=~s/\n/\x0D\x0A/g;
  print F "$i\x0D\x0A";
  print F msec2time($time1).' --> '.msec2time($time2)."$addition\x0D\x0A";
  print F $entrybody[$i]."\x0D\x0A";
}
close F;
$msg[$#msg+1]='shifted' if $shiftval;
$msg[$#msg+1]='adjusted' if $fps1>0 && $fps2>0;
$msg[$#msg+1]="broke in $REALNR of $BREAKNR entries" if $break;
$msg[$#msg+1]='corrected' if $#msg==-1;
$msg=join(', ',@msg);
$msg=~s/,\s(\w+)$/ and $1/;
warn $file.' was '.$msg.' sucessfully'.(($output eq $file || $output eq '-')?'':" into file $output").".\n";
if ($#fail>-1) {warn 'Failed: '.(join(',',@fail))."\n"}
exit;

sub nextentry {
  if ($currenthead ne '' && $currentbody=~/[^\s\x0D\x0A]/) {
    $entry++;
    $entryhead[$entry]=$currenthead;
    $entrybody[$entry]=$currentbody;
  }
  $currenthead=$currentbody='';
}

sub splithead {
  local ($head)=@_;
  return $head=~m/^(\d+)-(\d+)-(.*)$/;
}

sub manipulate {
  local($time)=@_;
  $time+=$shiftval if $time>=$reference;
  if ($fps1>0 && $fps2>0) {
    $time=ceil(($fps1*$time)/$fps2);
  }
  return $time;
}

sub msec2time {
  local($time)=@_;
  local $sign='';
  if ($time<0) {
    die "Negative time.\n" if $file eq $output;
    warn "Negative time\n" if $file ne $output;
    $time=-$time;
    $sign='-';
  }
  local($hour,$min,$sec,$msec);
  $msec=$time%1000;
  $msec="0$msec" while length($msec)<3;
  $time=floor($time/1000);
  $sec=($time)%60;
  $sec="0$sec" if $sec<=9;
  $time=floor($time/60);
  $min=$time%60;
  $min="0$min" if $min<=9;
  $hour=floor($time/60);
  $hour="0$hour" if $hour<=9;
  return "$sign$hour:$min:$sec,$msec";
}

sub time2msec {
  local ($time)=@_;
  local ($hour,$min,$sec,$msec)=
    $time=~/-{0,1}(\d+):(\d+):(\d+)[,:](\d+)/;
  return ($time=~/^-/?-1:1)*($msec+$sec*1000+$min*60000+$hour*3600000);
}

sub makeroom {
  local($roomnr,$pos)=@_;
  local ($i);
  for ($i=$#entryhead;$i>$pos;$i--) {
    $entryhead[$i+$roomnr]=$entryhead[$i];
    $entrybody[$i+$roomnr]=$entrybody[$i];
  }
}

sub srtsplit {
  local ($c)=@_;
  return ($c) if length($c)<$maxlength;
  local ($c1,$c2,$j,$cs,$l2,$p1,$p2,$p,$str);
  local ($minimp,$minmember,$imp,$minp,$minstr)=($border+1,$#by+1,$border+$#by,'','');
  $l2=ceil(length($c)/2);
  $c1=substr($c,0,$l2);
  $c2=substr($c,$l2);
  $c1=reverse($c1);

  if ($c1 ne '' && $c2 ne '') {
    for ($j=0;$j<=$#by;$j++) {
      $cs=$by[$j];
      $p1=index($c1,$cs);$p1=$border+1 if $p1<0;
      $p2=index($c2,$cs);$p2=$border+1 if $p2<0;
      if ($p1!=$border+1 || $p2!=$border+1) {
	if ($p2<=$p1) {$p=$p2;$str=1;} else {$p=$p1;$str=-1;}
	$imp=($p*0.2)+($j+1)*2; #Level 1 - after char
	#$imp=($p*0.5)+$j+1;    #Level 2 - medium
	#$imp=$p;               #Level 3 - after pos
	if ($imp<$minimp) {
	  $minimp=$imp;$minmember=$j;
	  $minp=$p;$minstr=$str;
      }
      }
    }
  }

  if ($minmember<=$#by) {
    $j=$l2+$minstr*$minp;
    $c1=substr($c,0,$j);
    $c2=substr($c,$j);
    ($p1,$p2)=$c2=~/^(\W*)(.*)/;
    ($p1,$p2)=$c2=~/^([$bylist]*)(.*)/;
    $c1.=$p1;
    $c2=$2;
    return ($c) if $c1 eq $c || $c2 eq $c;
    return (srtsplit($c1),srtsplit($c2));
  } else {
    return $c;
  }
}

sub srtlength {
  local ($c)=@_;
  # Experimental phonetical adjustment
  $c=~s/^-\ //;
  $c=~s/(,)/$1x2/seg;
  $c=~s/(;)/$1x3/seg;
  $c=~s/(\.\.\.)/$1x3/seg;
  $c=~s/(\.)/$1x2/seg;
  $c=~s/(\?)/$1x3/seg;
  $c=~s/(\w{8,})/'a'x(4*length($1)\/5)/seg;
  $c=~s/(well\s*,)/$1x2/g;
  $c=~s/(--|\w')//g;#'
  return length($c);
}

sub breakentry {
  local ($entrynr)=@_;
  $BREAKNR++;
  local ($i,$tl,$lastt,$tlen,$remain);
  local ($time1,$time2,$addition)=splithead($entryhead[$entrynr]);
  local $c=$entrybody[$entrynr];

  $c=~s/[\a\t]/ /g;
  $c=~s/[\r\x01\x02\x03\x05]//g;
  $c=~s/\.\.\./\x01/g;
  $c=~s/\?/\x02/g;
  $c=~s/!/\x05/g;
  $c=~s/\n/\x03/g;
  $c=~s/([\x01\x02\x03\x05]) ([\x01\x02\x03\x05])/$1$2/s while $c=~/[\x01\x02\x03\x05] [\x01\x02\x03\x05]/;
  local (@cold)=srtsplit($c);
  local (@c);
  $remain='';
  for ($i=0;$i<=$#cold;$i++) {
    $cold[$i]="$remain$cold[$i]";
    $remain='';
    if (length($cold[$i])<$minlength) {
      $remain=$cold[$i];
    } else {
      $c[$#c+1]=$cold[$i];
    }
  }
  if ($#c==0) {
    $fail[$#fail+1]=$entrynr;
    return 0;
  }
  $REALNR++;
  makeroom($#c,$entrynr);

  for ($i=1;$i<=$#c;$i++) {
    $c[$i]=~s/^ // while $c[$i]=~/^ /;
    $c[$i]=~s/ $// while $c[$i]=~/ $/;
    if ($c[$i]=~/^([\x01\x02\x03\x05]+)/) {
      $c[$i-1].=$1;
      $c[$i]=~s/^[\x01\x02\x03\x05]+//;
    }
  }
  $tl=0;
  for ($i=0;$i<=$#c;$i++) {
    $c[$i]=~s/\x01/.../g;
    $c[$i]=~s/\x02/\?/g;
    $c[$i]=~s/\x03/\n/g;
    $c[$i]=~s/\x05/!/g;
    $c[$i]=~s/^ // while $c[$i]=~/^ /;
    $c[$i]=~s/ $// while $c[$i]=~/ $/;
    $tl+=srtlength($c[$i]);
  }
  $lastt=$time1;
  for ($i=0;$i<=$#c;$i++) {
    $tlen=ceil(srtlength($c[$i])*($time2-$time1)/$tl);
    if ($breakmark) {
      $c[$i]="\x04[M:$entrynr:\x04$c[$i]" if $i==0;
      $c[$i]="$c[$i]\x04:M]\x04" if $i==$#c;
    }
    $entryhead[$entrynr+$i]=$lastt.'-'.($lastt+$tlen).'-'.$addition;
    $entrybody[$entrynr+$i]=$c[$i];
    $lastt+=$tlen;
  }
  $entry+=$#c;
  return $#c;
}

__END__
