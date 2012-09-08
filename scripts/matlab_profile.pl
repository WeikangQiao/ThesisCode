#!/usr/bin/perl

################################################################################
#
# Script to convert MATLAB profiler output into CSV format. Processes data as
# produced by the `matlab_profile.sh' script.
#
# Usage:
#     ./matlab-profile.pl input
#
# Input:  Base directory where the profiler output is found. Should contain 
#         subdirectories named after the data sets that the data pertains to.
#         Each data set subdirectory should contain a single subdirectory for 
#         each iteration of the Matlab code. The input format should be a 
#         directory hierarchy with the following structure:
#             `{data-set}/{iteration}/{profile}`
# Output: Profiler data in CSV format. Outputs to STDOUT.
#
################################################################################

use strict;
use warnings;

use File::Spec;

use constant PROFILE_HTML_FILE => "file0.html";
use constant OUTPUT_HEADER     => "Profile,Data set,Iteration,Function Name,Calls,Total Time,Self Time\n";

use FindBin;
use lib $FindBin::Bin;
require "util.pl";

# The argument should be the base directory for the profiling data
scalar(@ARGV) >= 1 || die("No directory specified!\n");
my $base_dir = $ARGV[0];
-d $base_dir || die("Directory doesn't exist: $base_dir\n");

# Get data sets from subdirectories below base directory
my @dataset_dirs = next_subdirectory_level($base_dir);

# Print header of output
print(OUTPUT_HEADER);

# A hashmap for the profiling results
#     results{'profile_name'}{'data_type'}
#
# Where 'data' is one of the following:
#     - calls               Total number of calls to each function, across all data sets.
#     - total_time          Total time for each function, across all data sets.
#     - self_time           Total self time for each function, across all data sets.
#     - iterations          Total iterations across all data sets.
#     - dataset_calls       Total number of calls to each function, across a given data set.
#     - dataset_total_time  Total time for each function, across a given data set.
#     - dataset_self_time   Total self time for each function, across a given data set.
#     - dataset_iterations  Total iterations across a given data set.
my %results = ();

# Loop through each data set
for my $dataset_dir (@dataset_dirs) {
    my $dataset = strip_directory($dataset_dir);
    
    # Get iterations from next subdirectory level
    my @iteration_dirs = next_subdirectory_level($dataset_dir);
    
    # Loop through each iteration subdirectory
    for my $iteration_dir (@iteration_dirs) {
        my $iteration = strip_directory($iteration_dir);
    
        # Get profiles from next subdirectory level
        my @profile_dirs = next_subdirectory_level($iteration_dir);
        
        # Loop through each profile subdirectory
        for my $profile_dir (@profile_dirs) {
            my $profile = strip_directory($profile_dir);
            
            # Check if the profile exists in the results hash
            if (!exists $results{$profile}) {
                $results{$profile} = ();
                $results{$profile}{'calls'} = ();
                $results{$profile}{'total_time'} = ();
                $results{$profile}{'self_time'} = ();
                $results{$profile}{'iterations'} = 0;
                $results{$profile}{'dataset_calls'} = ();
                $results{$profile}{'dataset_total_time'} = ();
                $results{$profile}{'dataset_self_time'} = ();
                $results{$profile}{'dataset_iterations'} = ();
            }
            if (!exists $results{$profile}{'dataset_calls'}{$dataset}) {
                $results{$profile}{'dataset_calls'}{$dataset} = ();
            }
            if (!exists $results{$profile}{'dataset_total_time'}{$dataset}) {
                $results{$profile}{'dataset_total_time'}{$dataset} = ();
            }
            if (!exists $results{$profile}{'dataset_self_time'}{$dataset}) {
                $results{$profile}{'dataset_self_time'}{$dataset} = ();
            }
            if (!exists $results{$profile}{'dataset_iterations'}{$dataset}) {
                $results{$profile}{'dataset_iterations'}{$dataset} = 0;
            }
    
            # Retrieve the input HTML file
            my $profile_html_file = File::Spec->catfile($profile_dir, PROFILE_HTML_FILE);
            my @data_rows = get_table_rows($profile_html_file);

            # Buffered output
            my @output = ();
            
            # We have seen another iteration
            ($results{$profile}{'dataset_iterations'}{$dataset})++;
            ($results{$profile}{'iterations'})++;

            # Output the data, looping through each row
            foreach my $row (@data_rows) {
                my $function = html_parse_function_name($row);
                my $calls = html_parse_function_calls($row);
                my $total_time = html_parse_function_total_time($row);
                my $self_time = html_parse_function_self_time($row);
                
                $results{$profile}{'dataset_calls'}{$dataset}{$function} += $calls;
                $results{$profile}{'calls'}{$function} += $calls;
                
                $results{$profile}{'dataset_total_time'}{$dataset}{$function} += $total_time;
                $results{$profile}{'total_time'}{$function} += $total_time;
                
                $results{$profile}{'dataset_self_time'}{$dataset}{$function} += $self_time;
                $results{$profile}{'self_time'}{$function} += $self_time;
                
                # Output the data
                my $this_output = [$function, $calls, $total_time, $self_time];
                push(@output, $this_output);
            }
        }
    }
    
    # Output averages over this data set
    my @profiles = sort(keys(%results));
    foreach my $profile (@profiles) {
        my @functions = sort(keys(%{$results{"$profile"}{'dataset_calls'}{$dataset}}));
        
        foreach my $function (@functions) {
            my $calls_average = $results{$profile}{'dataset_calls'}{$dataset}{$function} / $results{$profile}{'dataset_iterations'}{$dataset};
            my $total_time_average = $results{$profile}{'dataset_total_time'}{$dataset}{$function} / $results{$profile}{'dataset_iterations'}{$dataset};
            my $self_time_average = $results{$profile}{'dataset_self_time'}{$dataset}{$function} / $results{$profile}{'dataset_iterations'}{$dataset};
            print("\"$profile\",\"$dataset\",\"average\",\"$function\",$calls_average,$total_time_average,$self_time_average\n");
        }
    }
}

# Output averages over all data sets
my @profiles = sort(keys(%results));
    foreach my $profile (@profiles) {
    
    my @functions = sort(keys(%{$results{$profile}{'calls'}}));
    foreach my $function (@functions) {
        my $calls_average = $results{$profile}{'calls'}{$function} / $results{$profile}{'iterations'};
        my $total_time_average = $results{$profile}{'total_time'}{$function} / $results{$profile}{'iterations'};
        my $self_time_average = $results{$profile}{'self_time'}{$function} / $results{$profile}{'iterations'};
        print("\"$profile\",\"average\",\"average\",\"$function\",$calls_average,$total_time_average,$self_time_average\n");
    }
}
