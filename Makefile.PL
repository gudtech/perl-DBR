use ExtUtils::MakeMaker;

WriteMakefile(
	      NAME            => 'DBR',
	      VERSION_FROM    => 'lib/DBR.pm',
	      PREREQ_PM       => {
				  'Carp'               => 0,
				  'Class::Std'         => 0,
				  'Clone'              => 0,
				  'Curses::UI'         => 0,
				  'Data::Dumper'       => 0,
				  'DateTime::TimeZone' => 0,
				  'DBI'                => 0,
				  'Digest::MD5'        => 0,
				  'Error'              => 0,
				  'FileHandle'         => 0,
				  'POSIX'              => 0,
				  'Scalar::Util'       => 0,
				  'Symbol'             => 0,
				  'Time::HiRes'        => 0,
				  'Time::ParseDate'    => 0,
				 },

	     );