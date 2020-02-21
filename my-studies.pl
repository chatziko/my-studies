#!/usr/bin/perl -w
use strict;
use feature 'state';
use experimental 'smartmatch';

use LWP::UserAgent;
use Getopt::Long;
use Data::Dumper;
use IO::Handle;



my ($username, $password, $course_id, $grades);
GetOptions(
	"username=s"	=> \$username,
	"password=s"	=> \$password,
	"course-id=s"	=> \$course_id,
	"grades=s"		=> \$grades,
) or exit 1;
my $command = shift @ARGV;
$command ~~ [qw/set-grades verify-grades/]	or die "valid commands: set-grades verify-grades\n";

!@ARGV			or die "too many options";
$username		or die "no username\n";
$course_id		or die "no course id\n";
$grades			or die "no --grades=...\n";
if(!$password) {
	print "my-studies password: ";
	STDOUT->flush();
	system('stty', '-echo');
	chop($password=<STDIN>);
	system('stty', 'echo');
	print "\n\n";
	$password	or die "no password\n";
}

# read/ grades
my @grades;
open F, "< $grades"		or die "cannot open $grades\n";
while(<F>) {
	chomp;
	next if	/^\s*$|^#/;

	/^(\d+),([\d,.]*)$/	or die "invalid line $_\n";
	my ($id, $grade) = ($1, $2);

	$id = "111520$id"	if length($id) == 7;
	length($id) == 13	or die "invalid id: $id\n";

	$grade =~ s/,/\./;
	$grade eq "" || ($grade >= 0 && $grade <= 10)	or die "invalid grade: $grade\n";
	$grade =~ s/\./,/;		# my-studies likes commas

	push @grades, [$id, $grade];
}



my %urls = (
	login => 'https://my-studies.uoa.gr/Secr3w/connect.aspx',
	courses => 'https://my-studies.uoa.gr/Secr3w/app/works.aspx',
	marksheet => 'https://my-studies.uoa.gr/Secr3w/app/markSheets/sheetInfo.aspx?marksheetcode=',
	sheetfill => 'https://my-studies.uoa.gr/Secr3w/app/markSheets/sheetFill.aspx',
);


my $ua = LWP::UserAgent->new;		# ssl_opts => { verify_hostname => 0, SSL_verify_mode => 0, SSL_version => 'TLSv1', });
$ua->cookie_jar({});				# store/use cookies

my $res = $ua->post($urls{login}, [
	username => $username,
	password => $password
]);

$res = $ua->get($urls{courses});
$res->is_success && $res->content !~ /top.window.location.href='\/Secr3w'/		or die "incorrect password\n";
$res->content =~ /(\d+)_$course_id/												or die "course $course_id not found\n";
my $marksheet_code = $1;

# after this the server will remember the selected marksheet_code
$res = $ua->get($urls{marksheet} . $marksheet_code);



for(@grades) {
	set_grade(@$_)	or die "\n ---- FAILED ---- \n";
}

# check number
load_sheetfill(cmdFilter => '');
my $html = load_sheetfill(ddStuOnPage => 'ALL');	# load all
my @total = $html =~ /(name="dataGrid\$ctl\d+?\$txtGrade" type="text" value=".+?")/g;
my $grades_nonempty = grep { $_->[1] ne "" } @grades;
print "\n", (@total != $grades_nonempty ? "WARNING: " : ""), "students with non-empty grades: my-studies: ", scalar(@total), ", $grades: $grades_nonempty\n";


sub set_grade {
	my ($student_id, $grade) = @_;
	$grade =~ s/\./,/;

	# first load the grid filtering only this student
	load_sheetfill(cmdFilter => '');	# NEEDED for initial state
	my $html = load_sheetfill(
		txtFiter => $student_id,
		cmdFilter => '',
	);
	$html =~ /$student_id/ && $html !~ /ctl04/									or die "$html\n\ninvalid html: not filtered";

	# check current grade
 	$html =~ /name="dataGrid\$ctl03\$txtGrade" type="text" (value="(.*?)")?/	or warn("student $student_id not found\n"), return;
	my $current = $2 // "";
	$current ne $grade															or warn("student $student_id already has grade '$grade'\n"), return 1;

	$command eq 'set-grades'													or warn("verify-grades: student $student_id has incorrect grade '$current' instead of '$grade'\n"), return;

	# load again, this time setting the new grade
	$html = load_sheetfill(
		__EVENTTARGET => 'dataGrid$ctl03$txtGrade',
		'dataGrid$ctl03$txtGrade' => $grade,
	);
 	$html =~ /name="dataGrid\$ctl03\$txtGrade" type="text" (value="(.*?)")?/	or warn("could not change $student_id to '$grade\n'"), return;
 	($2 // "") eq $grade														or warn("could not change $student_id to '$grade\n'"), return;

	warn("student $student_id changed to '$grade'\n");
	return 1;
}

sub load_sheetfill {
	state @last_hidden_params;

	$res = $ua->post($urls{sheetfill}, [
		@last_hidden_params,		# the <input type="hidden" name="__foo"> params from the last call
		@_							# new params
	]);
	$res->is_success			or die $res->content . "\n\nrequest failed";
	my $html = $res->content;

	# find all hidden params and store for next call
	@last_hidden_params = $html =~ /name="__.*?" id="(__.*?)" value="(.*?)"/g;

	return $html;
}